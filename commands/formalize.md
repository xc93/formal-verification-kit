# `/formalize` — add formal specs and surface hidden bugs

Read the code and write a formal **specification** for it — a precondition/postcondition contract per function, an invariant per loop — plus a plain-language **Findings report** flagging missing preconditions, forgotten corner cases, and suspicious behavior. K need not be installed; the Findings report is useful on its own.

**Output contract.** Emit formal artifacts (`mini-<lang>.k`, `<program>-spec.k`, a human-readable spec note) **plus** the evidence/adequacy audit (`INTENT_SPEC.md`, `PUBLIC_EVIDENCE_LEDGER.md`, `FORMAL_SPEC_ENGLISH.md`, `SPEC_AUDIT.md`, `PUBLIC_COMPATIBILITY_AUDIT.md`) **plus** the Findings report. The `.k` artifacts are non-optional: a Markdown-only result is **invalid** as `/formalize`. The Findings report is **non-blocking** — it never stops you, edits code, or deletes anything.

**Scope.** No arguments → operate on the whole program, writing a spec for *each* function and *each* loop. Default is **partial correctness** (correct *if* it terminates); surface termination as a recommendation, not proved unless asked.

---

## Steps

### 1. Learn

If not already internalized this session, read the bundled primers (offline, instant, identical every run):

- [`knowledge/intent-evidence.md`](../knowledge/intent-evidence.md) — turn prompts, requirements, examples, docs, names, comments, public tests, implementation facts, and proof findings into traceable spec obligations.
- [`knowledge/matching-logic.md`](../knowledge/matching-logic.md) — patterns-as-sets, the definedness ladder, `μ`, and the `#And`/`#Or`/`#Equals`/`#Not`/`#Exists` connectives used below.
- [`knowledge/k-framework.md`](../knowledge/k-framework.md) — configuration cells, rules, `seqstrict`/heating, `claim`s, `kprove`, `[simplification]`, and `/Int` (truncates toward zero; `divInt` floors toward negative infinity).
- [`knowledge/reachability-and-circularities.md`](../knowledge/reachability-and-circularities.md) — reachability logic, the **Circularity** rule, coinductive loop invariants, the proof recipe.

These are a fast path for common cases. When the code uses something they don't cover — recursive data structures, binders/closures, concurrency, the heap, exceptions — escalate **by topic** via [`knowledge/sources.md`](../knowledge/sources.md). `/formalize --refresh` re-fetches those live sources first.

### 2. Read the target — public intent **and** implementation

Enumerate **every function** and **every loop**. For each, infer the *intended* behavior from all intent evidence — the original prompt / problem statement, conversation history, issue/task descriptions, requirements docs, `PROMPTS.md`, an UltimatePowers transcript, names, docstrings, comments, and tests — **not from the code alone**.

**Within each target, cover the whole observable behavior space — every branch and every in-domain input class — not just the patched path.** Enumeration of every function/loop is the *across-unit* rule; this is its *within-unit* companion. Specify and check each reachable branch and each in-domain input class the contract covers, not only the input the issue reproduces with or the line the candidate patch changed. When one observable (a returned value, a rendered string, an emitted query/output) is produced by **several contributors jointly** — multiple methods, helpers, or call sites that each inject part of it — specify the *whole* observable and trace **every** contributor to it; an untouched contributor that still injects the defect is code-under-audit, not fixed background. A spec scoped to the changed lines cannot see a sibling contributor that still violates intent. This pairs with the **full intent** audit boundary (verify.md Step 1): the driving question is "is the intent met across the whole behavior space?", not "is the changed slice locally sound?"

**When the contract is a *family* of like cases, specify the whole family — not just the member the issue exhibits.** If the intended behavior is a *table* or *set* of homogeneous cases — the special values of a function, a set of implication/inference rules, a group of overloads or operators, a family of formats — and the issue shows only **one** member, the obligation is the **entire known family**, not that single instance. Enumerate the members from the unit's own definition and the established domain/library/math references it implements (e.g. the standard special values of the function being defined), and specify each; a member you can name but did not handle is a Finding, not out of scope. The same applies across **duplicated or generated** copies of the family: if the rule/table is mirrored in a second engine, a generated file (`*_generated.py`, a built cache), or a parallel resolver, the fix must reach every copy — an untouched mirror or un-regenerated cache is a Finding. **Balance:** include only members you can justify from intent or an established domain definition — do not invent values; if a member's value is genuinely underivable from public/domain knowledge, record it as an open Finding rather than guessing.

