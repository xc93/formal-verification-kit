// =============================================================================
//  mini-python.k
//  "mini Python": a MINIMAL K semantics for exactly the fragment of Python used
//  by gcd(a, b). Constructs covered (and nothing else): integer literals and names;
//  % (modulo); assignment x = e ; the tuple swap a, b = b, a % b ; the truthiness
//  loop guard `while b:` (a bare integer used as a Bool: nonzero == true);
//  function def ; return ; function call.
//  NO `if`, NO `+`, NO `<=`, NO `+=` are introduced -- gcd uses none of them.
//
//  Adapted from K Tutorial Lesson 1.22 (which verifies a sum function); we keep
//  its proven <k>/<store>/<funcs>/<stack> configuration and call/return machinery,
//  and its Bot/Bots list construction for argument lists. The sum-up example
//  (examples/sum-up/mini-python.k) is the file-by-file template; this file is its
//  count-loop sibling specialized to the Euclidean fragment.
//
//  INDENTATION NOTE (same modeling decision as sum-up):
//    K's parser is not whitespace-sensitive, so it cannot apply Python's off-side
//    rule directly. A real Python tokenizer emits INDENT/DEDENT tokens bracketing
//    a suite; we model a suite as that token-bracketed block:
//    Suite ::= "INDENT" Stmt "DEDENT". Displayed Python indentation corresponds
//    1-1 to INDENT ... DEDENT here. Layout only; never the semantics of a construct.
//
//  TWO MODELING DECISIONS SPECIFIC TO gcd (both faithful, both commented):
//
//  1. THE TUPLE SWAP  `a, b = b, a % b`.
//     Python evaluates the WHOLE right-hand side tuple `(b, a % b)` FIRST (against
//     the OLD store), then binds the targets simultaneously. The naive sequential
//     desugaring `a = b ; b = a % b` is WRONG: after `a = b`, the second statement
//     would compute `b = (new a) % b = b % b = 0`. So we model the simultaneous
//     bind with a TEMP holding the old `a`, exactly as the prompt directs:
//         a, b = b, a % b   ==>   t = a ;  a = b ;  b = t % b
//     With `t` capturing the OLD `a`, `b` becomes (old a) % (old b) -- faithful.
//     We desugar at the syntax level via a single rule so the spec can WRITE the
//     Pythonic `a, b = b, a % b` and have it mean the temp-based sequence.
//     (`t` is a fresh program name not used by gcd, so it cannot collide.)
//
//  2. THE TRUTHINESS GUARD  `while b:`.
//     Python's `while b:` tests truthiness of the integer `b`: the body runs iff
//     `b != 0`. We model the guard as the boolean `b =/=Int 0` by giving the bare
//     IExp-as-guard a coercion rule (Int N as a guard => N =/=Int 0). No general
//     `if`/Boolean algebra is needed -- only "nonzero is true".
// =============================================================================

module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  // ---- expressions ----------------------------------------------------------
  syntax IExp ::= Id | Int
                | "(" IExp ")"            [bracket]
                > IExp "%" IExp           [seqstrict, left]   // modulo (Python %)
                | Id "(" IExps ")"        [strict(2)]         // function call

  // The loop guard. gcd's guard is a bare expression `b` tested for truthiness;
  // we evaluate that IExp and coerce a nonzero Int to true (see the truthiness
  // rule below). A guard is therefore a (strict) IExp, plus literal Bools.
  syntax BExp ::= Bool
                | IExp                    [strict]

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
                | Id "," Id "=" IExp "," IExp                     // tuple swap (desugars)
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

  // Python % on integers is FLOOR modulo (result has the sign of the divisor);
  // modInt is K's floor modulo, matching Python exactly for the nonnegative
  // operands gcd uses. (For nonneg a,b with b>0, 0 <= a modInt b < b.)
  rule <k> I1:Int % I2:Int => I1 modInt I2 ... </k>
    requires I2 =/=Int 0

  // ---- truthiness guard: a bare Int used as a BExp is "nonzero == true" -------
  //   This is the ONLY Bool-coercion gcd needs: `while b:` runs the body iff b!=0.
  rule <k> I:Int => I =/=Int 0 ... </k> [owise]

  // ---- statement sequencing (newline) ---------------------------------------
  rule <k> S1:Stmt S2:Stmt => S1 ~> S2 ... </k>

  // ---- suite unwrapping -----------------------------------------------------
  rule <k> INDENT S:Stmt DEDENT => S ... </k>

  // ---- assignment ------------------------------------------------------------
  rule <k> X:Id = I:Int => .K ... </k>
       <store> STORE => STORE [ X <- I ] </store>

  // ---- tuple swap  a, b = b, a % b  -----------------------------------------
  //   Simultaneous bind, modeled with a temp capturing the OLD first target so
  //   the second RHS (`a % b`) reads the OLD `a`.  See MODELING DECISION 1.
  //   Desugars to: t = a ; a = b ; b = t % b   (general for any X, Y, E1, E2;
  //   for gcd specifically X=a,Y=b,E1=b,E2=a%b gives t=a; a=b; b=t%b).
  rule <k> X:Id , Y:Id = E1:IExp , E2:IExp
        => t = X ~> X = E1 ~> Y = (subst(E2, X, t)) ... </k>

  // subst(E, X, T): replace program name X by name T inside expression E, so the
  // second target's RHS reads the saved OLD value of X (here `a % b` -> `t % b`).
  syntax IExp ::= subst(IExp, Id, Id) [function]
  rule subst(Z:Id,        X, T) => T          requires Z  ==K X
  rule subst(Z:Id,        X, _) => Z          requires Z =/=K X
  rule subst(I:Int,       _, _) => I
  rule subst(A:IExp % B:IExp, X, T) => subst(A, X, T) % subst(B, X, T)

  // ---- while  (truthiness guard; no `if` is introduced) ----------------------
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
