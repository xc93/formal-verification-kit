# Reproducibility — the prompts that produce `insertion-sort`

> **Provenance note (read this first).** This example was produced by an
> **isolated-newcomer agent** — the kit's "how examples are produced" methodology:
> a fresh Claude Code session, dropped into an empty directory, told only to learn
> the kit and to `/formalize` then `/verify` independently-written code. Because that
> cold run was isolated, the **exact prompts were not captured verbatim**. So the
> recipe below is **not** a transcript — it is the reproducibility **pattern**, written
> to be parallel to the arithmetic examples (`sum-up`, `sum-down`, `sum-recursive`),
> that recreates this artifact. Pasting these prompts in order reproduces the same
> program, semantics, spec, findings, and (escalation-bounded) proof; exact wording
> will differ run-to-run (see *Non-determinism* below).

This entire example — the program, the mini Python semantics over **lists**, the
specification, the findings, and the constructed-but-escalation-bounded proof — comes
out of natural-language prompts to **Claude Code**, driven by the same 7-prompt shape
as the sum examples, adapted to an **array/list algorithm** whose postcondition is
**relational** (sorted + permutation) rather than a polynomial closed form. That
single change is what drives this example into the kit's documented **escalation**
regime, and the prompts below are written to surface that boundary honestly rather
than paper over it.

To reproduce, open Claude Code in an empty working directory **with the
formal-verification-kit available** (point the agent at the repo, or clone it), and
issue the prompts below **in order, in a single session** (context carries between
turns; each builds on the previous). The prompt marked 🌐 needs web/repo access.

## The prompts

```text
[P1]  Let's write a classic insertion sort in Python. Call it insertion_sort(array).
      It should return a NEW sorted list and leave the input array unchanged (copy it
      first with result = list(array)). Use the standard two-loop shape: an outer loop
      walking i from 1, and an inner loop that shifts elements greater than the key one
      slot to the right, then drops the key into the hole. Add a few tests — empty,
      single, already-sorted, reverse-sorted, duplicates, negatives, and one that
      checks the input is not mutated.

[P2]  🌐 Now I'd like to formally verify this program using the formal-verification
      kit (github.com/grosu/formal-verification-kit). First, learn this formal
      verification kit, and then let me know when you are done so we can agree on
      the next step.

[P3]  Let's just discuss the approach first — before generating any artifacts. Model
      the array as a K `List`. There are TWO loops, so two nested loop circularities
      plus the function contract — three nested claims: call them (SORT), (OUTER),
      (INNER). The postcondition is RELATIONAL, not a closed form: the result is
      isSorted AND a permutation of the input (multiset / `bag` equality), same length.
      And flag it up front — I expect sortedness and permutation to hit the kit's
      ESCALATION boundary, because they are inductive/multiset predicates, not the
      arithmetic fast path. Walk me through how (OUTER) "grows the sorted prefix",
      how (INNER) "inserts the key into a hole", and exactly where you expect to stall.

[P4]  Run /formalize.

[P5]  If I tell you /verify, what exactly will it establish — given the escalation
      boundary you just flagged?

[P6]  Go ahead and /verify.

[P7]  Add this to the kit's examples as insertion-sort, next to the sum examples — as
      the first array/list example, the one that shows the escalation boundary done
      honestly. Follow the same reproducibility/prompt pattern we used in the siblings.
```

## What each prompt produces

- **P1** → [`insertion_sort.py`](insertion_sort.py): the two-loop program
  (`result = list(array)` copy; outer `i` from `1`; inner shift on
  `result[j] > key`; hole fill `result[j + 1] = key`) plus
  [`test_insertion_sort.py`](test_insertion_sort.py) — empty, single, sorted, reverse,
  duplicates, negatives, and the non-mutation test.
- **P2** → the agent reads the kit (`AGENTS.md`, the three knowledge primers, the two
  command workflows, and the sibling examples) and reports back the **list-modeling +
  escalation** adaptation it will make — explicitly naming, in advance, that sorting's
  postcondition is *not* the arithmetic fast path.
