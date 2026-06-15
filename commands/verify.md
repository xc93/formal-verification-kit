# `/verify` — construct the correctness proof and emit the artifacts

Take the formal specs from [`formalize.md`](formalize.md) and **construct a correctness proof** of them — symbolic execution against the K semantics, the loop circularity discharged by coinduction, the arithmetic verification conditions checked — then write out the proof, the `.k` files, and the exact `kompile`/`kprove` commands so a human can machine-check it later.

`/verify` is also a **feedback generator** for the next code iteration: every proof obstacle — a side condition, a failed VC, a non-universal postcondition, a termination gap, an escalation boundary — becomes a proof-derived Finding and actionable guidance for the next prompt / code-generation pass.

Agent-agnostic; no arguments → the whole program / each function in it.

**Two benefits, even for a user who never reads the proof:**

1. **Fewer tests, faster CI.** A verified function is proven correct for *all* inputs in its domain, so unit tests re-checking in-domain points become redundant. Report exactly which tests are subsumed and the CI time saved — **a recommendation, never an auto-delete** (see the Honesty gate).
2. **Finds hidden, subtle bugs.** If constructing the proof **fails or gets stuck** — a VC won't discharge, a side condition must be invented, a postcondition doesn't hold universally — that is a *strong bug signal*. Surface it in plain language into the Findings report, and say what the next code generator or UltimatePowers-style intent pass should ask, change, or test.

> **MVP scope.** `/verify` **constructs** the proof and emits the artifacts and run-commands; it **does NOT run `kompile`/`kprove`** in this version. Every result is labeled **"constructed, not machine-checked."** Running the toolchain (which also enables *confident* test removal) is on the roadmap.

Read the primers first if not already internalized — especially [`../knowledge/reachability-and-circularities.md`](../knowledge/reachability-and-circularities.md) (the proof technique + the numbered recipe), [`../knowledge/k-framework.md`](../knowledge/k-framework.md), [`../knowledge/matching-logic.md`](../knowledge/matching-logic.md), and [`../knowledge/intent-evidence.md`](../knowledge/intent-evidence.md). Pick the **closest example by shape** in [`../examples/`](../examples/) (reference pair: [`sum-up`](../examples/02-sum-up/PROOF.md) / [`sum-down`](../examples/03-sum-down/PROOF.md)); for recursion, recursive data structures, binders, or concurrency, escalate by topic via [`../knowledge/sources.md`](../knowledge/sources.md) (optional `--refresh`).

---

## Steps

### Step 1 — Ensure the specs exist, then run the adequacy gate

`/verify` proves what `/formalize` wrote. If the spec artifacts are missing — `mini-<lang>.k`, `<program>-spec.k` (function contract + each loop circularity), the spec note — **run [`/formalize`](formalize.md) first**, then continue. Do not invent specs here; `/verify`'s job is to *prove* a stated contract, not choose it.

If after `/formalize` there is still no `mini-<lang>.k` or no `<program>-spec.k` with real K `claim` blocks, **stop: the run is invalid/unresolved.** A Markdown-only proof discussion is not `/verify` and must not be presented as FVK success.

Confirm each function has a reachability-rule `claim` (`φ_pre ⇒ φ_post`, with the `requires` precondition) and each loop its circularity `claim` (generalized over accumulator/counter, with the soundness side condition). Worked pair: [`../examples/02-sum-up/sum-up-spec.k`](../examples/02-sum-up/sum-up-spec.k) — `(SUM)` (`requires N >=Int 0`, result `N*(N+1)/2`) and `(LOOP)` (side condition `I <=Int N +Int 1`).

Confirm `SPEC.md` has a public intent ledger and that nontrivial claims/circularities carry provenance comments. If provenance is missing, incomplete, contradicted by the proof, or an ordered expected result cites only the candidate implementation / legacy behavior rather than prompt/docs/tests or a named default-domain order, record a proof-derived Finding and ask for `/formalize` to be repaired before relying on the proof. If a claim is supported only by an in-repo/public test that conflicts with the public issue intent, mark it **SUSPECT** instead of proving legacy behavior as authoritative. A `V2 == V1` / no-change conclusion is **invalid** if any order/precedence/winner claim needed to justify no change is still implementation-derived or ambiguous, **or if it rests on a SUSPECT test or pre-fix display, or on a concrete change the audit named and then dropped on scope grounds**; the audit boundary is the **full intent**, not the issue sentence.

