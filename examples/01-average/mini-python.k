// =============================================================================
//  mini-python.k
//  "mini Python (+ lists)": a MINIMAL K semantics for EXACTLY the fragment of
//  Python used by average(nums). The program is now SELF-CONTAINED -- it sums with
//  an explicit `while` loop and then divides by the length -- so the fragment is
//  the union of the sum-up loop machinery and the insertion-sort list machinery.
//  Constructs covered (and nothing else):
//    - integer literals and names;
//    - len(e)            -- list length;
//    - index READ  e[e]  -- element access (READ only; average never mutates);
//    - arithmetic +      -- accumulate the running total;
//    - comparison  <     -- the loop guard  i < n;
//    - integer division e / e   (MODELING DECISION -- see DIVISION NOTE + FINDINGS #3);
//    - assignment x = e ;
//    - while ; function def ; return ; function call.
//  NO `if`, NO `-`/`*`, NO list mutation / index-assign, NO `list()`, NO slices,
//  NO exceptions.
//
//  Adapted from the kit's reference example examples/sum-up/mini-python.k (itself
//  from K Tutorial Lesson 1.22): same <k>/<store>/<funcs>/<stack> configuration,
//  the same call/return machinery, the same #whileLoop frozen-guard loop. The
//  Bot/Bots shared-klabel list trick is GENERALIZED from Int arguments to arbitrary
//  value (KResult) arguments exactly as in examples/insertion-sort/mini-python.k,
//  because average is called on a LIST value, not an Int.
//
//  LIST = VALUE SORT (why the read fragment is all we need):
//    K's `List` is an immutable value sort (size(L), L[I], ListItem(_), .List), not
//    a heap reference. average only READS len(nums) and nums[i]; it never mutates
//    its argument. So we import ONLY the read API: `size(L)` and `L[I]`. No
//    index-assign / copy machinery is introduced.
//
//  ELEMENT-SORT MODELING DECISION (faithful restriction, see FINDINGS.md #4):
//    The source averages "numbers"; we model elements as Int (the analogue of the
//    sum example restricting to Int). Floats / mixed numeric types are reported as
//    a Finding, not modeled away silently.
//
//  DIVISION NOTE (a load-bearing modeling decision -- see FINDINGS.md #1/#3):
//    Python 3's `/` is TRUE (float) division: total/n is a float (average([1,2]) ==
//    1.5). K's `/Int` is INTEGER division that TRUNCATES toward zero. We model `/`
//    as `/Int` (the kit's arithmetic fast path is over Int; floats are an escalation
//    case -- knowledge/sources.md). The two AGREE only when n exactly divides total;
//    the gap (int-vs-float) is FINDINGS.md #3.
//    Crucially, the rule carries `requires I2 =/=Int 0`, making /Int's PARTIALITY
//    explicit. So average([]) -- where n = len(nums) = 0 -- gets STUCK on `total / 0`,
//    which is exactly Python's ZeroDivisionError (FINDINGS.md #1, the headline bug).
//    We do NOT model `raise`/exceptions (out of the fragment); the stuck state IS the
//    signal. The missing precondition len(nums) >= 1 is what `requires I2 =/=Int 0`
//    makes explicit.
//
//  INDENTATION NOTE: as in the reference example, a suite is the INDENT...DEDENT
//    token-bracketed block a real Python tokenizer would emit; K's parser is not
//    whitespace-sensitive. Affects layout only, not semantics.
//
//  BUILTIN NAMES: list `size(L)` (length) and element access `L[I]` are from K's
//    `LIST` module / domains.md; `/Int`, `=/=Int`, `+Int`, `<Int` are from `INT`.
//    The MVP does not run the toolchain (artifacts are "constructed, not
//    machine-checked"); confirm exact builtin spellings against your K's domains.md
//    at kprove time.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  // Values are Int, Bool, or List (declared as KResult below). Precedence runs
  // from tightest (indexing / len / call) to loosest (comparison), matching Python.
  syntax Exp ::= Id | Int
               | "(" Exp ")"            [bracket]
               | "len" "(" Exp ")"      [strict]            // len(e)
               | Exp "[" Exp "]"        [seqstrict]         // index read  e[e]
               > Exp "+" Exp            [seqstrict, left]   // arithmetic +
               | Exp "/" Exp            [seqstrict, left]   // integer division (see DIVISION NOTE)
               > Exp "<" Exp            [seqstrict, non-assoc]   // comparison <  (loop guard)
               | Id "(" Exps ")"        [strict(2)]         // function call (expr)

  // Argument / parameter lists. Shared klabel(exps) Bot/Bots construction (as in
  // the reference examples) makes Vals (evaluated args, a KResult) and Ids
  // (parameters) BOTH subsorts of the strict Exps list, so the seqstrict arg list
  // cools to a Vals KResult and `.Bots` is the single shared empty terminator.
  // GENERALIZATION vs the sum example: evaluated args are Vals = List{KResult},
  // not List{Int}, so a LIST value is a legal argument (cf. insertion-sort).
  syntax Bot
  syntax Bots ::= List{Bot,     ","}    [klabel(exps)]
  syntax Vals ::= List{KResult, ","}    [klabel(exps)] | Bots   // evaluated args
  syntax Ids  ::= List{Id,      ","}    [klabel(exps)] | Bots   // parameters
  syntax Exps ::= List{Exp,     ","}    [klabel(exps), seqstrict] | Vals | Ids

  syntax KResult ::= Int | Bool | List | Vals

  // ---- statements -----------------------------------------------------------
  // Suite-headed/leaf statements bind TIGHTER than sequencing (the `>` block), and
  // a Suite is itself a Stmt, so INDENT...DEDENT is self-delimiting and the parser
  // knows where a while/def body ends.
  syntax Stmt ::= Id "=" Exp                       [strict(2)]    // x = e
                | "while" Exp ":" Suite                           // while
                | "def" Id "(" Ids ")" ":" Suite                  // function def
                | "return" Exp                     [strict]       // return
                | Id "(" Exps ")"                  [strict(2)]     // call stmt
                | Suite
                > Stmt Stmt                          [left]        // sequencing

  syntax Suite ::= "INDENT" Stmt "DEDENT"