- **P3** → the agreed plan: arrays as K `List`; **three nested claims**
  `(SORT)` ⊃ `(OUTER)` ⊃ `(INNER)`; the **relational** postcondition
  (`isSorted(?R)` + `bag(?R) ==K bag(A)` + equal length); the `(OUTER)` "sorted prefix
  grows by one" invariant, the `(INNER)` "insert key into a hole" invariant; and the
  **explicit prediction** that the multiset/sortedness VCs will hit the
  `[ESCALATION BOUNDARY]`. *No files yet.*
- **P4** (`/formalize`) → [`mini-python.k`](mini-python.k) (the mini-Python semantics
  with `List`, indexing/index-assign, `len`, `while`, `and` short-circuit, call/return),
  [`mini-python-spec.k`](mini-python-spec.k) (the three claims `(SORT)`/`(OUTER)`/
  `(INNER)`, the **spec-only abstraction functions** `isSorted`/`allGt`/`take`/`seg`/
  `bag`, and the `(L1)`/`(L2)` lemmas left as explicit **`[ESCALATION BOUNDARY]`**
  obligations — *stated, not* `[trusted]`), [`SPEC.md`](SPEC.md), and
  [`FINDINGS.md`](FINDINGS.md) — including the **total-order / `NaN`** bug (Finding 1),
  the **stability-via-strict-`>`** property (Finding 5), the value-sort non-mutation
  property (Finding 4), and the escalation-is-scope-not-defect framing (Finding 6).
- **P5** → the clarification (no files): `/verify` will discharge the **structural**
  obligations — symbolic execution through both loops, the two nested circularities,
  the **in-bounds** VCs (`VC-bounds`) and the **map-extensionality** VC (`VC-ext`) —
  and will then **stop honestly** at the multiset (`VC-L1`) and sorted-prefix-
  composition (`VC-L2`) lemmas. That stop **is the signal**, not a failure; the proof
  is partial correctness, and the inductive list/multiset theory is the escalation
  route, not something to fake with `[trusted]`.
- **P6** (`/verify`) → [`PROOF.md`](PROOF.md): the constructed proof of `(INNER)` and
  `(OUTER)` by guarded coinduction (guard step for guardedness, true/false case split,
  the nested reuse, and `(OUTER)` invoking `(INNER)` as a lemma) and of `(SORT)` using
  `(OUTER)` as a lemma, with the VC table that **discharges `VC-bounds`/`VC-ext` and
  marks `VC-L1`/`VC-L2` open** — labeled **constructed, not machine-checked, *and*
  structurally incomplete by design** (the doubly-honest caveat).
- **P7** → this example package: the `examples/insertion-sort/` layout, this
  `PROMPTS.md`, and the entry next to the sum examples as the first array/list seed.

## Notes for reproducers

