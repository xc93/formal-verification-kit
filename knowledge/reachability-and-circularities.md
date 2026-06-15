# Reachability & Circularities — the proof technique and the recipe

The engine room: the one proof idea behind everything — **reachability rules** and the **Circularity rule** — and the numbered **recipe** `/formalize` and `/verify` follow. Read [`matching-logic.md`](matching-logic.md) for the logic underneath (patterns-as-sets, the connectives) and [`k-framework.md`](k-framework.md) for how this is written as K `claim`s, `kompile`/`kprove`, `seqstrict`/heating, and `[simplification]`. The fully worked instance: [`../examples/02-sum-up/`](../examples/02-sum-up/).

> **Fast-path scope.** Distilled for the common case: imperative functions with simple counting `while`/`for` loops over integers and maps. For recursion, recursive data structures (lists/trees/heaps), binders, or concurrency, it is a *starting point only* — escalate (see §7 and [`sources.md`](sources.md)). Worked examples are the best teacher; the example library will grow.

---

## 1. A reachability rule generalizes a Hoare triple

A **reachability rule** is a pair of configuration patterns

```
    φ  ⇒  φ'
```

read operationally: *every (terminating) execution from a state matching `φ` reaches a state matching `φ'`.* Each `φ` is a matching-logic pattern — a symbolic configuration `⟨…⟩` (the K cells `<k>`, `<store>`, …) conjoined with a first-order side constraint (`#And` a `requires`).

This is a Hoare triple `{Pre} code {Post}` recast so **the code itself lives inside the pattern** (in `<k>`) instead of being a separate syntactic object. The win is unification:

- **One operational semantics serves both execution and proof.** The same rewrite rules that *run* a program (`krun`) are the axioms you reason with (`kprove`) — no separate axiomatic/Hoare semantics to write, keep in sync, and trust (a classic soundness-bug source). `φ ⇒ φ'` *is* "the semantics, run symbolically from `φ`, lands in `φ'`."
- Pre/postconditions, frame conditions, and program text are all parts of one pattern, manipulated by one rule set.

A K `claim` *is* a reachability rule; [`../examples/02-sum-up/sum-up-spec.k`](../examples/02-sum-up/sum-up-spec.k) is two — the function contract `(SUM)` and the loop circularity `(LOOP)`.

---

## 2. The reachability proof system

Prove `A ⊢ φ ⇒ φ'` (the semantics `A` entails the rule) with these rules. The first six are routine symbolic execution + glue; the seventh, **Circularity**, is the whole point.

