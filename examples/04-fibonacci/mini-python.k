// =============================================================================
//  mini-python.k
//  "mini Python": a MINIMAL K semantics for exactly the fragment of Python used
//  by fib(n). Constructs covered (and NOTHING else): integer literals and names;
//  + ; < ; assignment x = e ; SIMULTANEOUS (tuple) assignment x, y = e1, e2 ;
//  while ; function def ; return ; function call.
//  NO `if`, NO `<=`, NO `-`, NO `+=` (this program uses none of those).
//
//  Adapted from K Tutorial Lesson 1.22 and the sum-up example: we keep the proven
//  <k>/<store>/<funcs>/<stack> configuration, the call/return machinery, and the
//  Bot/Bots list construction. The two differences from sum-up are (a) the loop
//  guard is strict `<` (not `<=`), matching fib's `while i < n`, and (b) the loop
//  body uses a SIMULTANEOUS assignment, modeled faithfully below.
//
//  SIMULTANEOUS-ASSIGNMENT NOTE (the one real modeling decision).
//    Python's `prev, curr = curr, prev + curr` evaluates the ENTIRE right-hand
//    tuple to values FIRST, then binds the targets -- so the new `prev` reads the
//    OLD `curr`, and the new `curr` reads the OLD `prev` (no sequential clobber).
//    We model exactly that: the RHS components are `strict(3,4)`, so BOTH evaluate
//    to Ints (reading the old store) BEFORE the binding rule fires; the binding
//    rule then updates BOTH targets in ONE step from those already-computed values.
//    This is value-faithful for the fib body (two simple-name targets, no
//    aliasing). A general n-ary / nested-target tuple assignment is out of scope --
//    the fragment models only the two-name simultaneous form the code uses.
//
//  INDENTATION NOTE.  As in the sum-up example, a suite is modeled as the
//  token-bracketed block  Suite ::= "INDENT" Stmt "DEDENT"  (K's parser is not
//  whitespace-sensitive). Displayed Python indentation corresponds 1-1 to
//  INDENT ... DEDENT here; this affects only layout, never semantics.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  syntax IExp ::= Id | Int
                | "(" IExp ")"            [bracket]
                > IExp "+" IExp           [seqstrict, left]   // addition (prev + curr)
                | Id "(" IExps ")"        [strict(2)]         // function call

  syntax BExp ::= Bool
                | IExp "<" IExp           [seqstrict]         // strict comparison (i < n)

  // Argument/parameter lists. The shared klabel(exps) Bot/Bots construction makes
  // Ints (evaluated args, a KResult) and Ids (parameters) BOTH subsorts of the
  // strict IExps list, so `IS:Ints` is a legal call argument, the seqstrict arg
  // list cools to an Ints KResult, and `.Bots` is the shared empty terminator
  // usable as both `.Ids` and `.Ints`.  (Cf. K Tutorial Lesson 1.22.)
  syntax Bot
  syntax Bots  ::= List{Bot,  ","}        [klabel(exps)]
  syntax Ints  ::= List{Int,  ","}        [klabel(exps)] | Bots   // evaluated args
  syntax Ids   ::= List{Id,   ","}        [klabel(exps)] | Bots   // parameters
  syntax IExps ::= List{IExp, ","}        [klabel(exps), seqstrict] | Ints | Ids

  syntax KResult ::= Int | Bool | Ints

  // ---- statements -----------------------------------------------------------
  // Suite-headed/leaf statements bind TIGHTER than sequencing (the `>` block),
  // and a Suite is itself a Stmt, so an INDENT...DEDENT block is self-delimiting
  // and the parser knows where a while/def body ends.
  syntax Stmt ::= Id "=" IExp                       [strict(2)]   // assignment
                | Id "," Id "=" IExp "," IExp        [strict(3,4)] // SIMULTANEOUS assign
                | "while" BExp ":" Suite                          // while
                | "def" Id "(" Ids ")" ":" Suite                  // function def
                | "return" IExp                     [seqstrict]   // return
                | Id "(" IExps ")"                  [strict(2)]   // call stmt
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
    <funcs> .Map  </funcs>     // function table      Id |-> (def ...)
    <stack> .List </stack>     // call stack of saved (continuation, store)

  // ---- expressions ----------------------------------------------------------
  rule <k> X:Id => V ... </k>
       <store> ... X |-> V ... </store>

  rule <k> I1:Int + I2:Int => I1 +Int I2 ... </k>

  rule <k> I1:Int < I2:Int => I1 <Int I2 ... </k>

  // ---- statement sequencing (newline) ---------------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>

  // ---- suite unwrapping -----------------------------------------------------
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment -----------------------------------------------------------
  rule <k> X:Id = I:Int => .K ... </k>
       <store> STORE => STORE [ X <- I ] </store>

  // ---- SIMULTANEOUS (tuple) assignment  x, y = e1, e2 -----------------------
  //   strict(3,4) has already evaluated BOTH right-hand expressions to Ints
  //   (I1, I2) -- reading the OLD values of any variables they mention -- BEFORE
  //   this rule fires. The rule then binds both targets in ONE step, so
  //   `prev, curr = curr, prev + curr` sets the new prev to the old curr and the
  //   new curr to old prev + old curr, with no sequential clobber.
  rule <k> X:Id , Y:Id = I1:Int , I2:Int => .K ... </k>
       <store> STORE => STORE [ X <- I1 ] [ Y <- I2 ] </store>

  // ---- while  (only the `while` construct; no `if` is introduced) -----------
  //   Evaluate a FRESH copy of the guard at the head of <k>, keeping an
  //   UNEVALUATED copy frozen inside #whileLoop so it can be re-checked each
  //   iteration. The head and the frozen copy are distinct subterms, so heating
  //   the head never rewrites the frozen copy. Re-entry is to `while`, not `if`.
  syntax KItem ::= #whileLoop(BExp, Suite)

  rule <k> while B:BExp : S:Suite => B ~> #whileLoop(B, S) ... </k>
  rule <k> true  ~> #whileLoop(B:BExp, S:Suite) => S ~> while B : S ... </k>
  rule <k> false ~> #whileLoop(_:BExp, _:Suite) => .K ... </k>

  // ---- function definition --------------------------------------------------
  rule <k> def FNAME:Id ( ARGS:Ids ) : BODY:Suite => .K ... </k>
       <funcs> FS => FS [ FNAME <- def FNAME ( ARGS ) : BODY ] </funcs>

  // ---- function call (args already evaluated to Ints by strict(2)) ----------
  rule <k> FNAME:Id ( IS:Ints ) ~> CONT => #makeBindings(ARGS, IS) ~> BODY </k>
       <funcs> ... FNAME |-> def FNAME ( ARGS:Ids ) : BODY:Suite ... </funcs>
       <store> STORE => .Map </store>
       <stack> .List => ListItem(state(CONT, STORE)) ... </stack>

  // ---- return ---------------------------------------------------------------
  rule <k> return I:Int ~> _ => I ~> CONT </k>
       <stack> ListItem(state(CONT, STORE)) => .List ... </stack>
       <store> _ => STORE </store>

  rule <k> return I:Int ~> .K => I </k>
       <stack> .List </stack>

  // ---- parameter binding -----------------------------------------------------
  syntax KItem ::= #makeBindings(Ids, Ints)
                 | state(continuation: K, store: Map)

  rule <k> #makeBindings(.Ids, .Ints) => .K ... </k>
  rule <k> #makeBindings((I:Id, IDS:Ids) => IDS, (IN:Int, INTS:Ints) => INTS) ... </k>
       <store> STORE => STORE [ I <- IN ] </store>
endmodule