- **Environment.** Claude Code with the formal-verification-kit available, plus Python 3
  for the program and its tests. The K toolchain (`kompile`/`kprove`) is **not** needed
  to reproduce this document; and note that even *with* the toolchain, `kprove` as
  configured here is **expected to stall on `VC-L1`/`VC-L2`, not return `#Top`** — that
  is the designed outcome, not a setup error (see [`PROOF.md`](PROOF.md) → "Reproduce
  the (attempted) machine check").

- **The kit collapses the prompt sequence.** Without the kit — from scratch — an agent
  needs *two* explicit "go learn the foundations" prompts: *"go learn matching logic"*
  and *"go read the K framework"* — because it has to learn from primary sources. Here a
  **single** *"learn this kit"* (P2) replaces **both**: the kit *is* the pre-distilled
  matching logic + K + proof recipe. Likewise the from-scratch *"write the list
  semantics / infer the two circularities / state the multiset spec / prove it"*
  sequence collapses into **two commands**, `/formalize` and `/verify`. The kit is, in
  miniature, the "baked-in knowledge" a fine-tuned model will eventually provide.

- **Escalation done right — this is the headline.** The instructive point of this
  example is *how it stops*. Sorting's postcondition is two **non-arithmetic**
  predicates (sortedness, inductively defined; permutation, **multiset** equality), and
  the kit's bundled simplification tier (exact-halving + map-extensionality) does not
  discharge them. The honest recipe the kit follows, and that reproducers must follow,
  is five moves:
  1. **State the claims fully** — all three of `(SORT)`/`(OUTER)`/`(INNER)`, with their
     real invariants, so the proof obligations are *explicit* and well-formed.
  2. **Define the abstractions** — `isSorted`, `allGt`, `take`, `seg`, `bag` as
     spec-only functions, so the postcondition is sayable.
  3. **Discharge the bundled VCs** — the in-bounds/linear arithmetic (`VC-bounds`) and
     map-extensionality (`VC-ext`) really do close.
  4. **Mark the rest `[ESCALATION BOUNDARY]`** — the multiset lemma `(L1)` and the
     sorted-prefix-composition lemma `(L2)` are left as **stated open obligations**.
  5. **Never fake `[trusted]`** — admitting `L1`/`L2` as trusted simplifications would
     manufacture confidence the kit does not have. Instead, **route to the papers**
     (OOPSLA'20 unified fixpoint reasoning over inductive data structures; LICS'19
     Matching mu-Logic) via [`knowledge/sources.md`](../../knowledge/sources.md). The stall is
     the *correct, honest* terminus for this shape — the signal that sorting wants an
     inductive list/multiset theory, of which this function is a natural seed.

- **List modeling — non-aliasing for free.** Arrays are modeled as the K `List` sort,
  which is a **value sort**: index-assignment to `result` rebinds it to a new list
  value and can never alias the caller's `array`. That is *why* the non-mutation
  property (Finding 4) holds **by construction** in the model rather than as a separate
  frame proof — and it is exactly why `test_does_not_mutate_input` is the one test to
  **KEEP** (it pins the value-sort modeling assumption against Python's actual reference
  semantics, which the model abstracts away).

- **The two highest-value turns are detours.** P3 (*discuss first*) and P5 (*what are
  you actually verifying?*) are not strictly required to produce the artifacts — but
  they are the most pedagogically useful turns of this example. P3 is where the
  **three-nested-claims** structure and the **relational postcondition** get named, and
  where the escalation boundary is *predicted out loud before any tool runs*; P5 is
  where "verify" is correctly scoped to **the structural VCs it can close** plus **the
  honest stop** at the inductive lemmas. Keep them — the whole point of this example is
  the boundary, and these turns are where the boundary is articulated.

- **Non-determinism.** LLM outputs vary run-to-run. The structure (three nested
  claims), the list semantics, the relational spec, the findings, and the
  **escalation-bounded** proof result should reproduce; exact wording will differ.
  Treat every generated semantics, spec, and proof as something to **review**, not
  trust blindly — append *"be exhaustive and adversarially verify this"* (or, if
  enabled, the *"ultracode"* / *"use a workflow"* trigger) to the `/formalize` and
  `/verify` prompts to fan out and cross-check. Two things a reviewer should scrutinize
  first: (a) that the `(INNER)`/`(OUTER)` nesting reuses each circularity only after a
  genuine guard step (guardedness), and (b) that `VC-L1`/`VC-L2` were left **open**
  rather than quietly admitted — the integrity of this whole example is the refusal to
  fake the multiset/sortedness lemmas.

- **Faithfulness.** Unlike a captured session, the prompts above were **not** recorded
  from the originating run (it was an isolated cold run; see the provenance note). They
  are reconstructed to be parallel to the sum examples and to regenerate the same
  artifacts; they can be pasted verbatim.

## The one-line prompt of the future

As with the siblings, the whole artifact should one day come from a single line —

> ### `Implement insertion_sort(array) in Python (returns a new sorted list, input unchanged), and formally verify it with the kit.`

— with the kit's knowledge built in and the pipeline autonomous, so the program arrives
*together with* its list semantics, its relational specification, its findings, and a
proof that **honestly reports its escalation boundary** (rather than a faked `#Top`), at
zero extra effort. The multi-prompt sequence above is today's approximation of that one
line — already shorter than the from-scratch sequence, precisely because the kit exists,
and already disciplined enough to stop where the math genuinely escalates.
