# Findings report — `insertion_sort.py`

Plain-language findings from formalizing [`insertion_sort.py`](insertion_sort.py).
Each is `input → observed vs expected`. **Non-blocking** — this report never edits
or deletes your code; it is advice. These findings **do not** depend on
machine-checking the proof — they are solid today. The concrete cases below were
**executed** against the actual code (not just reasoned about).

---

## Finding 1 — missing precondition: elements must form a total order (real bug with NaN / mixed types)

Writing a clean contract forces the question "what does `<`/`>` mean on the
elements?" The code silently assumes the elements are **pairwise comparable and
totally ordered**. Two concrete ways that fails:

- **`float('nan')` poisons the order.** Every comparison with NaN is `False`, so
  the inner guard `result[j] > key` never fires across a NaN and the element is
  never moved. Executed:

  | input | code returns (observed) | expected (sorted) | agree? |
  |---|---|---|---|
  | `[3, float('nan'), 1]` | `[3, nan, 1]` (3 precedes 1) | a sorted order | ✗ **not sorted** |

  The output places `3` before `1` — it is **not** sorted. This is the direct
  analogue of the sum example's missing `n >= 0`: a silently-assumed precondition
  that, when violated, makes the function disagree with its own intent.

- **Mixed incomparable types raise.** `insertion_sort([1, "a"])` raises
  `TypeError: '>' not supported between 'str' and 'int'` (Python 3). The function
  is only defined on a domain of mutually-orderable elements.

**Recommendation:** document/enforce the precondition "elements are mutually
comparable and the order is total (no NaN)." The formal contract `(SORT)` makes
this explicit by **modeling elements as `Int`** (a total order); the gap between
"generic element" and "`Int`" is exactly this finding.

## Finding 2 — spec-difficulty signal: the load-bearing invariant side conditions

As in the sum example (`I <= N+1`), writing the loop circularities **forced**
side conditions that are not in the source text — and each marks a real boundary:

- `(OUTER)` needs `1 <= i <= len` and `isSorted(result[0:i])`. The lower bound
  `i >= 1` is why `i` starts at `1`, not `0` (a 1-element prefix is sorted for
  free — the proof's base case). Start `i` at `0` and the first comparison
  `result[-1]` would wrap (Python negative index!) — see Finding 7.
- `(INNER)` needs `-1 <= j < i < len` and the **hole-multiset** condition. The
  `j >= -1` lower bound is what the guard `j >= 0` protects: the read `result[j]`
  is only reached while `j >= 0`, so the loop never indexes out of range. This is
  a *positive* finding — the code's guard ordering (`j >= 0` **before**
  `result[j] > key`, relying on `and` short-circuit) is exactly what keeps every
  index in bounds.

These are not bugs; they are the silent assumptions the formal lens surfaces.

## Finding 3 — `list(array)` accepts any iterable, and always returns a *list*

The parameter is named `array`, but `result = list(array)` coerces **any
iterable**. Executed: `insertion_sort('dcba')` → `['a', 'b', 'c', 'd']` — a *list
of characters*, not a string. Likewise a tuple input returns a list, and a
**generator** input would be silently consumed. 

**Recommendation:** if only lists are intended, validate the input type or document
that the return is always a new `list` regardless of input type. (Harmless if the
coercion is intended; worth a one-line docstring note either way.)

## Finding 4 — input is not mutated (a deliberate, verified-by-construction property)

`result = list(array)` copies, so the caller's list is never modified. Executed:
`insertion_sort([3,1,2])` leaves the argument `[3,1,2]`. In the K model this holds
**by construction**: `List` is a value sort, so index-assignment to `result`
rebinds `result` to a new value and can never alias `array`. 

**Recommendation:** keep the `test_does_not_mutate_input` test — it pins a real
part of the contract. (Once `(SORT)` is machine-checked, the no-mutation frame is
covered, but until then the test is the guard.)

## Finding 5 — stability hinges on the **strict** `>` in the inner guard (subtle, intent-relevant)