Do an **intent-only pass first** and write `INTENT_SPEC.md`: required behaviors, order/winner rules, frame conditions, boundary cases, and default-domain assumptions, derived only from public intent. Record current/legacy behavior only as observed behavior to check later, never as expected output by itself.

Then read the code as the **implementation being formalized** — its functions, control flow, loops/recursion, data structures, and constructs determine the semantics fragment, the reachability claims, and the circularities. The contract captures intended behavior; the code is checked against it. Intent↔implementation divergence becomes a Finding (step 7). The default is **intent-spec mode**: align NL intent ↔ code ↔ formal spec and report mismatches. Do **not** formalize "whatever the code happens to do" as the spec — an as-built reading is a secondary note only when intent is unavailable or ambiguous.

**Fix the spec's domain from intent, not from the code or the diff.** Intent-spec mode governs the *domain/precondition* (which inputs are in scope) just as much as the postcondition. The set of inputs the contract ranges over must come from the unit's intended contract — what it is *for* — never from the inputs the implementation happens to accept, the branch the candidate patch happens to touch, or the single input the issue reproduces with. A domain drawn from the current guards/branches/diff lets a defect be **defined out of existence before any obligation can land on it**: the missing case falls outside the spec, "total on its domain" becomes vacuously true, and no precondition or Finding ever fires on the gap. `Total on its domain` is only meaningful when the domain was fixed *independently* of the implementation. **Balance:** when intent genuinely under-specifies the domain, name the `default-domain-assumption` (step 2 provenance) and record it — do not silently inherit the implementation's domain as if it were intent.

Build a **public intent ledger** before writing any claims (full rules in [`intent-evidence.md`](../knowledge/intent-evidence.md)). Per evidence item record: source (`prompt`, `requirements`, `docs`, `public-test`, `name/comment`, `implementation`, or `proof-finding`), quoted evidence, semantic obligation, status. Put it in `SPEC.md` and `PUBLIC_EVIDENCE_LEDGER.md`; mirror critical entries as comments above the matching claim/circularity in `<program>-spec.k`. If no external prompt/requirements exist, say so and mark the spec inferred from code/docs/tests only.

Label every nontrivial precondition, postcondition, invariant/circularity, ordering rule, frame condition, and proof side condition with its provenance: `intent-derived`, `default-domain-assumption`, `implementation-derived`, `proof-required`, or `ambiguous`. For an `implementation-derived` or `proof-required` condition, require independent public justification or name the default-domain convention that licenses it. **Conditions that look weird relative to the prompt/spec are where bugs hide.**

When a public/in-repo test **or an issue's pre-fix REPL / printed / example "before" output** encodes behavior the public issue or prompt describes as buggy, do **not** enshrine it as the spec: add a ledger entry **SUSPECT legacy-test obligation**, explain the conflict, and derive the claim from the best public intent evidence. **Contrapositive trigger:** if the issue/prompt reports current behavior X as the bug, then any existing test or shown "before" display that encodes X is SUSPECT by default — you need not find a separate contradiction, the bug report *is* the contradiction. The correct fix may legitimately delete or change such a test/display; a test you would have to delete to satisfy the public intent is itself a positive bug signal, not a reason to keep V1. **Balance:** still derive the new behavior from positive public-intent evidence — SUSPECT means "don't let it veto the intent," not "invert it blindly." *(An issue whose reproduction shows `polylog(2, 1/2)` printing unevaluated is reporting that as the symptom — do not enshrine "stays unevaluated by default" as an invariant.)*

Treat informal words as spec signals: `first`/`last`/`closest`/`precedence`/`override`/`stable`/`in order` impose ordering/winner properties; `all`/`both`/`every`/`exactly`/`deduplicate` impose cardinality/collection properties; `preserve`/`same as`/`backward compatible` impose frame conditions over intended public behavior. Code that violates such an obligation is a Finding, not a reason to weaken the spec.

