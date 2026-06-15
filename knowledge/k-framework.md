# K Framework: writing a definition and a `kprove` claim

The **fast path** for the K mechanics `/formalize` and `/verify` need: writing a small K semantics for a code fragment (a "mini-X") and a `claim` that `kprove` can discharge. Distilled for the common case (an imperative function over integers, maps, lists). For anything outside that — recursive/heap data structures, binders/closures, concurrency, a real per-language semantics — treat this as a starting point and escalate via [`sources.md`](sources.md) (see [LIMITS + ESCALATION](#limits--escalation)).

Read alongside the worked sum example: [`../examples/02-sum-up/mini-python.k`](../examples/02-sum-up/mini-python.k) (the semantics) and [`../examples/02-sum-up/sum-up-spec.k`](../examples/02-sum-up/sum-up-spec.k) (the claims). Everything below is grounded in those two files and in K Tutorial **Lesson 1.22** ("Basics of Deductive Program Verification using K").

---

## 1. What K is

K is a framework for **rewrite-based executable semantics**. Write the syntax and operational rules of a language once; K turns that single definition into tools:

- **`kompile def.k --backend haskell`** — compiles the definition. For proofs use the **Haskell backend** (symbolic/reachability); the LLVM backend is the fast concrete interpreter.
- **`krun program`** — executes a concrete program under the semantics. Use it to sanity-check the semantics before proving.
- **`kprove spec.k`** — proves reachability **claims** against the compiled semantics by symbolic execution (rewriting with logical variables), discharging arithmetic/map side conditions via **Z3**. Output **`#Top`** = all claims proved; anything else is a residual obligation it could not close.

A rule `LHS => RHS` is both an execution step and a logical statement; a `claim` `LHS => RHS` is a *reachability* property "every (or some) execution from `LHS` reaches `RHS`." That overlap is why the same semantics both runs and verifies.

> MVP note: the kit **constructs** the definition, claims, and exact `kompile`/`kprove` commands but does not run the toolchain — artifacts are "constructed, not machine-checked." The mini-X fragment is a stopgap; full per-language K semantics is the roadmap.

---

## 2. Shape of a K definition

A set of `module`s, idiomatically split into a `*-SYNTAX` module (BNF) and a same-named main module (configuration + rules).

### 2a. The `*-SYNTAX` module — BNF with attributes

```
module MINI-PYTHON-SYNTAX
  imports INT-SYNTAX
  imports BOOL-SYNTAX
  imports ID-SYNTAX

  syntax IExp ::= Id | Int
                | "(" IExp ")"      [bracket]              // parsing only, no node
                > IExp "+" IExp     [seqstrict, left]      // > = lower precedence; left assoc
                | Id "(" IExps ")"  [strict(2)]

  syntax KResult ::= Int | Bool | Ints                     // the "fully evaluated" sorts
endmodule
```

Key attributes:

- **`strict` / `seqstrict`** — declare evaluation order; they generate the small-step stepping (Section 3). `strict(2)` = evaluate the 2nd argument before applying the rule.
- **`left`** — associativity, to disambiguate `a + b + c`.
- **`bracket`** — `( )` is grouping only; no AST node.
- **`token`** — makes a literal lex as a terminal of a sort (e.g. `syntax Id ::= "$a" [token]`). Not needed in the sum example: program vars are lowercase `Id`s, which never collide with K's uppercase/`?`-prefixed logical variables.
- **`syntax KResult ::= ...`** — declares which sorts count as *values*. Strictness checks against this (`isKResult`); get it wrong and evaluation never stops heating or stops too early. Sum example: `syntax KResult ::= Int | Bool | Ints`.

### 2b. The main module — configuration + rules

```
module MINI-PYTHON
  imports MINI-PYTHON-SYNTAX
  imports INT     // +Int, -Int, *Int, <=Int, /Int, modInt, ...
  imports BOOL    // andBool, orBool, notBool, ...
  imports MAP     // M[K <- V] update,  K |-> V binding,  .Map empty
  imports LIST    // ListItem(_),  .List empty

  configuration
    <k> $PGM:Stmt </k>        // the computation: a ~>-separated list of work
    <store> .Map  </store>    // program variables   Id |-> Int
    <funcs> .Map  </funcs>    // function table       Id |-> (def ...)
    <stack> .List </stack>    // call stack of saved (continuation, store)

  rule <k> I1:Int + I2:Int => I1 +Int I2 ... </k>          // builtin INT
  rule <k> X:Id => V ... </k>  <store> ... X |-> V ... </store>
endmodule
```

- The **configuration** is a tuple of named **cells**. `<k>` is special: it holds the *computation* as a `~>`-separated list, where **`~>` is the cons** ("do this, then that") and **`.K` is the empty computation**.
- A **rule** rewrites with `=>`. `...` inside a cell means "the rest is unchanged/irrelevant" — `<k> X => V ... </k>` rewrites only the head; `<store> ... X |-> V ... </store>` matches `X` anywhere in the map.
- **`requires`** adds a `Bool` side condition that must hold for the rule to fire, e.g. `rule <k> I1 / I2 => I1 /Int I2 ... </k> requires I2 =/=Int 0`.
- Builtins you will lean on: **`+Int`, `<=Int`, `/Int`** (truncates toward zero; `divInt` floors), `modInt`; map **`M[K <- V]`** (update) and **`K |-> V`** (single binding); `LIST` with `ListItem(_)` and `.List`.

---

## 3. Strictness ⇒ heating / cooling (the small-step engine)

You do not hand-write the stepping for `a + b`. `seqstrict` on `IExp "+" IExp` **auto-generates** heating `[heat]` and cooling `[cool]` rules that pull a subexpression to the front of `<k>`, evaluate it, then plug the value back:

```
rule <k> HOLE +  E2:IExp => HOLE ~>  [] + E2 ... </k> requires notBool isKResult(HOLE) [heat]
rule <k> E1:IExp  + HOLE => HOLE ~> E1 +  [] ... </k> requires isKResult(E1)            [heat]   // seqstrict: left first
rule <k> HOLE ~>  [] + E2:IExp => HOLE +  E2 ... </k>                                   [cool]
rule <k> HOLE ~> E1:IExp +  [] => E1  + HOLE ... </k>                                   [cool]
```

(The sort-annotated siblings `E2:IExp` / `E1:IExp` mirror the form K's strictness machinery generates; these are illustrative, simplified versions of the compiler-generated rules.)

`HOLE` is the term being evaluated; the compiler attaches the `isKResult(HOLE)` / `notBool isKResult(HOLE)` side conditions. `seqstrict` sequences the arguments (left, then right) by gating the second heat on the first being a `KResult`; plain `strict` leaves the order nondeterministic. This heating/cooling *is* the small-step semantics: a nested expression reduces one operator at a time at the head of `<k>`. You write only the value-level rules (`I1:Int + I2:Int => I1 +Int I2`); strictness supplies the rest.

> Gotcha (from the sum build): the `while` loop must keep an **unevaluated** copy of the guard frozen (inside `#whileLoop(B, S)`) and evaluate a **fresh** copy at the head of `<k>`. Heating rewrites only the head, so the frozen copy survives to be re-checked next iteration. See the `while`/`#whileLoop` rules in `mini-python.k`.

---

## 4. Claims: the spec module

A spec file `requires` the semantics and defines a `VERIFICATION` module (semantics + symbolic helpers), then a spec module holding the `claim`s.

```
requires "mini-python.k"

module MINI-PYTHON-SPEC-SYNTAX
  imports MINI-PYTHON-SYNTAX        // (+ any [token] declarations for program vars)
endmodule

module VERIFICATION
  imports MINI-PYTHON-SPEC-SYNTAX
  imports MINI-PYTHON
  imports MAP-SYMBOLIC             // symbolic reasoning over maps (extensionality etc.)
  imports K-EQUAL                  // #Equals and friends
  // ... simplification lemmas go here (Section 6) ...
endmodule

module MINI-PYTHON-SPEC
  imports VERIFICATION
  // ... claims go here ...
endmodule
```

A **claim** has a configuration's shape, but cells carry `=>` rewrites and logical (symbolic) variables:

```
claim
  <k> while i <= n : INDENT s += i  i += 1 DEDENT => .K ... </k>
  <store>
    s |-> (S:Int => S +Int (I +Int N) *Int (N -Int I +Int 1) /Int 2)
    i |-> (I:Int => N +Int 1)
    n |-> N:Int
  </store>
  requires I <=Int N +Int 1
  [all-path]
```

- **`<k> LHS => RHS ...`** — start from `LHS`; the claim asserts the program runs to `RHS` (`=> .K` = "and terminates").
- **store rewrites `x |-> (OLD => NEW)`** — `x` starts `OLD`, ends `NEW`. Untouched bindings (`n |-> N`) just constrain the input.
- **`requires`** — the **precondition**, e.g. the loop side condition `I <=Int N +Int 1` or the function precondition `N >=Int 0`.
- **`ensures`** — the **postcondition**: extra constraints after execution. Use **`?`-prefixed existentials** for "some value exists": `?C:Int` in the configuration and `ensures (?C ==Int A) orBool (?C ==Int B)` (Lesson 1.22 §3.3). `<funcs> .Map => ?_:Map` = "ends in some unconstrained map."
- **`[all-path]` vs `[one-path]`** — `[all-path]`: **every** path from `LHS` reaches `RHS` (what the sum proof uses). `[one-path]`: **some** path does. Or set a module default / `--default-claim-type`.

---

## 5. Circularities (loops and recursion)

K's reachability prover treats **every claim in the module as a coinduction hypothesis** (a *circularity*). This lets a loop claim **discharge its own loop**: after one iteration the proof reaches a state matching the same claim, and the coinduction hypothesis closes it. So you state the loop invariant *as a claim* and it proves itself; other claims (e.g. the function contract) may **reuse that loop claim as a lemma**.

Two attributes you may need:

- **`[trusted]`** — assume a claim as already proven (added to the proven circularities without proof). Use sparingly, to stage a proof or admit an axiom.
- **`[simplification]`** rules — **user lemmas** the prover applies anywhere their LHS matches (they do *not* complete to the top of the configuration). These feed K the arithmetic/map facts it needs to discharge a side condition — the **verification-condition oracle**. A `[simplification]` rule fires only when the current side condition *implies* its `requires`, so it is sound to add (you own its soundness — it must preserve definedness; see manual §`simplification`).

---

## 6. The Lesson 1.22 pattern (cite)

Lesson 1.22 verifies *this exact* sum function and is the template the mini-Python example follows. Ingredients:

- **Configuration** `<k> / <store> / <funcs> / <stack>`: computation, variable store, function table, call stack of saved `state(continuation, store)` frames.
- **Statements**: assignment `x = e`, `if`, `while`, `def`, `return`, `call`. (Mini-Python drops `if` — not needed for `sum` — and adds `x += e`, desugared to `x = x + e`.)
- **Two claims**, both `[all-path]`:
  1. a **loop-invariant claim** over the `while` body (the circularity that proves itself), and
  2. a **function claim** (`def sum` then `result = sum_to_n(N)` stores `N*(N+1)/2`), reusing the loop claim.
  Run `kprove`; success is **`#Top`**.
- **The Bot / Bots shared-`klabel` list trick.** Evaluated arguments (`Int`s, which are `KResult`s), parameters (`Id`s), and source expressions (`IExp`s) must all be lists with a *shared* spine so the seqstrict argument list can **cool to an `Ints` `KResult`**:

  ```
  syntax Bot
  syntax Bots  ::= List{Bot,  ","} [klabel(exps)]
  syntax Ints  ::= List{Int,  ","} [klabel(exps)] | Bots   // evaluated args, a KResult
  syntax Ids   ::= List{Id,   ","} [klabel(exps)] | Bots   // parameters
  syntax IExps ::= List{IExp, ","} [klabel(exps), seqstrict] | Ints | Ids
  ```

  The shared `[klabel(exps)]` makes `Ints` and `Ids` both subsorts of the strict `IExps`, so an evaluated `IS:Ints` is a legal call argument and `.Bots` is the single empty terminator usable as both `.Ids` and `.Ints`.

The sum spec needs two `[simplification]` lemmas beyond Lesson 1.22's down-counting loop (which needed none), because the **up-counting** invariant divides a *symbolic* product and the inductive step equates two distinct products under truncating `/Int`:

```
// map extensionality: closes the post-store implication (result <- V)
rule { M:Map [ K <- V ] #Equals M:Map [ K <- V' ] } => { V #Equals V' } [simplification]

// exact halving of an always-even product of consecutive integers
rule (X:Int *Int (X +Int 1)) /Int 2 *Int 2 => X *Int (X +Int 1) [simplification]
rule ((A:Int +Int B:Int) *Int C:Int) /Int 2 *Int 2 => (A +Int B) *Int C
  requires ((A +Int B) *Int C) modInt 2 ==Int 0 [simplification]
```

---

## 7. Common gotchas (the kind `/formalize` must avoid)

These bit the sum build; surfacing them early is part of the "difficulty writing a clean spec is itself a bug signal" discipline.

- **List-sort / `KResult` subsorting.** Evaluated argument lists must subsort into a `KResult` (the Bot/Bots `[klabel(exps)]` trick, Section 6). Skip it and the seqstrict arg list never cools — the call rule can't fire and `kprove` stalls before reaching the interesting goal.
- **Statement-sequencing parse ambiguity vs. suite priority.** `Stmt Stmt [left]` (sequencing) must bind **looser** than suite-headed/leaf statements, and a `Suite` (`INDENT Stmt DEDENT`) must be self-delimiting, or the parser cannot tell where a `while`/`def` body ends. Mini-Python enforces this with the `>` precedence block putting sequencing last.
- **Map extensionality `[simplification]`.** Postconditions that pin a result land in the store as `STORE [ result <- V ]`; closing the implication needs `{ M[K<-V] #Equals M[K<-V'] } => { V #Equals V' }`. Without it the `ensures`/store goal stays open (Lesson 1.22 §3.3).
- **Exact-halving `[simplification]` when dividing a symbolic product.** `/Int` truncates, so Z3 will not on its own equate `(P /Int 2) *Int 2` with `P` for a symbolic product `P` — supply the "this product is even, so halving is exact" lemma (guarded by `modInt 2 ==Int 0`).

---

## Lists / arrays & spec-only abstraction functions

To model a Python **list/array**, use K's builtin `List` (a *value* sort): `size(L)`, element read `L[I]`, functional update `L[I <- V]`, `ListItem(_)` / `.List`. Because `List` is a value (not a heap reference), Python's copy semantics and **non-aliasing** fall out for free — `list(L)` is identity, and an index-assign rebinds the variable to a new `List`. (Generalize the call machinery's evaluated-args list from `Int` to `KResult` so a `List` value can be passed.)

When a postcondition is **relational** (*sorted*, *permutation*) rather than an arithmetic closed form, declare **spec-only abstraction functions** `[function]` in the `VERIFICATION` module and use them in `ensures` — e.g. `isSorted(List)` (an inductive `Bool` function) and a multiset `bag(List)` (a value→count `Map`, so `bag(X) ==K bag(Y)` *is* "X is a permutation of Y"). These are **spec vocabulary, not language constructs**. **Caveat:** the bundled `[simplification]` tier does *not* discharge inductive-predicate or multiset VCs — state those as `[ESCALATION BOUNDARY]` obligations and route to the papers; do **not** fake them as `[trusted]`. Worked example: [`../examples/12-insertion-sort/`](../examples/12-insertion-sort/).

**Minimal, but still property-complete — never abstract away the property under test.** Shrinking the language to mini-X or replacing a structure with a spec-only abstraction is sound only when the model that remains can **still express and distinguish pass from fail for the exact property being verified**. Abstracting away *state* is fine; abstracting away the *property* is not. The axis the change manipulates and the tests measure — the value, the type, the structure, the order, the shape, the cardinality — must survive into the model's observable; if you collapse it into an opaque symbol and then prove something over that symbol, every obligation is **vacuous with respect to the defect** and the proof certifies nothing. Discriminator test: before trusting an abstraction, exhibit one concrete *passing* and one concrete *failing* instance of the property and confirm the abstraction maps them to **different** values. If it cannot — if the property under test is structurally unrepresentable in your model, or you find yourself forced to fence the only region that carries it as an escalation boundary — the property is **un-assessable**; declare it so as an explicit `[ESCALATION BOUNDARY]`, never certify it "unchanged / correct" over a model that cannot see it. **Balance:** minimality is still the goal (model only the constructs the code uses); the constraint is that the *property's* axis is not among the things you drop.

**Validate against an independent reference, never one derived from the artifact under test.** A check is only meaningful if its ground truth is **independent of the object being verified**. Deriving the expected value, the reference structure, or the oracle from the *same* code/output/structure you are checking yields only **self-consistency** — it confirms internal coherence while staying blind to a whole missing dimension (a dropped attribute, branch, or value axis). Require at least one externally anchored concrete value (from the prompt, docs, an independent computation, or a named default-domain fact) or an oracle the implementation did not produce. If the only thing your proof compares the code against is something the code itself emitted, you have a **circular proof** — surface it as a Finding, not a positive result.

## LIMITS + ESCALATION

This file is the **fast path**: an imperative function over ints/maps/lists, with a loop-invariant claim and a function contract, in the Lesson 1.22 style. Enough for the common case and the bundled sum example, but deliberately narrow.

You will need more than this primer for, among others:

- **recursive / heap-allocated data structures** (lists, trees, separation-style heaps),
- **binders, closures, scope** (anything where variable capture matters),
- **concurrency / nondeterminism**, exceptions, I/O,
- a **real per-language semantics** instead of a mini-X fragment (the roadmap; mature K semantics for C, Java, JavaScript, EVM, etc. exist in the K ecosystem).

When the recipe here does not cover your case, **escalate via [`sources.md`](sources.md)** — the first-class path to the K manual, the K tutorial (Lesson 1.22 and neighbors), and matching-logic references — and re-derive from there (`--refresh` pulls current upstream docs). Do not invent K features to force a fit; if you cannot write a clean definition or claim with the constructs above, say so and route to the deeper sources. Worked examples are the growth lever: prefer extending the example library over stretching this primer.