The guard is `result[j] > key` (**strict**), so an element equal to `key` does
**not** shift — equal elements keep their original relative order. The sort is
therefore **stable**. Executed (keys comparing on a hidden field, tags showing
origin): `[1a, 1b, 0c, 1d]` → `[0c, 1a, 1b, 1d]` — the three `1`s stay in input
order `a, b, d`.

Had the guard been `result[j] >= key`, the function would still be correct
(a sorted permutation) but **no longer stable**. This `>` vs `>=` choice is
load-bearing for stability and invisible to a quick read — the kind of property
formalization makes explicit. **Recommendation:** if stability is intended (it
often is the reason to pick insertion sort), state it in the docstring and keep a
test that would catch a regression to `>=`.

## Finding 6 — spec-difficulty = ESCALATION signal: sorting is beyond the bundled fast path (NOT a code bug)

This is the headline, and it is **honest scope**, not a defect in your code.
A *clean* postcondition for sorting needs two **non-arithmetic** predicates:

- **sortedness** — universally quantified / inductively defined over the list;
- **permutation** — **multiset** equality of input and output.

The kit's bundled simplification tier (exact-halving of even products +
map-extensionality) discharges *polynomial/linear* VCs, not multiset-preservation
or sorted-prefix-composition. The kit itself flags "array / list loop" as a
**roadmap** example shape and "recursive data structures / inductively-defined
predicates (often `mu`)" as an **escalation** case. So:

- The semantics and all three claims are **constructed and well-formed**.
- Two classes of VC are left as explicit `[ESCALATION BOUNDARY]` obligations in
  [`mini-python-spec.k`](mini-python-spec.k): (L1) multiset change under one
  index-update, (L2) sorted-prefix composition. They are **not** admitted as
  `[trusted]` — doing so would fake confidence the kit does not have.
- **Route (per [`knowledge/sources.md`](../../knowledge/sources.md)):** OOPSLA'20
  (unified fixpoint reasoning over inductive data structures) and LICS'19
  (Matching mu-Logic) for the `mu`-defined `sorted`/multiset predicates and their
  lemmas. The most reliable fix is a **worked array/list example** added to the
  kit — this function is a good candidate once those lemmas exist.

## Finding 7 — corner cases that are handled correctly (deliberate non-findings)

Stated because a reviewer will ask:

- **Empty list** `[]` → `[]`: outer guard `1 < len([]) == 0` is false, loop never
  runs. ✓
- **Single element** `[x]` → `[x]`: `1 < 1` false. ✓
- **Already sorted / reverse sorted / duplicates / negatives**: all handled
  (covered by the existing tests). ✓
- **No index-out-of-bounds**: the inner guard's `j >= 0` (short-circuiting before
  `result[j]`) and `i` starting at `1` keep every index in `[0, len)`. ✓ (See
  Finding 2 — starting `i` at `0` would read `result[-1]`, Python's *last* element,
  a silent wrap-around; the code correctly avoids it by starting at `1`.)

## Note — termination (partial vs total correctness)

The contract is **partial correctness**: it says nothing about halting. Both loops
clearly terminate: the **outer** measure `len - i` strictly decreases by 1 per
iteration (bounded below by 0); the **inner** measure `j + 1` strictly decreases
each iteration (`j` decrements; bounded below by 0, and the loop also exits when
`result[j] <= key`). **Recommendation-only:** if you want it proved, add those two
variants to `(OUTER)`/`(INNER)` and discharge "strictly decreases, bounded below"
alongside the existing VCs. Not attempted unless you ask.

---

*Next: run `/verify` to construct the proof of `(SORT)`/`(OUTER)`/`(INNER)` and get
the test-redundancy recommendation (benefit 1). Expect `/verify` to land cleanly on
the structure and the in-bounds/linear VCs, and to **stop at the `[ESCALATION
BOUNDARY]`** multiset/sortedness lemmas (Finding 6) — that stop is the honest
signal, not a failure.*