endmodule

module MINI-PYTHON
  imports MINI-PYTHON-SYNTAX
  imports INT
  imports BOOL
  imports MAP
  imports LIST

  configuration
    <k> $PGM:Stmt </k>
    <store> .Map  </store>     // program variables  Id |-> Value (Int or List)
    <funcs> .Map  </funcs>     // function table      Id |-> (def ...)
    <stack> .List </stack>     // call stack of saved (continuation, store)

  // ---- expressions ----------------------------------------------------------
  rule <k> X:Id => V ... </k>
       <store> ... X |-> V ... </store>

  rule <k> len(L:List) => size(L) ... </k>

  // index read: in-bounds element access. Out-of-bounds is intentionally STUCK
  // (= Python IndexError); the loop invariant guarantees 0 <= i < size(nums) at
  // every read of nums[i] (the guard i < n with n = size(nums)).
  rule <k> L:List [ I:Int ] => L [ I ] ... </k>
    requires 0 <=Int I andBool I <Int size(L)

  rule <k> I1:Int + I2:Int => I1 +Int I2 ... </k>

  rule <k> I1:Int < I2:Int => I1 <Int I2 ... </k>

  // DIVISION -- modeled as INTEGER division /Int (truncates toward zero). The
  // `requires I2 =/=Int 0` makes /Int's PARTIALITY explicit: division by zero is
  // UNDEFINED, so the rule cannot fire and the configuration is STUCK -- exactly
  // Python's ZeroDivisionError. This is where average([]) (n = 0) dies; see
  // FINDINGS.md #1 (the headline bug) and #3 (int-vs-float gap of /Int vs `/`).
  rule <k> I1:Int / I2:Int => I1 /Int I2 ... </k>
    requires I2 =/=Int 0

  // ---- statement sequencing & suite unwrapping ------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment -----------------------------------------------------------
  rule <k> X:Id = V:KResult => .K ... </k>
       <store> STORE => STORE [ X <- V ] </store>

  // ---- while  (fresh guard copy at the head; frozen copy survives in #whileLoop;
  //   re-entry is to `while`, never an `if`. Exactly as examples/sum-up.) --------
  syntax KItem ::= #whileLoop(Exp, Suite)

  rule <k> while B:Exp : S:Suite => B ~> #whileLoop(B, S) ... </k>
  rule <k> true  ~> #whileLoop(B:Exp, S:Suite) => S ~> while B : S ... </k>
  rule <k> false ~> #whileLoop(_:Exp, _:Suite) => .K ... </k>

  // ---- function definition --------------------------------------------------
  rule <k> def FNAME:Id ( ARGS:Ids ) : BODY:Suite => .K ... </k>
       <funcs> FS => FS [ FNAME <- def FNAME ( ARGS ) : BODY ] </funcs>

  // ---- function call (args already evaluated to Vals by strict(2)) ----------
  rule <k> FNAME:Id ( VS:Vals ) ~> CONT => #makeBindings(ARGS, VS) ~> BODY </k>
       <funcs> ... FNAME |-> def FNAME ( ARGS:Ids ) : BODY:Suite ... </funcs>
       <store> STORE => .Map </store>
       <stack> .List => ListItem(state(CONT, STORE)) ... </stack>

  // ---- return ---------------------------------------------------------------
  rule <k> return V:KResult ~> _ => V ~> CONT </k>
       <stack> ListItem(state(CONT, STORE)) => .List ... </stack>
       <store> _ => STORE </store>

  rule <k> return V:KResult ~> .K => V </k>
       <stack> .List </stack>

  // ---- parameter binding ----------------------------------------------------
  syntax KItem ::= #makeBindings(Ids, Vals)
                 | state(continuation: K, store: Map)

  rule <k> #makeBindings(.Ids, .Vals) => .K ... </k>
  rule <k> #makeBindings((X:Id, IDS:Ids) => IDS, (V:KResult, VS:Vals) => VS) ... </k>
       <store> STORE => STORE [ X <- V ] </store>
endmodule
