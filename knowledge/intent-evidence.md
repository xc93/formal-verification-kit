# Intent evidence and spec provenance

Base formal specifications on the program's **intended behavior**, not on whatever the current implementation happens to do. The informal prompt / problem statement is a first-class public specification source.

Use this checklist whenever `/formalize` writes `<program>-spec.k` claims, loop circularities, or a `SPEC.md` note.

## 1. Allowed evidence sources

Use only public or user-provided evidence:

- the user's original prompt, issue, task description, requirements, acceptance criteria, examples, and follow-up clarifications;
- project docs, public API docs, comments, docstrings, names, and public tests;
- the current implementation's control/data flow, as implementation evidence only;
- proof obstacles found by `/verify`, surfaced as Findings for the next iteration.

Public/in-repo tests **and quoted current-behavior / pre-fix displays** are **evidence, not an oracle**. They often capture intended behavior, but in bug-fix tasks they may encode the legacy bug or be stale relative to the public issue. When such an obligation conflicts with prompt/issue intent, mark it **SUSPECT**, explain the conflict in `SPEC.md` / `FINDINGS.md`, and do not let it veto the public-intent spec by itself. Contrapositive trigger: if the issue reports current behavior X as the bug, any test or "before" display encoding X is SUSPECT by default — the bug report *is* the contradiction. The correct fix may legitimately delete or change such a test/display; a test you would have to delete to satisfy the public intent is itself a positive bug signal, not a reason to keep V1.

Do **not** use hidden tests, private evaluator traces, gold patches, benchmark scores, prior-attempt pass/fail status, or any artifact an ordinary coding agent would not see.

## 2. Build an intent ledger before writing claims

Before choosing a claim or invariant, write a short ledger in `SPEC.md` (mirror critical entries as comments in the `.k` spec file). Per entry:

- **Source** — `prompt`, `requirements`, `docs`, `public-test`, `name/comment`, `implementation`, or `proof-finding`.
- **Quoted evidence** — the smallest public excerpt that matters.
- **Semantic obligation** — the property it imposes: precondition, postcondition, ordering, uniqueness, preservation, error behavior, boundary case, invariant, or termination measure.
- **Status** — encoded in the spec, conflict finding, ambiguity to ask, or escalation.

If no external prompt or requirements exist, say so explicitly and mark the spec inferred from code/docs/tests only.

## 2a. Intent-first and formal round-trip adequacy

Start from "what public behavior is required?", not "what does the candidate do?". Before accepting any candidate/legacy behavior as a formal postcondition, write `INTENT_SPEC.md`: a concise English list of required behaviors from prompt text, docs, public tests, API names/comments, and named default-domain conventions. Mention the current implementation only as "observed behavior to check later," never as an expected value by itself.

After writing the K semantics and claims, paraphrase every nontrivial claim, circularity, expected value, ordering/winner rule, side condition, and frame condition back into English in `FORMAL_SPEC_ENGLISH.md`. Compare it against `INTENT_SPEC.md` in `SPEC_AUDIT.md`:

- **pass** — the formal English is entailed by public intent / default-domain evidence;
- **fail** — it is candidate-derived, legacy-derived, over-specific, under-specific, or contradicts public intent;
- **ambiguous** — public evidence is insufficient, and the point must not justify `V2 == V1`.

A K proof whose English paraphrase fails this audit proves the wrong contract. Record the mismatch in `FINDINGS.md` and treat the run as invalid/unresolved until the spec or code is repaired.

## 3. Extract properties from language, not just syntax

Treat words in informal specs as semantically loaded:

- **Order / winner**: `first`, `last`, `closest`, `nearest`, `precedence`, `override`, `shadow`, `stable`, `in order` → an ordering property.
- **Cardinality**: `all`, `both`, `every`, `exactly one`, `at most one`, `deduplicate` → collection-size or uniqueness.
- **Preservation**: `keep`, `preserve`, `same as`, `backward compatible`, `do not change` → frame conditions, but only over intended public behavior.
- **Boundary**: `empty`, `missing`, `zero`, `negative`, `duplicate`, `invalid` → preconditions, error behavior, or Findings.
- **Performance**: `linear`, `constant`, `streaming`, `without copying` → complexity/space obligations or termination/performance Findings.

The implementation tells you how the code works; the prompt tells you what it is for. Do not downgrade prompt examples to smoke tests when they express a general property.

Slice frame conditions to the property public evidence actually names. "Preserve the well-used inheritance feature" supports the named feature (marks continue to transfer); it does not preserve every legacy list order, winner precedence, return type, or helper signature. Each preserved sub-property needs its own order-sensitive evidence or named default-domain convention.

Executable snippets, reference implementations, and workaround code in the prompt are first-class intent evidence. If they traverse, merge, or select in a particular order, encode that order as an `intent-derived` claim unless another public source overrides it. A sentence may carry both negative and positive information: "actual behavior uses MRO so X wins, but only one element is present" is negative evidence about completeness and positive identification of the winner `X`.

