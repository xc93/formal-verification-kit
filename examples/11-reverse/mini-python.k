// =============================================================================
//  mini-python.k
//  "mini Python (+ lists)": a MINIMAL K semantics for EXACTLY the fragment of
//  Python used by reverse(a). Constructs covered (and nothing else):
//    - integer literals and names;
//    - len(e) ;
//    - index READ   e[e] ;
//    - index ASSIGN x[e] = e ;
//    - arithmetic + and - ;
//    - comparison < ;
//    - assignment x = e ;
//    - while ; function def ; return ; function call.
//  NO `if`, NO `*`/`/`, NO `and`/`or`/`not`, NO `list()`/copy, NO slices,
//  NO comparisons other than `<`, NO exceptions.
//
//  Adapted from the kit's array/list reference example
//  examples/insertion-sort/mini-python.k (itself derived from examples/sum-up,
//  K Tutorial Lesson 1.22): same <k>/<store>/<funcs>/<stack> configuration,
//  the same call/return machinery, and the same Bot/Bots shared-klabel list
//  trick -- GENERALIZED from Int arguments to arbitrary value (KResult) arguments,
//  because reverse is called on a LIST value, not an Int.
//
//  ELEMENT-SORT MODELING DECISION (faithful restriction, see FINDINGS.md #1):
//    The source is generic over the element type. reverse() COMPARES NOTHING --
//    it only swaps by position -- so unlike insertion_sort there is NO total-order
//    requirement on the elements. We still model elements as Int (the analogue of
//    the sum/insertion examples restricting to Int) purely so the spec's multiset
//    abstraction `bag` has a concrete value sort to count. The genericity gap here
//    is BENIGN (no order is used) -- itself a POSITIVE Finding (#1), not a hidden
//    precondition.
//
//  LIST = VALUE SORT (this is what makes the IN-PLACE swap clean to model):
//    K's `List` is an immutable value sort, not a heap reference. An index-assign
//    `a[i] = v` rebinds the program variable `a` to a NEW List value `L[I <- V]`.
//    reverse mutates its parameter `a` in place; in this model that is a sequence
//    of rebindings of the single store binding `a |-> L`. Because the function is
//    called as `out = reverse(A)`, after `return a` the caller's `out` holds the
//    final (reversed) list. NOTE: this value-sort model does NOT capture Python's
//    aliasing -- in real Python `reverse` mutates the *caller's* list object too
//    (the input is mutated; see FINDINGS.md #4). That aliasing/no-copy behavior is
//    a behavioral contract point reported as a Finding, not captured by the value
//    semantics here.
//
//  INDENTATION NOTE: as in the reference example, a suite is modeled as the
//    INDENT...DEDENT token-bracketed block a real Python tokenizer would emit;
//    K's parser is not whitespace-sensitive. Affects layout only, not semantics.
//
//  BUILTIN NAMES: list operations `size(L)`, element access `L[I]`, and update
//    `L [ I <- V ]` are from K's `LIST` module / domains.md. The MVP does not run
//    the toolchain (artifacts are "constructed, not machine-checked"); confirm the
//    exact builtin spellings against your K's domains.md at `kprove` time.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  // Values are Int, Bool, or List (declared as KResult below). Precedence runs
  // from tightest (indexing / len) to loosest (comparison `<`), matching Python.
  syntax Exp ::= Id | Int
               | "(" Exp ")"            [bracket]
               | "len"  "(" Exp ")"     [strict]            // len(e)
               | Exp "[" Exp "]"        [seqstrict]         // index read  e[e]
               > Exp "-" Exp            [seqstrict, left]   // arithmetic
               | Exp "+" Exp            [seqstrict, left]
               > Exp "<"  Exp           [seqstrict, non-assoc]   // the ONLY comparison
               | Id "(" Exps ")"        [strict(2)]         // function call (expr)

  // Argument / parameter lists. Shared klabel(exps) Bot/Bots construction (as in
  // the insertion-sort example) makes Vals (evaluated args, a KResult) and Ids
  // (parameters) BOTH subsorts of the strict Exps list, so the seqstrict arg list
  // cools to a Vals KResult and `.Bots` is the single shared empty terminator.
  // Evaluated args are Vals = List{KResult} (not List{Int}), so a LIST value is a
  // legal argument -- reverse is called on a list.
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
                | Id "[" Exp "]" "=" Exp           [strict(2,3)]  // x[i] = e
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
  // Python IndexError; the loop invariant guarantees indices stay in range).
  rule <k> L:List [ I:Int ] => L [ I ] ... </k>
    requires 0 <=Int I andBool I <Int size(L)

  rule <k> I1:Int + I2:Int => I1 +Int I2 ... </k>
  rule <k> I1:Int - I2:Int => I1 -Int I2 ... </k>

  rule <k> I1:Int < I2:Int => I1 <Int I2 ... </k>

  // ---- statement sequencing & suite unwrapping ------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment -----------------------------------------------------------
  rule <k> X:Id = V:KResult => .K ... </k>
       <store> STORE => STORE [ X <- V ] </store>

  // index assignment  x[i] = v  (target x is a name bound to a List value).
  // This is the IN-PLACE update: rebinds x to a new List value with position I
  // replaced by V. The two-pointer swap is two of these (through the temp `tmp`).
  rule <k> X:Id [ I:Int ] = V:KResult => .K ... </k>
       <store> ... X |-> (L:List => L [ I <- V ]) ... </store>
    requires 0 <=Int I andBool I <Int size(L)

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
