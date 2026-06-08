# Example: `insertion-sort` (Python) — arrays, nested loops, a relational spec

`insertion_sort(array)` returns a **sorted permutation** of its input — a new
list, same length, in non-decreasing order, with the input **left unchanged**.
This is a **new example family**, not a member of the `sum-*` cluster: where every
sum example has a **polynomial closed-form** postcondition (`n*(n+1)/2`), sorting's
contract is two **non-arithmetic, relational** predicates — *sortedness* and
*permutation* — over a **list**. It is also the kit's **first example to hit the
escalation boundary honestly**.

The verification has **three nested claims**:

- `(SORT)` — the function contract: result is the same length, **sorted**, and a
  **permutation** (multiset) of the input.
- `(OUTER)` — the outer-loop circularity: *the sorted prefix grows by one* each
  iteration (`result[0:i]` sorted, whole array a permutation, length invariant).
- `(INNER)` — the inner-loop circularity, the crux: *insert the key into a hole*
  by shifting larger elements right; filling the hole recovers the multiset.

**Nested loops → nested circularities.** `(SORT)` reuses `(OUTER)`, which reuses
`(INNER)` **as a lemma** — one level deeper than the sum example's `(SUM)` reuses
`(LOOP)`. That extra nesting is the teaching payload.

## What's new vs the sum examples

- **Arrays / lists.** Elements live in K's `List` value sort, so non-aliasing and
  no-mutation hold **by construction** — index-assignment rebinds `result` to a new
  value and can never touch the caller's `array` (Finding 4).
- **Nested loops** — two back-edges, so two circularities, the inner one a lemma
  for the outer.
- **A relational postcondition.** *Sortedness* (an inductive `isSorted`) and
  *permutation* (a multiset `bag`) are defined as **spec-only abstraction
  functions**, not arithmetic.

## The headline — escalation done right

The bundled simplification tier discharges the **in-bounds / linear** VCs
(`VC-bounds`) and the post-store map-extensionality VC (`VC-ext`). But the
**multiset / sortedness** VCs need an **inductive list/multiset theory** the kit
does not bundle: `VC-L1` (multiset preserved across one index-update) and `VC-L2`
(sorted-prefix composition). Those are stated as explicit **`[ESCALATION
BOUNDARY]`** obligations — **not** faked as `[trusted]`, which would manufacture
confidence the kit does not have. Route them to **OOPSLA'20** (fixpoint reasoning
over inductive data structures) and **LICS'19** (Matching μ-Logic) via
[`../../knowledge/sources.md`](../../knowledge/sources.md).

**Status: `constructed (escalation-bounded)`** — *doubly* short of machine-checked:
`kprove` was not run, **and** the construction is complete only modulo L1/L2.

## Rich findings — see [`FINDINGS.md`](FINDINGS.md)

- **Finding 1 (a real bug):** the missing **total-order precondition** — `float('nan')`
  poisons every comparison, so `[3, nan, 1]` comes back **unsorted**; mixed types raise.
- **Finding 5:** **stability hinges on the strict `>`** — `>=` would still sort but
  lose stability (equal elements would reorder).
- **Positive finding (2 / 7):** the inner guard's `j >= 0` short-circuits **before**
  `result[j]`, so every index stays in bounds — the code is index-safe by design.
- **Finding 4:** the **input is not mutated** — `result = list(array)` copies, and
  in the model `List` is a value sort, so non-mutation holds by construction.

## Provenance — how this example was produced

Produced by an **isolated-newcomer** agent: it learned the kit and ran
`/formalize` **and** `/verify` on independently-written code (it even wrote its own
[`test_insertion_sort.py`](test_insertion_sort.py)). This `README.md` and
[`PROMPTS.md`](PROMPTS.md) were added on promotion. That isolated split is the kit's
standard methodology — see the [examples catalog](../README.md).

## The files

| File | What it is | Stage |
|---|---|---|
| [`insertion_sort.py`](insertion_sort.py) | **The program** — two nested `while` loops; copies the input first. | — |
| [`test_insertion_sort.py`](test_insertion_sort.py) | The newcomer's own tests (incl. `test_does_not_mutate_input`). | — |
| [`mini-python.k`](mini-python.k) | **The minimal K semantics**, now over **lists**: `len`, `list` copy, index read/assign, `<`/`>`/`>=`, short-circuit `and`, `while`. | `/formalize` |
| [`mini-python-spec.k`](mini-python-spec.k) | **The three claims** `(SORT)`/`(OUTER)`/`(INNER)`, the `isSorted`/`bag` spec functions, and the `[ESCALATION BOUNDARY]` obligations. | `/formalize` |
| [`SPEC.md`](SPEC.md) | Plain-English spec note. | `/formalize` |
| [`FINDINGS.md`](FINDINGS.md) | Plain-language findings (total-order bug, stability, index-safety, escalation). | `/formalize` |
| [`PROOF.md`](PROOF.md) | **The constructed proof** + the VC table + the (doubly-gated) test-redundancy recommendation. | `/verify` |
| [`README.md`](README.md) | This overview. | — |
| [`PROMPTS.md`](PROMPTS.md) | **The exact prompts** that reproduce the example, in order. | — |

## Read the proof

See **[PROOF.md](PROOF.md)** for the reachability proof, the VC table, and the
`kompile`/`kprove` commands — which here are **expected to stall on `VC-L1`/`VC-L2`**,
not reach `#Top`, until the inductive list/multiset theory is supplied. That stall
is the honest signal, not a failure.

See the [examples catalog](../README.md) for the full set and the kit methodology.
