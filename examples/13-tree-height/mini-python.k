// =============================================================================
//  mini-python.k
//  "mini Python": a MINIMAL K semantics for exactly the fragment of Python used
//  by the (in-domain) core of tree_height.py -- which is now SELF-CONTAINED: it
//  defines its OWN helper max2(x, y) and uses it. Constructs covered, and NOTHING
//  else: integer literals and names; + ; - ; > (greater-than); assignment x = e ;
//  if / else ; function def ; return ; (recursive, BRANCHING) function call; and a
//  tuple-shaped BINARY TREE modeled as a K VALUE SORT (see below).
//  NO while, NO += , NO <= , NO == (this program uses none of those).
//
//  Adapted from K Tutorial Lesson 1.22 and the sum-recursive example: we keep the
//  proven <k>/<store>/<funcs>/<stack> configuration, the call/return machinery, and
//  the Bot/Bots list construction. TWO functions are modeled (max2, tree_height),
//  so <funcs> holds two definitions; recursion needs no new machinery -- <funcs> is
//  FRAMED (never reset by a call), so a self-call re-finds the definition, and the
//  two recursive CHILD calls of tree_height each push their own frame in turn.
//
//  THE BINARY TREE -- THE ONE NEW MODELING DECISION vs. sum-recursive.
//  The Python tree is `None` or a 3-tuple `(value, left, right)`. We model it as a
//  first-class K VALUE SORT `Tree`:
//        syntax Tree ::= "none" | node(Int, Tree, Tree)
//  This is the tree-shaped analog of insertion-sort modeling a Python list as K's
//  builtin `List` value sort: because `Tree` is a *value* (not a heap reference),
//  Python's by-value tuple structure and non-aliasing fall out for free. The Python
//  field reads `t[1]` / `t[2]` and the `t is None` test become structural matches on
//  `node(_, L, R)` / `none` -- modeled by spec-only selector/predicate functions
//  (`left(_)`, `right(_)`, `isNone(_)`) declared in the spec's VERIFICATION module,
//  so the semantics here stays a clean value algebra. A Tree is a KResult, so it is
//  passable to a call (the args list is generalized to KResult, cf. insertion-sort
//  passing a List).
//
//  GUARD-LAYER / SHAPE NOTE (the modeling decision, cf. sum-recursive).  The real
//  tree_height reads `t[1]`/`t[2]` from a Python tuple after `if t is None`. On the
//  VERIFIED DOMAIN (t is a well-formed tree: either None or a (value,left,right)
//  tuple whose children are themselves well-formed trees) those reads always
//  succeed, so the *value* semantics is EXACTLY the reduced body modeled here:
//        def max2(x, y):
//            if x > y: return x
//            else:     return y
//        def tree_height(t):
//            if t is None: return 0
//            return 1 + max2(tree_height(t.left), tree_height(t.right))
//  The exact TUPLE SHAPE is ASSUMED (a malformed tuple -- wrong arity, a non-tree in
//  a child slot -- is out of domain); this becomes an (assumed) finding, see
//  SPEC.md / FINDINGS.md. The `__main__` I/O block (asserts/print) is outside the
//  verified core and not modeled.
//
//  INDENTATION NOTE.  As in the sibling examples, a suite is the token-bracketed
//  block  Suite ::= "INDENT" Stmt "DEDENT"  (K's parser is not whitespace-sensitive).
//  Displayed Python indentation corresponds 1-1 to INDENT ... DEDENT here; this
//  affects only layout, never semantics.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- the binary tree value sort -------------------------------------------
  //  none                     <->  Python None
  //  node(V, L, R)            <->  Python tuple (V, L, R)
  //  A Tree is a fully-evaluated value (a KResult), passed by value to calls.
  syntax Tree ::= "none"
                | "node" "(" Int "," Tree "," Tree ")"

  // ---- expressions ----------------------------------------------------------
  //  Field reads `t . left` / `t . right` mirror Python's tuple reads `t[1]`/`t[2]`
  //  on the verified domain; they are strict so `t` evaluates to a Tree value first,
  //  then the read pattern-matches `node(_, L, R)`.
  syntax IExp ::= Id | Int | Tree
                | "(" IExp ")"            [bracket]
                > Id "(" IExps ")"        [strict(2)]         // call (binds tightest)
                | IExp "." "left"         [strict(1)]         // t.left  (Python t[1])
                | IExp "." "right"        [strict(1)]         // t.right (Python t[2])
                > IExp ">" IExp           [seqstrict, left]   // greater-than (x > y)
                > IExp "+" IExp           [seqstrict, left]   // addition    (1 + ...)
                | IExp "-" IExp           [seqstrict, left]   // subtraction (kept tiny)

  syntax BExp ::= Bool
                | IExp ">" IExp           [seqstrict]         // guard form of >
                | IExp "is" "None"        [strict(1)]         // t is None  (None test)

  // Argument/parameter lists. The shared klabel(exps) Bot/Bots construction makes
  // KResults (evaluated args -- here Ints AND Trees) and Ids (parameters) BOTH
  // subsorts of the strict IExps list, so an evaluated argument list is a legal
  // call argument, the seqstrict arg list cools to a KResult, and `.Bots` is the
  // shared empty terminator. Generalized from sum-recursive's Int-only list to
  // ANY KResult, so a Tree value can be passed (cf. insertion-sort passing a List).
  syntax Bot
  syntax Bots   ::= List{Bot,      ","}   [klabel(exps)]
  syntax Vals   ::= List{KResult,  ","}   [klabel(exps)] | Bots   // evaluated args
  syntax Ids    ::= List{Id,       ","}   [klabel(exps)] | Bots   // parameters
  syntax IExps  ::= List{IExp,     ","}   [klabel(exps), seqstrict] | Vals | Ids

  syntax KResult ::= Int | Bool | Tree | Vals

  // ---- statements -----------------------------------------------------------
  // Suite-headed/leaf statements bind TIGHTER than sequencing (the `>` block),
  // and a Suite is itself a Stmt, so an INDENT...DEDENT block is self-delimiting
  // and the parser knows where an if/else/def body ends.
  syntax Stmt ::= Id "=" IExp                          [strict(2)]   // assignment
                | "if" BExp ":" Suite "else" ":" Suite                // if / else
                | "if" BExp ":" Suite                                 // if (no else)
                | "def" Id "(" Ids ")" ":" Suite                      // function def
                | "return" IExp                        [seqstrict]    // return
                | Id "(" IExps ")"                     [strict(2)]    // call stmt
                | Suite
                > Stmt Stmt                             [left]         // sequencing

  // A suite (indented block); see the INDENTATION NOTE above.
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
    <store> .Map  </store>     // program variables  Id |-> (Int or Tree)
    <funcs> .Map  </funcs>     // function table      Id |-> (def ...)
    <stack> .List </stack>     // call stack of saved (continuation, store)

  // ---- expressions ----------------------------------------------------------
  rule <k> X:Id => V ... </k>
       <store> ... X |-> V ... </store>

  rule <k> I1:Int + I2:Int => I1 +Int I2 ... </k>
  rule <k> I1:Int - I2:Int => I1 -Int I2 ... </k>

  // greater-than (covers both the IExp value form and the BExp guard form).
  rule <k> I1:Int > I2:Int => I1 >Int I2 ... </k>

  // ---- tree field reads / None test (the value-sort structural matches) ------
  //  On the verified domain `t` is a well-formed node here (the None case is
  //  handled by the `if t is None` early return), so the reads pattern-match a node.
  rule <k> node(_, L:Tree, _) . left  => L ... </k>
  rule <k> node(_, _, R:Tree) . right => R ... </k>

  rule <k> none          is None => true  ... </k>
  rule <k> node(_, _, _) is None => false ... </k>

  // ---- statement sequencing (newline) ---------------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>

  // ---- suite unwrapping -----------------------------------------------------
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment (value may be an Int or a Tree) ---------------------------
  rule <k> X:Id = V:KResult => .K ... </k>
       <store> STORE => STORE [ X <- V ] </store>

  // ---- if / else ------------------------------------------------------------
  rule <k> if true  : S:Suite else : _:Suite => S ... </k>
  rule <k> if false : _:Suite else : S:Suite => S ... </k>
  // ---- if  (no else): used by tree_height's early-return `if t is None` -------
  rule <k> if true  : S:Suite => S  ... </k>
  rule <k> if false : _:Suite => .K ... </k>

  // ---- function definition --------------------------------------------------
  rule <k> def FNAME:Id ( ARGS:Ids ) : BODY:Suite => .K ... </k>
       <funcs> FS => FS [ FNAME <- def FNAME ( ARGS ) : BODY ] </funcs>

  // ---- function call (args already evaluated to KResults by strict(2)) ------
  //   <funcs> is matched/framed (not reset), so a self-call re-finds the same
  //   definition; <store> is reset to a fresh scope and the caller's
  //   (continuation, store) is pushed on <stack>. A BRANCHING recursive function
  //   (two child calls) needs no extra machinery: each child call is itself a
  //   call expression that pushes its own frame in turn.
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

  // ---- parameter binding -----------------------------------------------------
  syntax KItem ::= #makeBindings(Ids, Vals)
                 | state(continuation: K, store: Map)

  rule <k> #makeBindings(.Ids, .Vals) => .K ... </k>
  rule <k> #makeBindings((X:Id, IDS:Ids) => IDS, (V:KResult, VS:Vals) => VS) ... </k>
       <store> STORE => STORE [ X <- V ] </store>
endmodule