Treat executable snippets, reference implementations, and workaround code in the prompt as first-class spec evidence. If they traverse or merge in a particular order, that order must appear in a concrete claim unless another public source explicitly overrides it. Split mixed bug-report statements into all their obligations ("uses MRO so X wins, but only one element is present" = negative evidence about completeness + positive evidence about winner `X`).

Do **not** invent list-order compatibility from set/membership tests — those support completeness, not ordering. Any ordered expected value must cite prompt code, docs/API names such as `first`/`closest`, an order-sensitive public test, or a named default-domain convention. If the only source for the order is the candidate implementation, classify it `implementation-derived` and unresolved; it cannot justify `V2 == V1`.

The **form** of a desired output is a spec signal too: a value shown bare (no opt-in transform such as `.expand()`) sets a placement obligation on the default/construction path (`eval`/constructor), not an opt-in method. Landing it on an opt-in path while the default path still returns the old value is a Finding, not a confirmation.

Slice frame conditions narrowly: "marks transfer through inheritance" supports transfer/completeness; it does not by itself pin list order or same-name winner precedence. A stronger preserved sub-property needs its own order-sensitive source or named default-domain convention.

Audit public compatibility for changed APIs and virtual dispatch. If the code changes a method signature, return shape, or producer/consumer protocol, or calls a virtual method with new arguments (e.g. `self.method(new_keyword=...)`), search public callers and subclass overrides and write `PUBLIC_COMPATIBILITY_AUDIT.md` — each changed symbol, public callsite/override, status, required code/test-helper update. An unhandled public override/callsite is a Finding even if the unit claim proves.

> Worked example: `examples/02-sum-up/sum.py` is one function `sum_to_n(n)` with one `while` loop. Prompt/docstring intent "Return the sum of the integers from 1 to n" + loop `while i <= n: s += i; i += 1` ⇒ intended `sum_to_n(n) = 1 + 2 + … + n` on its intended domain. The code's behavior on negative inputs is then a Finding (missing precondition `n >= 0`), not part of the spec silently accepted as correct.

### 3. Build a mini-X K semantics

Build a **minimal K semantics of just the fragment the code uses** — "mini-X" (mini-Python, mini-TS, …). Imitate [`examples/02-sum-up/mini-python.k`](../examples/02-sum-up/mini-python.k): a `*-SYNTAX` module for the constructs that actually appear (*and nothing else*) and a semantics module with a `configuration` of cells (e.g. `<k>`, `<store>`, `<funcs>`, `<stack>`) and one rewrite `rule` per construct. Cover only what the code touches — `sum` needs integer literals/names, `+`, `<=`, `=`, `+=`, `while`, `def`, `return`, and call, and introduces **no `if`** because the program never uses one (`if` is straightforward to add when a program needs it). Do not invent K features; check each against the manual / Lesson 1.22.

**Minimal, but still property-complete.** Cover only what the code touches — *and* keep whatever axis the change manipulates and the tests measure (value, type, structure, order, shape, cardinality) **representable in the model's observable**. Minimality means dropping unused *constructs/state*, never dropping the *property under verification*: a fragment that can no longer express the property — or an abstraction that maps a passing and a failing instance to the same value — proves nothing. (Discriminator test and the independent-reference rule: [`../knowledge/k-framework.md`](../knowledge/k-framework.md), Lists / spec-only abstraction functions. This is distinct from the step 5 "reduced in-domain body" note, which is about dropping *validation guards*, not the verified property.)

> **MVP stopgap.** The fragment is a deliberate placeholder for full per-language K semantics (real Python-in-K, TS-in-K, …), so the *literal* program is verified against the *real* language. Until that lands, keep the fragment small, faithful, and commented.

### 4. Specify each function — a reachability rule

Write each function's contract as a **reachability rule** `φ_pre ⇒ φ_post` (the reachability arrow: every execution from a `φ_pre` state reaches a `φ_post` state), expressed as a K `claim` over the mini-X semantics. Imitate the `(SUM)` claim in [`examples/02-sum-up/sum-up-spec.k`](../examples/02-sum-up/sum-up-spec.k): the left `<k>` defines and calls the function on a symbolic argument; `requires` states the **precondition**; the rewritten right-hand cells state the **postcondition**. Use uppercase math variables (`S`, `I`, `N`) for logical values and lowercase (`s`, `i`, `n`) for program variables so they never clash. Carry `[all-path]` (or `[one-path]`).

