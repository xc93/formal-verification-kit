// =============================================================================
//  mini-python.k
//  "mini Python (+ lists)": a MINIMAL K semantics for EXACTLY the fragment of
//  Python used by array_max(a). Constructs covered (and nothing else):
//    - integer literals and names;
//    - len(e) ;
//    - index READ   e[e] ;
//    - arithmetic + ;
//    - comparisons < (loop guard) and > (body `if`) ;
//    - assignment x = e ;
//    - if e : suite ;
//    - while ; function def ; return ; function call.
//  NO `*`/`/`/`-`, NO `>=`/`<=`/`==`, NO `and`/`or`/`not`, NO index ASSIGN,
//  NO slices, NO `else`, NO exceptions.
//
//  Adapted from the kit's reference example examples/sum-up/mini-python.k (itself
//  from K Tutorial Lesson 1.22) and from examples/insertion-sort/mini-python.k
//  (which introduced the List value sort + the Vals=List{KResult} call machinery).
//  Same <k>/<store>/<funcs>/<stack> configuration, the same call/return machinery,
//  and the same Bot/Bots shared-klabel list trick GENERALIZED to KResult arguments
//  so a LIST value can be passed.
//
//  vs. insertion-sort's fragment, this one:
//    + ADDS `if e : suite` (Lesson 1.22 has it; array_max uses it, insertion_sort
//      did not). `if` is a plain conditional, no `else` (array_max has none).
//    - DROPS index ASSIGN, `list()`, `-`, `>=`, short-circuit `and`
//      (array_max never uses them -- keep the fragment to exactly what is touched).
//    KEEPS both `<` (the loop guard `i < len(a)`) and `>` (the body `if a[i] > largest`).
//
//  ELEMENT-SORT MODELING DECISION (faithful restriction, see FINDINGS.md #2):
//    The source is generic over the element type; we model elements as Int, so
//    `>` is K's total order on Int. This is the analogue of the sum example
//    restricting to Int. The genericity gap (and the real total-order precondition
//    it hides -- e.g. NaN / mixed incomparable types) is reported as a Finding,
//    not modeled away silently.
//
//  LIST = VALUE SORT: K's `List` is an immutable value sort, not a heap reference.
//    array_max only READS the list (size(L), L[I]); it never mutates it, so the
//    input-non-mutation property holds by construction.
//
//  INDENTATION NOTE: a suite is modeled as the INDENT...DEDENT token-bracketed
//    block a real Python tokenizer would emit; K's parser is not whitespace-
//    sensitive. Affects layout only, not semantics.
//
//  BUILTIN NAMES: list operations `size(L)` and element access `L[I]` are from K's
//    `LIST` module / domains.md. The MVP does not run the toolchain (artifacts are
//    "constructed, not machine-checked"); confirm the exact builtin spellings
//    against your K's domains.md at `kprove` time.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  // Values are Int, Bool, or List (declared as KResult below). Precedence runs
  // from tightest (indexing / len) to loosest (comparison), matching Python.
  syntax Exp ::= Id | Int
               | "(" Exp ")"            [bracket]
               | "len" "(" Exp ")"      [strict]            // len(e)
               | Exp "[" Exp "]"        [seqstrict]         // index read  e[e]
               > Exp "+" Exp            [seqstrict, left]   // arithmetic
               > Exp "<" Exp            [seqstrict, non-assoc]   // comparison (loop guard)
               | Exp ">" Exp            [seqstrict, non-assoc]   // comparison (body if)
               | Id "(" Exps ")"        [strict(2)]         // function call (expr)

  // Argument / parameter lists. Shared klabel(exps) Bot/Bots construction (as in
  // the reference examples) makes Vals (evaluated args, a KResult) and Ids
  // (parameters) BOTH subsorts of the strict Exps list, so the seqstrict arg list
  // cools to a Vals KResult and `.Bots` is the single shared empty terminator.
  // Evaluated args are Vals = List{KResult}, so a LIST value is a legal argument.
  syntax Bot
  syntax Bots ::= List{Bot,     ","}    [klabel(exps)]
  syntax Vals ::= List{KResult, ","}    [klabel(exps)] | Bots   // evaluated args
  syntax Ids  ::= List{Id,      ","}    [klabel(exps)] | Bots   // parameters
  syntax Exps ::= List{Exp,     ","}    [klabel(exps), seqstrict] | Vals | Ids

  syntax KResult ::= Int | Bool | List | Vals

  // ---- statements -----------------------------------------------------------
  // Suite-headed/leaf statements bind TIGHTER than sequencing (the `>` block), and
  // a Suite is itself a Stmt, so INDENT...DEDENT is self-delimiting and the parser
  // knows where an if/while/def body ends.
  syntax Stmt ::= Id "=" Exp                       [strict(2)]    // x = e
                | "if" Exp ":" Suite               [strict(1)]    // if e : suite
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

  // index read: in-bounds element access (out-of-bounds is intentionally stuck =
  // Python IndexError; the function precondition + loop invariant keep indices in
  // range -- including the very first read a[0], which needs len(a) >= 1).
  rule <k> L:List [ I:Int ] => L [ I ] ... </k>
    requires 0 <=Int I andBool I <Int size(L)

  rule <k> I1:Int + I2:Int => I1 +Int I2 ... </k>

  rule <k> I1:Int < I2:Int => I1 <Int I2 ... </k>
  rule <k> I1:Int > I2:Int => I1 >Int I2 ... </k>

  // ---- statement sequencing & suite unwrapping ------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment -----------------------------------------------------------
  rule <k> X:Id = V:KResult => .K ... </k>
       <store> STORE => STORE [ X <- V ] </store>

  // ---- if  (guard already evaluated to Bool by strict(1); no else branch) ----
  rule <k> if true  : S:Suite => S   ... </k>
  rule <k> if false : _:Suite => .K  ... </k>

  // ---- while  (fresh guard copy at the head; frozen copy survives in #whileLoop)
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