| Rule | What it does |
|---|---|
| **Reflexivity** | `A ⊢ φ ⇒ φ`. The zero-step execution. This is where guardedness bites: the circularity hypothesis is **forbidden** from closing a goal via Reflexivity alone (that would discharge the claim with zero progress — see §3). The hypothesis becomes available only on a goal that has already strictly advanced. |
| **Axiom** (+ framing) | Apply one semantic rule `φ_l ⇒ φ_r ∈ A` (with a substitution). **Framing** carries the untouched parts — the rest of `<k>`, unmentioned store bindings, the side constraint — unchanged around the step (K's automatic `...` cell-completion). |
| **Transitivity** | From `A ⊢ φ ⇒ φ₁` and `A ⊢ φ₁ ⇒ φ'`, get `A ⊢ φ ⇒ φ'`. Chains steps. |
| **Consequence** | Strengthen the pre / weaken the post via a **first-order implication** discharged by an SMT oracle (Z3) or `[simplification]` lemmas. Where arithmetic VCs are dispatched. |
| **Case Analysis** | Split a goal whose precondition is a disjunction `φ ≡ φ₁ #Or φ₂` and prove each branch (K's `#Or` split — e.g. loop guard `true` vs `false`). |
| **Abstraction** | Existentially quantify away variables in the precondition but **not** the postcondition (e.g. the overwritten initial values `∃S₀,I₀`). |
| **Circularity** | Use a rule as its own hypothesis — see §3. |

(See [`k-framework.md`](k-framework.md) for which K/`kprove` mechanism realizes each: `seqstrict` heating ↔ the operand micro-steps of Axiom, `#Or` ↔ Case Analysis, the SMT/`[simplification]` oracle ↔ Consequence, `...` ↔ framing. The `seqstrict` heating/cooling rules are themselves auto-generated semantic rules, applied *via* Axiom — not a separate proof rule.)

---

## 3. The Circularity rule — the key idea

```
    A ∪ {φ ⇒ φ'}  ⊢  φ ⇒ φ'
    ─────────────────────────
        A  ⊢  φ ⇒ φ'
```

You may **assume the very rule you are proving** while proving it — *provided* you use that hypothesis **only after at least one genuine `=>⁺` step** (one real semantic transition). This proviso is **guardedness**, and it makes the otherwise-circular argument a sound **guarded coinduction**: every appeal to the hypothesis is "paid for" by real progress, so you can never discharge the goal with zero work. Concretely, guardedness is enforced by **forbidding the hypothesis from closing a goal via Reflexivity** (zero steps): it is available only on a goal that has *strictly advanced*. That side condition is the whole soundness story.

**It replaces the loop invariant.** Classically you invent an invariant `Inv` and prove it established, preserved by the body, and implying the postcondition on exit. Here instead:

- The loop's **own reachability claim is the coinductive hypothesis.** Run the loop one step (evaluate the guard — the genuine `=>⁺` that earns the hypothesis), case-split on the guard, and in the *body-taken* branch reach the same loop in a shifted state, where you **invoke the claim on itself**.
- The role of the invariant is now played by the **closed-form expression in the claim's postcondition**, generalized over the accumulator/counter (e.g. the running sum `S + (I+N)·(N−I+1)/2`).

In [`../examples/02-sum-up/`](../examples/02-sum-up/) this is `(LOOP)`: running the loop from `i = I` (side condition `I ≤ N+1`) adds `Σ_{k=I}^{N} k = (I+N)·(N−I+1)/2` to `s` and leaves `i = N+1`. The guard-evaluation step discharges guardedness; the *guard-true* branch invokes `(LOOP)` at `{S := S+I, I := I+1}`; the *guard-false* branch (`I = N+1`) gives the empty sum `0`. K realizes this without ceremony: **every `claim` in the module is automatically a circularity available as a hypothesis.**

**The same principle covers recursion.** A recursive function's back-edge is the recursive call, so the **function's own contract is the coinductive hypothesis** — `f(N) ⇒ result(N)` discharges its inner `f(N−1)`. Guardedness comes from the **`call` step** taken before the hypothesis is reused, exactly as guard-evaluation does for a loop; the **base case** is the *exit* branch. See [`../examples/06-sum-recursive/`](../examples/06-sum-recursive/): `(REC)` `sum_recursive(N) ⇒ N*(N+1)/2` (side condition `N ≥ 0`) discharges `sum_recursive(N−1)`, with `n == 0` as the base case.

---

## 4. THE RECIPE

What `/formalize` then `/verify` actually do, step by step.

1. **Get a K semantics of the fragment (mini-X).** A minimal K semantics covering *only* the constructs the code uses — the "mini-X" stopgap, as the example builds *mini Python*: syntax + configuration cells + rewrite rules. See [`k-framework.md`](k-framework.md), and [`../examples/02-sum-up/mini-python.k`](../examples/02-sum-up/mini-python.k) for a complete one. *(Roadmap: full per-language K semantics replaces this step.)*

2. **State the function spec as a reachability rule** `φ_pre ⇒ φ_post`. A K `claim` whose `<k>` rewrites the program to `.K` (terminated), whose output cells assert the postcondition, and whose `requires` is the precondition (e.g. `N >= 0`). Cf. `(SUM)` with `result ↦ N*(N+1)/2`.

3. **For each loop (or recursive function), state the circularity claim.** A second `claim` for the loop alone, **generalized over the accumulator and counter** (symbolic `S`, `I`, not their entry values), with the loop's closed form in the postcondition. **Include the soundness side condition** bounding the counter, e.g. `I ≤ N+1`. This is not cosmetic: without it the claim is *false* (for `I ≥ N+2` the body never runs, so the true sum is `0`, but the closed form `(I+N)·(N−I+1)/2` goes **negative** — `N=0, I=2` gives `−1`).

   **For a recursive function** (no loop), state the **function-contract circularity**: `f(args) ⇒ result`, generalized over the symbolic argument(s), with the soundness precondition (e.g. `N ≥ 0`). K uses it as its own hypothesis for the recursive call; the *base case* is the non-recursive branch. See `(REC)` in [`../examples/06-sum-recursive/`](../examples/06-sum-recursive/).

4. **Prove it** by symbolic execution against the semantics:
   - Drive the `<k>` cell with the rules: `seqstrict` heating/cooling evaluates subexpressions, then the matching rule fires (these micro-steps *are* the manual "lookup/add/leq" steps of a paper proof).
   - **Case-split** on the loop guard (`#Or` between body-taken and exit) — or, for recursion, base vs. recursive branch.
   - After the loop body's step (or the recursive **`call`** step), **invoke the circularity** on the shifted state / recursive call (the coinductive appeal; legal because that genuine step provided guardedness).
   - **Discharge the arithmetic VCs** by Consequence — Z3 for linear facts, `[simplification]` lemmas for the rest.

5. **Compose the function-level proof via Transitivity.** `def` files the function → `call` binds parameters in a fresh scope → body init → **loop via the circularity used as a lemma** (instantiated at its entry state, e.g. `{S := 0, I := 1}`, precondition discharged) → `return` pops the frame and delivers the value. Result: `A ⊢ φ_pre ⇒ φ_post`.

`/verify` then emits the artifacts and exact `kompile`/`kprove` commands, labeled **"constructed, not machine-checked"** (the MVP does not run the toolchain), plus the test-redundancy and Findings reports.

**Beyond arithmetic — predicates and nested loops.** A postcondition need not be a closed form: it can be a **predicate** (*sorted*, *permutation*) written as a **spec-only abstraction function** declared `[function]` in `VERIFICATION` — e.g. `isSorted(List)` or a multiset `bag(List)`. And **nested loops nest their circularities**: one `claim` per loop, the **inner used as a lemma by the outer** (just as a recursive function's contract is reused by its caller). See [`../examples/12-insertion-sort/`](../examples/12-insertion-sort/) — claims `(SORT)` / `(OUTER)` / `(INNER)` — for both. (Discharging the *inductive* predicate VCs may hit the escalation boundary — §7.)

---

## 5. Partial vs total correctness

Circularity gives **partial correctness**: *if and when the loop terminates*, the postcondition holds. Guardedness yields coinductive soundness without a variant — it never asserts the loop *halts*. With no decreasing measure in the proof, termination is simply not established.

**Total correctness** additionally requires a **decreasing measure** (well-founded, e.g. `N − i`, bounded below `≥ 0` and strictly decreasing each iteration) to rule out infinite looping. The default is partial correctness; **flag total correctness as a recommendation and do not attempt it unless the user asks.** When asked: add the variant to the loop claim and discharge "strictly decreases, bounded below" alongside the existing VCs.

---

## 6. Discharging the verification conditions

The Consequence steps generate first-order **verification conditions (VCs)**. Two tiers:

- **Linear facts → Z3.** Side conditions like `N ≥ 0 ⇒ 1 ≤ N+1`, `I ≤ N ⇒ I+1 ≤ N+1`, and zero-factor simplifications are pure linear arithmetic; the SMT oracle handles them directly.
- **Nonlinear / division-by-even → `[simplification]` lemmas.** When a VC equates two distinct **symbolic products** under truncating `/Int` (not linear without an evenness justification), Z3 needs help. Supply `[simplification]` lemmas — e.g. **VC-EXACT**: a product of two consecutive integers is even, so every `/Int 2` here is *exact* and `(A − B)/2 = A/2 − B/2` on the even subgroup. The example's **VC1** (loop step: `I + cf(I+1,N) = cf(I,N)`) is exactly this; **VC2** (exit, zero factor) and **VC3** (init, `cf(1,N) = N*(N+1)/2`) fall to Z3 once the map-extensionality `[simplification]` reduces the cell equality to a scalar one. See [`k-framework.md`](k-framework.md) for writing these and the map-extensionality lemma `M[K<-V] #Equals M[K<-V'] ⇒ V #Equals V'`.

> **Spec-difficulty is a bug signal.** If you *cannot* find a clean closed form, precondition, or side condition — or the VCs refuse to discharge — do not paper over it. Surface it: that difficulty is usually a real missing case, off-by-one, or undefined behavior, and naming it is itself a deliverable (benefit #2). A side condition you are *forced* to add (like `I ≤ N+1`, or a precondition `N ≥ 0`) is often a precondition the code silently assumed and never checked.

---

## 7. Limits & escalation

The recipe handles **simple counting loops** *and* **simple recursion** (one accumulator/argument, integer/map state, a polynomial closed form) well — its sweet spot. **Recursion is covered** — see [`../examples/06-sum-recursive/`](../examples/06-sum-recursive/). It strains, and you should **escalate**, when the code involves:

- **Non-polynomial / multiplicative VCs** — e.g. factorial's `N! / (I−1)!`. The §6 tier discharges *polynomial* facts and division-by-even; an arbitrary multiplicative recurrence needs a recursively-defined symbol and its own `[simplification]` lemmas, which the recipe does not yet supply.
- **Recursive / inductive data structures** — lists, trees, heaps — and **relational postconditions** over them (sortedness, permutation), needing inductively defined predicates and multiset reasoning (often `μ`). See [`../examples/12-insertion-sort/`](../examples/12-insertion-sort/), which models a Python list and a **nested-loop** sort and reaches exactly this boundary.
- **Binders** (`λ`, quantifiers, local scoping captured semantically).
- **Concurrency / nondeterminism**, where `[all-path]` vs one-path reachability genuinely diverge.

**Escalation done right.** Escalating is **not** giving up. [`../examples/12-insertion-sort/`](../examples/12-insertion-sort/) shows the discipline: build the mini-X semantics, state **all** claims well-formed, **define the spec-only abstractions** the postcondition needs (`isSorted` as an inductive `Bool` function, `bag` as a multiset count-`Map`), discharge every VC the §6 tier *can* (in-bounds, linear), and mark the rest as explicit `[ESCALATION BOUNDARY]` obligations — **never fake them as `[trusted]`**, which manufactures confidence the kit lacks. Then route those named obligations to the papers. The deliverable stays honest *and* complete: open obligations are **specified**, not hidden.

**Escalation path.** Go to [`sources.md`](sources.md) and route **by topic**: reachability logic and the Circularity rule are **Roșu & Ștefănescu, *From Hoare Logic to Matching Logic Reachability* (FM 2012)** and **Roșu, Ștefănescu, Ciobâcă & Moore, *One-Path Reachability Logic* (LICS 2013)**; fixpoint/inductive reasoning is the μ-logic line (LICS 2019, OOPSLA 2020); binders have their own paper (ICFP 2020). `--refresh` re-fetches these live. The most reliable way to extend the kit to a new shape is **another worked example** — the example library is the growth lever.

---

### Cross-references

- [`../examples/`](../examples/) — the worked instances: [`sum-up`](../examples/02-sum-up/) / [`sum-down`](../examples/03-sum-down/) (loop circularities, `I ≤ N+1` / `I ≥ 0`) and [`sum-recursive`](../examples/06-sum-recursive/) (the **recursion** circularity `(REC)`).
- [`matching-logic.md`](matching-logic.md) — the underlying logic and connectives.
- [`k-framework.md`](k-framework.md) — `claim` syntax, `kprove`, heating, `[simplification]`, `/Int`.
- [`sources.md`](sources.md) — papers (FM 2012, LICS 2013, …) and the `--refresh` escalation path.