> For `sum`: precondition `N >=Int 0`; postcondition `result |-> N *Int (N +Int 1) /Int 2`.

Above each nontrivial claim, add a provenance comment connecting the formal property to the intent ledger:

```k
// SPEC-PROVENANCE:
// - from_prompt: "<quote>" => <intended postcondition / ordering / error behavior>
// - from_docs_or_tests: "<quote>" => <supporting public obligation>
// - from_default_domain: <standard language/library/domain convention, if used>
// - from_code: <implementation fact used to model state/transition shape, not intent by itself>
// - conflicts: <observed mismatch, weird code-derived condition, or ambiguity; also in FINDINGS.md>
claim ...
```

Do not let a legacy implementation behavior veto a prompt-derived contract unless independent public evidence shows the legacy behavior is intended, or it is the named default-domain convention for this language/library/domain.

### 5. Specify each loop or recursive function — a circularity

For each loop, write a **loop-invariant claim** generalized over the accumulator and counter (not pinned to initial values), with the **soundness side condition** that bounds the counter through the loop. Imitate the `(LOOP)` claim. K's prover treats **every claim in the module as a coinduction hypothesis (a circularity)**, so the loop claim discharges its own loop — this replaces the classical loop invariant.

**For a recursive function instead of a loop:** write a **function-contract circularity** `f(args) ⇒ result`, generalized over the symbolic argument(s), with the soundness precondition (e.g. `N >= 0`). K uses it as its own hypothesis for the recursive call; the base case is the non-recursive branch. See `(REC)` in [`examples/06-sum-recursive/`](../examples/06-sum-recursive/).

> **Input-validation guards & exceptions (a common real-code pattern).** When code begins with `isinstance(...)` / `assert` / `if n < 0: raise ...`, those guards are **no-ops on the verified domain** (they pass and fall through). Model the **reduced in-domain body** in mini-X — do *not* model `raise`/exceptions (an escalation case) — and turn each guard into a **Finding**, often a *positive* one (`if n < 0: raise` enforces the precondition `requires N >= 0`). See [`examples/06-sum-recursive/`](../examples/06-sum-recursive/) (its `isinstance`/`ValueError` guards become Findings 1–2).

> For `sum`'s loop: generalize over `s = S`, `i = I`, `n = N`; the invariant says running the loop adds `(I +Int N) *Int (N -Int I +Int 1) /Int 2` to `s` and leaves `i = N +Int 1`; the side condition is `requires I <=Int N +Int 1`.

Derive invariants from both sides of the ledger: **intent** says what must be preserved or accumulated; **implementation** says the state variables and transition shape. If the prompt specifies an ordered traversal, a winner, preservation of all elements, or a boundary behavior, encode it in the invariant even when the current code runs the opposite or weaker order — the mismatch becomes a Finding.

### 6. Write the artifacts

Write these **alongside the code** (do not bury them elsewhere):

- **`mini-<lang>.k`** — the mini-X fragment from step 3.
- **`<program>-spec.k`** — the function and loop `claim`s from steps 4–5, plus any `[simplification]` rules the arithmetic needs (e.g. map extensionality, exact halving of an even product), with `SPEC-PROVENANCE` comments for nontrivial public-intent obligations.
- **a human-readable spec note** — what each function/loop is specified to do, the precondition, result, side conditions, and public intent ledger, in plain English for a developer who never opens the `.k` files.
- **`INTENT_SPEC.md`** — intent-only English obligations from public evidence and named default-domain conventions.
- **`FORMAL_SPEC_ENGLISH.md`** — one English paraphrase per nontrivial K claim, circularity, expected result, order/winner rule, frame condition, and side condition.
- **`SPEC_AUDIT.md`** — a pass/fail/ambiguous comparison of each formal-English obligation against `INTENT_SPEC.md`; failures and ambiguities also become Findings.
- **`PUBLIC_COMPATIBILITY_AUDIT.md`** — public API/callsite/subclass/override and producer/consumer audit for every changed symbol or dispatch shape.