## 4. Audit code-derived conditions against human intent

The most useful bug signals appear when a precondition, postcondition, invariant, ordering rule, frame condition, or side condition extracted from the program looks **weird** relative to the prompt, issue, examples, docs, or API names. Before accepting any nontrivial condition:

1. Label its provenance: `intent-derived`, `default-domain-assumption`, `implementation-derived`, `proof-required`, or `ambiguous`.
2. If `implementation-derived` or `proof-required`, require independent public justification from prompt/docs/tests/API names — **unless** it is a default, most-common domain assumption.
3. Default assumptions are allowed, but name them. Examples: integer arithmetic is exact unless overflow is in scope; Python inheritance uses normal `cls.__mro__`; a function named `closest` chooses the nearest/most-specific candidate; sorted output is ascending unless stated; a partial-correctness proof does not prove termination unless requested.
4. If an implementation-derived condition conflicts with public intent, or merely makes the spec awkward in a way the prompt does not justify, write a Finding rather than baking it into the spec.
5. A set/membership assertion does **not** establish a list-order obligation. Derive list/order precedence only from an order-sensitive assertion, prompt reference code, docs/API names such as `first`/`closest`, or a named default-domain convention.
6. For any ordered K claim, the expected ordered result must cite a non-candidate source. If the only reason for `[a,b]` over `[b,a]` is "the current patch returns it," classify the order `implementation-derived`/`ambiguous` and do not use it to justify no code change.
7. A "forced" / "uniquely-determined" / "backward-compat-requires-it" label is `proof-required`: it demands an explicit **side-by-side derivation of both candidates**, not prose. Name the concrete alternative, predict its output, and re-derive the public/legacy obligations under both. Keep "forced" only if the alternative demonstrably fails a public obligation; if both satisfy them, the value is **under-determined**, never CONFIRM, and never a basis for predicting a hidden test's value.
8. If both intent and default convention are unclear, mark the point underspecified and ask an UltimatePowers-style clarification.

Compatibility audits are also intent evidence. If a candidate changes a public function/method signature, return type, virtual dispatch call, producer/consumer shape, or storage format, search public callsites and subclass/override definitions. For virtual dispatch such as `self.method(new_keyword=...)`, every public override must accept the new call or the caller must preserve backward-compatible dispatch. Record this in `PUBLIC_COMPATIBILITY_AUDIT.md`; an unhandled public callsite or override is a Finding even if the formal unit proof closes.

The goal is not to reject all implementation facts — the implementation still tells you which variables, states, and transitions the proof must model. The point: implementation facts are **not automatically the desired semantics**.

## 5. Resolve conflicts honestly

When prompt-derived intent and implementation behavior disagree:

1. Prefer the public intent as the candidate specification.
2. Treat the implementation behavior as an observed behavior to check against it.
3. If the code violates the intent, write a Finding with `input → observed vs expected`.
4. If the code-derived spec condition is weird, stronger, weaker, or differently ordered than the human requirement, question it unless public intent evidence or an explicit default-domain assumption supports it.
5. If the intent is genuinely ambiguous, record the ambiguity and ask an UltimatePowers-style clarification; do not silently pick the legacy behavior because it is easier to prove.
6. Never preserve a legacy behavior as an invariant just because it is in the code. It needs independent public intent evidence or a named default-domain convention. Public evidence for one behavior (completeness, transfer) does not preserve a stronger legacy sub-behavior (list order, same-name winner precedence); over-preserved sub-behaviors are legacy-derived unless separately justified.
7. Block a `V2 == V1` / no-change conclusion if any ordering, precedence, winner, or proof side-condition claim is implementation-/code-/legacy-derived without public-intent or default-domain support. Such a claim is a Finding or ambiguity, not a proof that the candidate is correct.
8. The audit boundary is the **full intent** — the whole problem statement plus the docstring / API contract / public names — not just the issue sentence. A `V2 == V1` / no-change conclusion is **also** blocked if it rests on a SUSPECT test or pre-fix display (§1), or on a concrete change the audit named and then dropped on scope grounds. Every claimed wrongness must still trace to public-intent evidence.

## 6. Encode provenance in artifacts

Make every nontrivial claim/circularity traceable:

```k
// SPEC-PROVENANCE:
// - from_prompt: "<quote>" => <semantic obligation>
// - from_docs_or_tests: "<quote>" => <supporting obligation>
// - from_code: <implementation fact used for the semantics/proof>
// - conflicts: <observed implementation mismatch, if any; also in FINDINGS.md>
claim ...
```

`SPEC.md` explains the same obligations in plain English for readers who never open the `.k` files. `FINDINGS.md` records unresolved conflicts, missing preconditions, and proof-derived feedback for the next code-generation pass.
