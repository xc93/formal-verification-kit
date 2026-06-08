// =============================================================================
//  mini-python.k
//  "mini Python": a MINIMAL K semantics for exactly the fragment of Python used
//  by the (in-domain) core of is_even(n) / is_odd(n). Constructs covered, and
//  NOTHING else: integer literals and names; - (subtraction, n - 1); == (n == 0);
//  Bool literals (True / False as return values); assignment x = e ; if (NO else);
//  function def ; return ; (mutually recursive) function call.
//  NO while, NO += , NO + , NO <= , NO < (this program uses none of those).
//
//  Adapted from K Tutorial Lesson 1.22 and the sum-recursive example: we keep the
//  proven <k>/<store>/<funcs>/<stack> configuration, the call/return machinery,
//  and the Bot/Bots list construction. The ONE structural difference vs. the
//  single-recursion sum-recursive example is that here BOTH is_even and is_odd are
//  filed into <funcs>, and each calls the OTHER. That needs NO new machinery: the
//  stack-based call/return already handles any call graph, and <funcs> is FRAMED
//  (never reset by a call), so is_even's body can re-find is_odd's definition and
//  vice versa. MUTUAL recursion is carried entirely by call/return + the two
//  mutually-discharging circularities (EVEN)/(ODD) in the spec file.
//
//  RETURN VALUES ARE BOOLEANS.  Unlike sum-recursive (which returns Int), these
//  functions return Bool (True/False). So `return` and the call/return plumbing
//  are generalized from Int to a value type V that ranges over both Int and Bool
//  (Bool is the result here; Int is still needed for the argument n and for `n-1`,
//  `n==0`). We use a Val sort = Int | Bool for the things that flow through return.
//
//  GUARD-LAYER NOTE.  The displayed program has no input-validation guards at all
//  (no isinstance / no `if n < 0: raise`). The ONLY base case is `if n == 0`. On
//  the verified domain (n a non-negative int) the modeled body below is EXACTLY the
//  source. For n < 0 there is NO base case on the descending chain, so the mutual
//  recursion never bottoms out (it would run n, n-1, n-2, ... forever) -- this is a
//  real non-termination finding (see FINDINGS.md), and the precondition n >= 0 is
//  load-bearing for termination, not merely for the closed-form value.
//
//  The `if __name__ == "__main__"` test block (asserts, a `for` loop, print) is
//  outside the verified core and is intentionally NOT modeled.
//
//  INDENTATION NOTE.  As in the sum examples, a suite is modeled as the
//  token-bracketed block  Suite ::= "INDENT" Stmt "DEDENT"  (K's parser is not
//  whitespace-sensitive). Displayed Python indentation corresponds 1-1 to
//  INDENT ... DEDENT here; this affects only layout, never semantics.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  //   ONE expression sort `Exp` (Python is untyped at the surface). It carries the
  //   two value shapes this program produces -- integers (the argument n / n-1) and
  //   booleans (the parity result True/False and the guard n == 0) -- plus the
  //   operators it uses. A function call `is_odd(n - 1)` is an `Exp` (it returns a
  //   Bool here, but `Exp` is value-agnostic), so it is legal in BOTH `return`
  //   position and as an argument. This is the one syntactic generalization over
  //   sum-recursive (which split IExp/BExp and returned Int only): collapsing to a
  //   single `Exp` lets a call -- whose result is a Bool -- sit where the source
  //   puts it (`return is_odd(n - 1)`), exactly as in untyped Python.
  syntax Exp ::= Id | Int | Bool
               | "(" Exp ")"             [bracket]
               > Id "(" Exps ")"         [strict(2)]         // call (binds tightest)
               > Exp "-" Exp             [seqstrict, left]   // subtraction (n - 1)
               > Exp "==" Exp            [seqstrict]         // equality test (n == 0)

  // Argument/parameter lists. The shared klabel(exps) Bot/Bots construction makes
  // Vals (evaluated args, a KResult) and Ids (parameters) BOTH subsorts of the
  // strict Exps list, so an evaluated arg list is a legal call argument, the
  // seqstrict arg list cools to a KResult, and `.Bots` is the shared empty
  // terminator usable as both `.Ids` and the evaluated-args list. (Cf. Lesson 1.22.)
  //
  //   NOTE vs sum-recursive: there the evaluated-args list was `Ints` (Int only),
  //   because args AND returns were Int. Here the ARGUMENT is still an Int (`n - 1`),
  //   but a returned value can be a Bool, so the evaluated-value list is `Vals`
  //   (Val = Int | Bool) rather than `Ints`. The actual call args this program
  //   passes are always Int; `Vals` is the smallest list sort that still lets the
  //   strict arg list cool when a value flows through.
  syntax Bot
  syntax Bots  ::= List{Bot,  ","}        [klabel(exps)]
  syntax Vals  ::= List{Val,  ","}        [klabel(exps)] | Bots   // evaluated args
  syntax Ids   ::= List{Id,   ","}        [klabel(exps)] | Bots   // parameters
  syntax Exps  ::= List{Exp,  ","}        [klabel(exps), seqstrict] | Vals | Ids

  // Values: Int (for n / n-1) and Bool (the parity result True/False). This is the
  // one value-level generalization over sum-recursive, which returned Int only.
  syntax Val ::= Int | Bool

  syntax KResult ::= Val | Vals

  // ---- statements -----------------------------------------------------------
  // Suite-headed/leaf statements bind TIGHTER than sequencing (the `>` block),
  // and a Suite is itself a Stmt, so an INDENT...DEDENT block is self-delimiting
  // and the parser knows where an if/def body ends.
  syntax Stmt ::= Id "=" Exp                        [strict(2)]   // assignment
                | "if" Exp ":" Suite                              // if  (NO else)
                | "def" Id "(" Ids ")" ":" Suite                  // function def
                | "return" Exp                      [seqstrict]   // return a value
                | Id "(" Exps ")"                   [strict(2)]   // call stmt
                | Suite
                > Stmt Stmt                          [left]        // sequencing

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
    <store> .Map  </store>     // program variables  Id |-> Int
    <funcs> .Map  </funcs>     // function table      Id |-> (def ...)  (BOTH funcs)
    <stack> .List </stack>     // call stack of saved (continuation, store)

  // ---- expressions ----------------------------------------------------------
  rule <k> X:Id => V ... </k>
       <store> ... X |-> V ... </store>

  rule <k> I1:Int - I2:Int => I1 -Int I2 ... </k>
  rule <k> I1:Int == I2:Int => I1 ==Int I2 ... </k>

  // ---- statement sequencing (newline) ---------------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>

  // ---- suite unwrapping -----------------------------------------------------
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment -----------------------------------------------------------
  //   (used only by the spec's function-contract claim, e.g. `r = is_even(N)`;
  //   the RHS evaluates to a Bool here, so assignment stores a Bool value.)
  rule <k> X:Id = V:Val => .K ... </k>
       <store> STORE => STORE [ X <- V ] </store>

  // ---- if  (NO else): run the suite if the guard is true, skip it if false ---
  //   The program uses an early-return base guard (`if n == 0: return ...`), so an
  //   `if` with no else suffices: a false guard falls through to the next statement
  //   (the recursive `return is_odd(n - 1)` / `return is_even(n - 1)`).
  rule <k> if true  : S:Suite => S  ... </k>
  rule <k> if false : _:Suite => .K ... </k>

  // ---- function definition --------------------------------------------------
  //   Both is_even and is_odd are filed here (two `def`s run in sequence). <funcs>
  //   is keyed by name, so both coexist; neither call resets it (see call rule).
  rule <k> def FNAME:Id ( ARGS:Ids ) : BODY:Suite => .K ... </k>
       <funcs> FS => FS [ FNAME <- def FNAME ( ARGS ) : BODY ] </funcs>

  // ---- function call (args already evaluated to Vals by strict(2)) ----------
  //   MUTUAL-recursion-ready with NO extra machinery: <funcs> is matched/framed
  //   (not reset), so is_even's body re-finds is_odd's definition and vice versa;
  //   <store> is reset to a fresh scope and the caller's (continuation, store) is
  //   pushed on <stack>. Identical to the single-recursion call rule -- the call
  //   graph (self vs. mutual) is irrelevant to this rule.
  rule <k> FNAME:Id ( IS:Vals ) ~> CONT => #makeBindings(ARGS, IS) ~> BODY </k>
       <funcs> ... FNAME |-> def FNAME ( ARGS:Ids ) : BODY:Suite ... </funcs>
       <store> STORE => .Map </store>
       <stack> .List => ListItem(state(CONT, STORE)) ... </stack>

  // ---- return (a Bool value here; generalized to Val for the plumbing) -------
  rule <k> return V:Val ~> _ => V ~> CONT </k>
       <stack> ListItem(state(CONT, STORE)) => .List ... </stack>
       <store> _ => STORE </store>

  rule <k> return V:Val ~> .K => V </k>
       <stack> .List </stack>

  // ---- parameter binding -----------------------------------------------------
  //   Args evaluate to a Vals list; this program always passes an Int (the per-
  //   binding rule matches `IN:Int`), so each parameter binds to an Int in <store>.
  syntax KItem ::= #makeBindings(Ids, Vals)
                 | state(continuation: K, store: Map)

  rule <k> #makeBindings(.Ids, .Vals) => .K ... </k>
  rule <k> #makeBindings((I:Id, IDS:Ids) => IDS, (IN:Int, VS:Vals) => VS) ... </k>
       <store> STORE => STORE [ I <- IN ] </store>
endmodule