Do not substitute `SPEC.md` or `PROOF_OBLIGATIONS.md` for the formal files. If you cannot write credible K semantics and K `claim`s, stop and mark the formalization **invalid/unresolved** with the reason — itself a Finding and a signal for the next code/spec iteration.

### 7. Findings report (first-class, plain language)

A primary deliverable, written for **any developer**, each finding a concrete **`input → observed vs expected`**. Cover at least:

- **Missing preconditions / side conditions** — inputs the code silently assumes.
- **Forgotten corner cases** — empty, zero, negative, boundary, overflow, off-by-one.
- **Undefined or intent-contradicting behavior** — meaningless results, or results that disagree with stated/inferred intent.
- **Non-universal postconditions** — claimed behavior that fails for some input in the domain.
- **Dead / unreachable code** — branches or statements that can never execute.
- **Self-declared incompleteness** — a branch the code *itself* flags as unfinished or unhandled.

**Self-declared incompleteness is a bug signal, not a contract to certify.** When the code announces its own gap — `raise NotImplementedError`, a `TODO`/`FIXME`, a "not handled yet" comment, a `return None`/empty/sentinel "can't do it" fallback, an unsolved-marker return — that branch is a self-declared divergence from intent and becomes a **Finding** (often the exact locus of the bug). Promote it to an **obligation the code must discharge against the stated intent**; do **not** fold it into the frame/preserve conditions or write a postcondition that says "on this input the routine raises / returns the fallback" and mark it *positive*. The same applies to an error/traceback the issue itself exhibits: the emitted error is the symptom to remove, not a behavior to preserve. **Distinguish this from a precondition-enforcing guard** (step 5): `if n < 0: raise` on an out-of-domain input *enforces* `requires N >= 0` and is a *positive* Finding, because the input is outside the intended domain; a `raise NotImplementedError` / fallback on an **in-domain** input the intent requires handling is an *incompleteness* Finding, because the code admits it has not done what it was for. The discriminator is intent: does the contract require this input to be handled? If yes, the marker is a gap to close, never a contract. **Balance:** if the input is genuinely outside the intended domain, the marker may be a legitimate precondition-enforcing guard — say which, with the domain evidence, rather than assuming either.

**Spec-difficulty = bug signal.** If you cannot write a *clean* spec — no clean precondition exists, the postcondition needs awkward case splits, a loop has no clean invariant, or an implementation-derived side condition looks unrelated to the requirement — **say so and explain what's suspicious.** That difficulty is usually a real code smell, and naming it is itself a finding. Do not paper over it to force a tidy claim. This heuristic must **also** fire on *verbal* rationalizations — "conventionally wrong but accepted consequence," "out of scope," "exceeds the issue/hint," "wrong but expected" — each a smell to investigate and explain, not a license to accept the behavior or drop a named fix.

> Worked finding (`sum`): input `n = -3` → observed `0` (the loop `while i <= n` with `i = 1` never runs, so `s` stays `0`); expected per `n*(n+1)/2`: `(-3)*(-3+1)/2 = 3`. The function is only correct for `n >= 0`; for negative `n` it silently returns `0`, which is neither the sum `1 + … + n` nor the closed-form value. **Recommendation:** document/enforce `n >= 0`; the `(SUM)` contract states `requires N >=Int 0`. The related loop side condition `i <= n + 1` holds on every reachable iteration. This is the value `/formalize` delivers even to a user who never reads the proof.

---

## Output contract (summary)

`/formalize` emits, alongside your code:

1. **Artifacts** — `mini-<lang>.k`, `<program>-spec.k` (with spec-provenance comments), a human-readable spec note with the public intent ledger, and the adequacy/compatibility audits (`INTENT_SPEC.md`, `FORMAL_SPEC_ENGLISH.md`, `SPEC_AUDIT.md`, `PUBLIC_COMPATIBILITY_AUDIT.md`).
2. **Findings report** — plain-language `input → observed vs expected`, including spec-difficulty signals. **Non-blocking.**

Then run [`/verify`](verify.md) to construct the proof, get the **test-redundancy** recommendation (benefit 1), and emit the exact `kompile`/`kprove` commands — labeled *constructed, not machine-checked* — to confirm it later.