**A discharged proof is a *soundness* result over the stated claims — it is silent on *completeness* against the full intent.** Proving every claim the candidate makes shows the candidate is correct *for what it claims*; it does **not** show the patch **fixes the whole intent**. (This `soundness`/`completeness` pair is the *audit-coverage* sense — distinct from the proof-system metatheory and from the set-membership-vs-ordering use of "completeness" in `formalize.md`.) So a green proof is **necessary, not sufficient**, for accepting a patch: closing the unit proof must never be read as "the fix is done" or as license for a `V2 == V1` conclusion. After the proof discharges, run the completeness check explicitly — "does the proven contract span the *entire* intended behavior space (every branch, every in-domain input class, every contributor to the observable), or only the slice the claims happened to cover?" — and route any uncovered part of the intent to a proof-derived Finding (Step 3). A region the claims never reached is **un-audited**, not proven correct. **Balance:** this does not weaken the soundness result you do have — report what is proven as proven; the point is to not let the proven slice stand in for the unproven remainder.

**Formal adequacy gate** — run before trusting any proof result:

1. Confirm `INTENT_SPEC.md`, `PUBLIC_EVIDENCE_LEDGER.md`, `FORMAL_SPEC_ENGLISH.md`, `SPEC_AUDIT.md`, and `PUBLIC_COMPATIBILITY_AUDIT.md` exist and are non-empty.
2. Read `FORMAL_SPEC_ENGLISH.md` as if it were the only spec. Does it say exactly what `INTENT_SPEC.md` requires — no weaker and no stronger on order/winner/frame conditions?
3. If `SPEC_AUDIT.md` marks any required behavior fail/ambiguous, or the compatibility audit has an unhandled callsite/subclass override, the proof does not justify success or `V2 == V1`. Record the mismatch as a proof-derived Finding for the next code/spec pass.

### Step 2 — Construct the proof

Build the proof by **symbolic execution against the K semantics**, faithful to the rewrite rules of `mini-<lang>.k` (recipe: [`../knowledge/reachability-and-circularities.md`](../knowledge/reachability-and-circularities.md) §4). Three moving parts, then compose:

