// =============================================================================
//  mini-python.k
//  "mini Python": a MINIMAL K semantics for exactly the fragment of Python used
//  by sum_to_n(n) in sum.py. Constructs covered (and NOTHING else): integer
//  literals and names; + ; - ; >= ; assignment x=e ; augmented assignment
//  x+=e and x-=e (== x=x+e / x=x-e on ints); while ; function def ; return ;
//  function call.  NO `if` is introduced, and NO `<=`:  this program counts
//  DOWN with `>=`, so it is the `>=` / `-=` mirror of the kit's up-counting
//  `sum` example.
//
//  Adapted from K Tutorial Lesson 1.22 and the formal-verification-kit `sum`
//  example. We keep, unchanged, its proven <k>/<store>/<funcs>/<stack>
//  configuration, its call/return machinery, and its Bot/Bots argument-list
//  construction; we swap the up-counting operators (<=, +=) for this program's
//  down-counting ones, adding `>=`, binary `-`, and `-=` (and keeping `+`/`+=`,
//  since `total += i` desugars through `+`).
//
//  INDENTATION NOTE (the one modeling decision; identical to the sum example):
//    K's parser is not whitespace-sensitive, so a real Python tokenizer's
//    off-side rule is modeled by token-bracketing a suite as
//    Suite ::= "INDENT" Stmt "DEDENT". Displayed Python indentation corresponds
//    1-1 to INDENT ... DEDENT. This affects only lexing/layout, never semantics.
//  += / -= CAVEAT: the desugarings  x += e => x = x + e  and  x -= e => x = x - e
//    are value-faithful only because the targets here are side-effect-free simple
//    names; general Python evaluates a += / -= target once and dispatches to
//    __iadd__ / __isub__.
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  syntax IExp ::= Id | Int
                | "(" IExp ")"            [bracket]
                > IExp "+" IExp           [seqstrict, left]   // arithmetic +  (from +=)
                | IExp "-" IExp           [seqstrict, left]   // arithmetic -  (from -=)
                | Id "(" IExps ")"        [strict(2)]         // function call

  syntax BExp ::= Bool
                | IExp ">=" IExp          [seqstrict]         // comparison >=  (loop guard)

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
                | Id "+=" IExp                                     // augmented +=
                | Id "-=" IExp                                     // augmented -=
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
  rule <k> I1:Int - I2:Int => I1 -Int I2 ... </k>

  rule <k> I1:Int >= I2:Int => I1 >=Int I2 ... </k>

  // ---- statement sequencing (newline) ---------------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>

  // ---- suite unwrapping -----------------------------------------------------
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment & augmented assignment ------------------------------------
  rule <k> X:Id = I:Int => .K ... </k>
       <store> STORE => STORE [ X <- I ] </store>

  // Python augmented assignment on ints:
  rule <k> X:Id += E:IExp => X = X + E ... </k>
  rule <k> X:Id -= E:IExp => X = X - E ... </k>

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
