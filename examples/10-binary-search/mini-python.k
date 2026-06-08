// =============================================================================
//  mini-python.k
//  "mini Python (+ lists)": a MINIMAL K semantics for EXACTLY the fragment of
//  Python used by binary_search(a, x). Constructs covered (and nothing else):
//    - integer literals and names;
//    - len(e) ;
//    - index READ   e[e] ;          (NO index assign -- binary search never writes)
//    - arithmetic + and - and floor-division // ;
//    - comparisons == , < , <= ;
//    - tuple assignment  x, y = e, e   (for `lo, hi = 0, len(a) - 1`) ;
//    - simple assignment x = e ;
//    - if / elif / else ;
//    - while ; function def ; return ; function call.
//  NO `*`, NO `and`/`or`/`not`, NO slices, NO exceptions, NO index ASSIGN.
//
//  Adapted from the kit's list example examples/insertion-sort/mini-python.k
//  (itself from examples/sum-up, K Tutorial Lesson 1.22): same
//  <k>/<store>/<funcs>/<stack> configuration, the same call/return machinery, and
//  the same Bot/Bots shared-klabel list trick -- GENERALIZED from Int arguments to
//  arbitrary value (KResult) arguments, because binary_search is called with a
//  LIST value as its first argument.
//
//  DIFFERENCE vs the insertion-sort fragment (faithful to what THIS code uses):
//    * binary_search READS the list but never WRITES it  -> NO index-assign rule;
//      `a` is a read-only value sort, so non-mutation of the input is free.
//    * it uses `if/elif/else` (3-way branch on a[mid] vs x) -> `if` IS modeled here
//      (the sum/insertion examples dropped `if`; this program needs it).
//    * it uses floor-division `//` for the midpoint -> modeled with K's `divInt`
//      (floor toward negative infinity), which on the NON-NEGATIVE indices here
//      equals truncating `/Int`. See FINDINGS.md #2 (the historic C/Java overflow
//      bug) -- in Python there is NO overflow, so `(lo+hi)//2` is exactly the
//      mathematical floor((lo+hi)/2); we model it as such.
//    * it uses tuple assignment `lo, hi = 0, len(a) - 1` -> modeled directly.
//
//  ELEMENT-SORT MODELING DECISION (faithful restriction, see FINDINGS.md #1):
//    The source is generic over the element type; we model both list elements and
//    the search key `x` as Int, so `==`/`<`/`<=` are K's total order on Int. This
//    is the analogue of the sum example restricting to Int. The genericity gap (and
//    the real total-order precondition it hides -- NaN / incomparable types) is
//    reported as a Finding, not modeled away silently.
//
//  LIST = VALUE SORT: K's `List` is an immutable value sort, not a heap reference.
//    binary_search only reads it, so the caller's list is trivially never disturbed.
//
//  BUILTIN NAMES: list size `size(L)` and element access `L[I]` are from K's `LIST`
//    module / domains.md; integer floor-division is `divInt`, truncating division is
//    `/Int`. The MVP does not run the toolchain (artifacts are "constructed, not
//    machine-checked"); confirm the exact builtin spellings against your K's
//    domains.md at `kprove` time.
//
//  INDENTATION NOTE: a suite is modeled as the INDENT...DEDENT token-bracketed block
//    a real Python tokenizer would emit; K's parser is not whitespace-sensitive.
//    Affects layout only, not semantics.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  // Values are Int, Bool, or List (declared as KResult below). Precedence runs
  // from tightest (indexing / len) to loosest (comparisons), matching Python.
  syntax Exp ::= Id | Int
               | "(" Exp ")"            [bracket]
               | "len" "(" Exp ")"      [strict]            // len(e)
               | Exp "[" Exp "]"        [seqstrict]         // index read  e[e]
               > Exp "-"  Exp           [seqstrict, left]   // arithmetic
               | Exp "+"  Exp           [seqstrict, left]
               | Exp "//" Exp           [seqstrict, left]   // floor division
               > Exp "==" Exp           [seqstrict, non-assoc]   // comparisons
               | Exp "<"  Exp           [seqstrict, non-assoc]
               | Exp "<=" Exp           [seqstrict, non-assoc]
               | Id "(" Exps ")"        [strict(2)]         // function call (expr)

  // Argument / parameter lists. Shared klabel(exps) Bot/Bots construction (as in
  // the list example) makes Vals (evaluated args, a KResult) and Ids (parameters)
  // BOTH subsorts of the strict Exps list, so the seqstrict arg list cools to a
  // Vals KResult and `.Bots` is the single shared empty terminator. Evaluated args
  // are Vals = List{KResult}, so a LIST value is a legal argument.
  syntax Bot
  syntax Bots ::= List{Bot,     ","}    [klabel(exps)]
  syntax Vals ::= List{KResult, ","}    [klabel(exps)] | Bots   // evaluated args
  syntax Ids  ::= List{Id,      ","}    [klabel(exps)] | Bots   // parameters
  syntax Exps ::= List{Exp,     ","}    [klabel(exps), seqstrict] | Vals | Ids

  syntax KResult ::= Int | Bool | List | Vals

  // ---- statements -----------------------------------------------------------
  // Suite-headed/leaf statements bind TIGHTER than sequencing (the `>` block), and
  // a Suite is itself a Stmt, so INDENT...DEDENT is self-delimiting and the parser
  // knows where a while/def/if body ends.
  syntax Stmt ::= Id "=" Exp                       [strict(2)]    // x = e
                | Id "," Id "=" Exp "," Exp        [strict(3,4)]  // x, y = e1, e2
                | "if" Exp ":" Suite "else" ":" Suite  [strict(1)]  // if/else
                | "while" Exp ":" Suite                          // while
                | "def" Id "(" Ids ")" ":" Suite                 // function def
                | "return" Exp                     [strict]       // return
                | Id "(" Exps ")"                  [strict(2)]     // call stmt
                | Suite
                > Stmt Stmt                          [left]        // sequencing

  syntax Suite ::= "INDENT" Stmt "DEDENT"
  // NOTE on elif: Python `if A: .. elif B: .. else: ..` desugars to a nested
  // if/else (`if A: .. else: (if B: .. else: ..)`); we write binary_search that way
  // in the spec program. Only the two-armed `if/else` above is a primitive.
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
  // Python IndexError; the loop invariant guarantees lo,hi,mid stay in range).
  rule <k> L:List [ I:Int ] => L [ I ] ... </k>
    requires 0 <=Int I andBool I <Int size(L)

  rule <k> I1:Int +  I2:Int => I1 +Int   I2 ... </k>
  rule <k> I1:Int -  I2:Int => I1 -Int   I2 ... </k>
  // floor division. The source `(lo + hi) // 2` only ever divides a NON-NEGATIVE
  // sum by 2, where divInt (floor) and /Int (truncate) coincide. divInt is the
  // faithful model of Python's `//` (which floors). Guard against div-by-zero for
  // totality (the constant divisor here is 2, so it never fires).
  rule <k> I1:Int // I2:Int => I1 divInt I2 ... </k>
    requires I2 =/=Int 0

  rule <k> I1:Int == I2:Int => I1 ==Int  I2 ... </k>
  rule <k> I1:Int <  I2:Int => I1  <Int  I2 ... </k>
  rule <k> I1:Int <= I2:Int => I1 <=Int  I2 ... </k>

  // ---- statement sequencing & suite unwrapping ------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment -----------------------------------------------------------
  rule <k> X:Id = V:KResult => .K ... </k>
       <store> STORE => STORE [ X <- V ] </store>

  // tuple assignment  x, y = v1, v2  (both RHS already evaluated by strict(3,4))
  rule <k> X:Id , Y:Id = V1:KResult , V2:KResult => .K ... </k>
       <store> STORE => STORE [ X <- V1 ] [ Y <- V2 ] </store>

  // ---- if / else  (condition already evaluated to a Bool by strict(1)) -------
  rule <k> if true  : S:Suite else : _:Suite => S ... </k>
  rule <k> if false : _:Suite else : S:Suite => S ... </k>

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