- **Symbolic execution.** Drive the `<k>` cell with the rules. `seqstrict` heating/cooling evaluates sub-expressions left-to-right (these micro-steps *are* the manual `(lookup)`/`(add)`/`(leq)` steps of a paper proof); then the matching rule fires. Chain steps by **Transitivity**; carry untouched cells / bindings / the side constraint by **framing** (K's automatic `...` cell-completion).

- **Circularity discharge (the loop, or the recursive call).** Prove each circularity by **guarded coinduction**: K adds every `claim` in the module to its hypotheses, so the claim may assume itself — but only **after ≥ 1 genuine `=>⁺` step** (evaluating the guard, or for recursion the `call` step, is that step; this is *guardedness*). Then **case-split on the guard** (`#Or`): in the body-taken branch run the body and **invoke the circularity on the shifted state** (e.g. `{S := S+I, I := I+1}`, its precondition re-checked); in the exit branch the counter is pinned (e.g. `I = N+1`) and the closed form collapses (empty sum `0`). Both branches must land on the claimed post-state. *(Recursion is the same move: the genuine step is the `call`, the case-split is base vs. recursive branch, and you invoke the contract on the recursive call — see [`../examples/06-sum-recursive/`](../examples/06-sum-recursive/).)* The closed-form postcondition (e.g. the running sum `(I+N)*(N−I+1)/2`) plays the role of the classical loop invariant.

- **Arithmetic VCs.** **Consequence** steps generate first-order VCs. Discharge **linear facts with Z3** (side conditions like `N ≥ 0 ⇒ 1 ≤ N+1`, `I ≤ N ⇒ I+1 ≤ N+1`, zero-factor exits); for VCs equating two **symbolic products** under truncating `/Int`, supply `[simplification]` lemmas (e.g. **VC-EXACT**: a product of two consecutive integers is even, so each `/Int 2` is exact and `(A−B)/2 = A/2 − B/2` on the even subgroup), plus the map-extensionality lemma `{M[K<-V] #Equals M[K<-V']} => {V #Equals V'}` (defined verbatim in [`../knowledge/k-framework.md`](../knowledge/k-framework.md) §6) to reduce a cell `#Equals` to a scalar one.

**Compose the function proof** by Transitivity: `def` files the function → `call` binds parameters in a fresh scope → body init → **the loop via its circularity used as a lemma** (instantiated at its entry state, precondition discharged) → `return` pops the frame and delivers the value. Result: `A ⊢ φ_pre ⇒ φ_post`.

Default scope is **partial correctness** (if/when the loop terminates, the postcondition holds). **Termination is a recommendation, not proved** unless the user asks; when asked, add a decreasing measure (e.g. `N − i`, bounded below by `0` and strictly decreasing per iteration) to the loop claim and discharge it alongside the VCs.

> **If construction fails or gets stuck — that is a finding, not a dead end.** A VC that won't discharge, a side condition you are *forced* to invent, a postcondition that fails for some in-domain input, a loop with no clean closed form — surface each one as a proof-derived Finding (Step 3). Difficulty proving a clean contract is itself a strong bug signal (benefit 2).
>
> But distinguish *correctness* gaps from **capability** gaps. When a VC is beyond the bundled tier (an inductive-predicate or multiset fact — e.g. sortedness / permutation), that is **not** a code bug: state it as an explicit `[ESCALATION BOUNDARY]` obligation, discharge everything the bundled tier *can*, and route the rest to the papers — **never admit it as `[trusted]`** (that fakes confidence the kit does not have). See [`../examples/12-insertion-sort/`](../examples/12-insertion-sort/).

**"Forced" choices are hypotheses to falsify, not premises.** Treat any claim that a concrete choice — an ordering, a value, a branch — is *uniquely forced*, or that "the alternative would break X / backward-compatibility requires it," as a hypothesis to falsify. Procedure: name the concrete alternative; write its predicted output explicitly; re-derive the legacy / backward-compat trace under **both candidates side by side** (a two-column derivation). Keep the "forced" value **only** if the alternative demonstrably fails a public obligation. If both candidates satisfy the public obligations the choice is **under-determined, not forced** — record it as open, never as CONFIRM. Never assert a derived "forced" value, and never predict a hidden test's value from such an argument, without that side-by-side derivation.

This governs **placement / evaluation-point** choices too. When *where* a value takes effect is under-determined, you may **not** break the tie with a fresh secondary convention (e.g. "this transform is opt-in", "similar values already live in method `M`") to land on the current implementation — an under-determined choice resolved toward V1 is a Finding, not a confirmation. Resolve it from the issue's desired output **form**: a value shown bare (no opt-in call) must hold on the default/construction path. And if you find yourself predicting the chosen placement would fail "if it were tested," that prediction *is* the falsification — switch to the placement that satisfies the bare-form obligation.

### Step 3 — Accumulate proof-derived findings for the next generation

Treat `/verify` as a critic for the whole generate→formalize→verify loop, not just a proof writer. Append or update `FINDINGS.md` with a dedicated **Proof-derived findings from `/verify`** section, and summarize the same points in `PROOF.md`. For every proof obstacle or proof-discovered fact, write an actionable entry:

- **A named change must not be dropped on scope grounds.** If the audit **names a concrete change** (quotes or describes a specific edit) and then declines it, **promote it to a tested hypothesis**: write its claim and check it against the **full intent**. "Exceeds the issue/hint scope," "conventionally wrong but accepted," or "out of scope" are **not** sufficient reasons to discard a named, intent-consistent change — especially under hidden tests, where "current behavior" cannot be confirmed. *Balance:* promote it as a hypothesis to **test** against intent (it may still be rejected on positive intent grounds) — this is not a license to apply every named change.
- **Evidence** — the exact claim, branch, VC, circularity side condition, or proof step where the issue appeared, plus the public intent-ledger entry it supports or contradicts.
- **Localize from the symptom, not from the diff.** Find where behavior diverges from intent by reasoning from the **reported wrong behavior backward through the semantics** to the branch that produces it — do **not** assume the bug lives at the lines the candidate patch already changed. A clean proof over the patched lines does **not** close the case if another reachable branch still violates the intent. Two forcing functions: (a) **Quoting the symptom is not localizing the cause.** Reproducing the issue's error string / symptom text in the artifacts shows you found the symptom, not that your modeled mechanism produces it — apply the *pointed-at-the-spot* test to the **cause**: would a knowledgeable reader agree the mechanism in your spec is what generates the observed failure? (b) **Adversarial reproduction.** Try to *construct the reported failure symbolically on the pre-fix code via your modeled mechanism*, then show the fix removes it. If you **cannot** derive the symptom from the mechanism you specified, your mechanism is probably not the bug — **re-localize** rather than certifying the candidate. When a remedy co-ships several edits, center the spec on the contributor that produces the **observed/graded symptom**, not the sub-issue the issue text spells out most; localizing *a* real defect is not localizing *the* operative one. (Reference the **full intent** audit boundary in Step 1; this adds *where to look*, not a new boundary.)
- **Classification** — one of: code bug, missing precondition, underspecified intent, needed code guard, termination/performance gap, test gap, or proof capability gap / `[ESCALATION BOUNDARY]`.
- **UltimatePowers question** — the next question the intent-elicitation layer should ask the user (e.g. "Should negative `n` raise, return `0`, or be outside the domain?" / "For duplicates, any match or the leftmost match?").
- **Recommended next code/spec change** — the concrete guard, contract change, algorithm change, or spec refinement to feed back into the code generator.
- **Tests** — tests to add, keep, or conditionally remove after machine-checking.

Include adequacy obstacles too: a claim whose English paraphrase over-preserves a legacy behavior, omits a prompt behavior, chooses an order/winner without public support, or closes while `PUBLIC_COMPATIBILITY_AUDIT.md` has an unhandled public callsite/override is a proof-derived Finding. Fix by repairing the spec, repairing the code, or asking a clarification; never use the proof to bless the mismatch.

Stop with the accumulated findings. Do **not** regenerate or patch code during `/verify` unless the user asks for a repair pass; the default output is the evidence package that a conventional code generator can use for a better next iteration.

Examples:

- `sum_to_n`: proof needs `N >= 0` ⇒ missing precondition / needed guard; ask: reject negatives, return `0`, or define a signed sum?
- `binary_search`: proof needs sorted, totally ordered inputs and only proves "some matching index" ⇒ clarify sortedness, NaN/mixed-type policy, duplicate semantics.
- `insertion_sort`: sortedness/permutation VCs hit list/multiset induction ⇒ mark `[ESCALATION BOUNDARY]` and keep tests until the inductive theory and `kprove` close the obligations.

### Step 4 — Test-redundancy report (benefit 1)

Map the project's existing tests onto the verified spec and classify each:

- **Redundant** — any test whose assertion is **entailed by what was proved, within the verified domain**. A machine-checked contract holds for *every* in-domain input, so a unit test asserting one in-domain input/output point is subsumed. Show the one-line reason (`sum_to_n(5) == 15` → `5*6/2 = 15`, `5 ≥ 0` → subsumed) and recommend removal (**conditioned on machine-checking** — see the Honesty gate), with an estimate of **CI time saved**.
- **Keep** — explicitly — every test the proof does *not* cover: **out-of-domain** inputs (e.g. `n < 0` when the precondition is `n ≥ 0` — often exactly where a Findings bug lives), **termination/performance** tests (partial correctness says nothing about halting or speed), and **integration/end-to-end** tests (the proof covers the unit, not the wiring).
- **Recommendation-only. NEVER auto-delete.** Propose removals and explain them; do not touch the test files. (An opt-in `--apply` is a later option.)

Worked instance: [`../examples/02-sum-up/PROOF.md`](../examples/02-sum-up/PROOF.md) §6 — `sum_to_n(5)==15`, `sum_to_n(1)==1`, `sum_to_n(0)==0` flagged redundant; the out-of-domain `sum_to_n(-1)==0` boundary test **kept**. Imitate that shape.

### Step 5 — Emit artifacts

Write out, alongside the code, everything needed to machine-check the proof later:

- the **proof write-up** (condensed, in the shape of [`../examples/02-sum-up/PROOF.md`](../examples/02-sum-up/PROOF.md): function claim, loop circularity, short English proof, machine-detailed sketch, and the two plain-language benefit payoffs);
- the **updated Findings report**, including the proof-derived entries from Step 3;
- the **evidence/adequacy/compatibility audits** — `INTENT_SPEC.md`, `PUBLIC_EVIDENCE_LEDGER.md`, `FORMAL_SPEC_ENGLISH.md`, `SPEC_AUDIT.md`, `PUBLIC_COMPATIBILITY_AUDIT.md`;
- the **`.k` files** — `mini-<lang>.k` and `<program>-spec.k`;
- the **exact run-commands**:

  ```sh
  kompile mini-<lang>.k --backend haskell  # compile the fragment semantics (Haskell backend, required to prove)
  kast    --backend haskell <program>-spec.k # (optional) confirm the claim program parses to one AST
  kprove  <program>-spec.k                 # discharge the claims; expected: #Top  (all proved)
  ```

**Label everything "constructed, not machine-checked."** A `#Top` from `kprove` is what upgrades the result from *constructed* to *machine-verified*.

### Step 6 — Report

Produce the human-readable report:

- **What's proved** — the function contract(s) and loop circularity(ies), in plain language (e.g. "for every `n ≥ 0`, `sum_to_n(n) = n*(n+1)/2`, if and when it terminates").
- **Residual risk** — partial vs total correctness (termination not proved unless asked); the **trusted base** (adequacy of the mini-X fragment semantics; the reachability proof-system metatheory and `kprove`; the SMT/`[simplification]` oracle); and the **"constructed, not machine-checked"** caveat with the run-commands.
- **The test-redundancy recommendation** (Step 4), with the conditioning below.
- **The Findings entries** — and if verification **failed or got stuck**, surface that **prominently as a strong bug signal** into the Findings report (benefit 2). A side condition you were forced to add (`I ≤ N+1`, or a precondition `N ≥ 0`) is usually a precondition the code silently assumed and never checked; report it with a concrete `input → observed vs expected`, the way [`../examples/02-sum-up/PROOF.md`](../examples/02-sum-up/PROOF.md) §5 does for the `n < 0` case.

---

## Honesty gate (must be explicit)

The MVP **constructs** the proof but **does NOT run `kprove`**. Therefore:

- **Test removal is a recommendation *conditioned on machine-checking*.** Advise running the emitted `kompile`/`kprove` commands first, or keeping the tests until the claims actually discharge (`kprove` returns `#Top`). Only then are the deletions safe.
- **Never auto-delete tests**, and **never claim confidence the un-machine-checked proof does not yet have.** Say plainly: "constructed, not machine-checked."
- **The Findings report (benefit 2) does *not* depend on machine-checking.** A missing precondition, off-by-one, failed VC, or undefined behavior is a real finding today. Report those with full confidence; gate only the *proof-derived test removals* on the machine check.

Worked conditioning: [`../examples/02-sum-up/PROOF.md`](../examples/02-sum-up/PROOF.md) §6 ("Conditioned on machine-checking") and its "Reproduce the machine check" section.

---

## Limits & escalation

The recipe is a **fast path** for imperative functions with simple counting `while`/`for` loops over integers and maps. For **recursion** (the circularity is on the recursive call's contract), **recursive data structures** (lists/trees/heaps, needing separation/heap abstractions and inductive `μ` predicates), **binders**, or **concurrency / nondeterminism** (where `[all-path]` vs one-path genuinely diverge), treat it as a starting point and **escalate by topic** via [`../knowledge/sources.md`](../knowledge/sources.md) (optional `--refresh`). The most reliable way to extend the kit to a new shape of problem is **another worked example** — the example library is the growth lever.

---

### Cross-references

- [`formalize.md`](formalize.md) — produces the specs `/verify` proves; run it first.
- [`../knowledge/reachability-and-circularities.md`](../knowledge/reachability-and-circularities.md) — the proof system, the Circularity rule, the numbered recipe.
- [`../knowledge/k-framework.md`](../knowledge/k-framework.md) — `claim` syntax, `kprove`, `seqstrict`/heating, `[simplification]`, `/Int`.
- [`../knowledge/matching-logic.md`](../knowledge/matching-logic.md) — the underlying logic and the `#And`/`#Or`/`#Equals`/`#Not`/`#Exists` connectives.
- [`../examples/02-sum-up/PROOF.md`](../examples/02-sum-up/PROOF.md) — the worked target: proof shape, Findings (benefit 2), and the test-redundancy snippet (benefit 1).
- [`../knowledge/sources.md`](../knowledge/sources.md) — papers and the `--refresh` escalation path.
