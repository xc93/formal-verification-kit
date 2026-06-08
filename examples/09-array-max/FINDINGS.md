# Findings report — `array_max.py`

Plain-language findings from formalizing [`array_max.py`](array_max.py). Each is
`input → observed vs expected`. **Non-blocking** — this report never edits or
deletes your code; it is advice. These findings **do not** depend on machine-checking
the proof: a missing precondition is real today, whether or not `kprove` has run.

The two headline findings (#1, #2) were **executed** against the real program; the
observed outputs below are literal `python3` results.

---

## Finding 1 — missing precondition: the list must be **non-empty** (`len(a) >= 1`)

The first line `largest = a[0]` reads element 0 unconditionally. On the empty list
there is no element 0.

- input: `array_max([])`
  → **observed:** `IndexError: list index out of range` (executed).
  → **expected (intent):** the maximum of an empty list is undefined; the function
    should either reject `[]` explicitly (e.g. raise a clear `ValueError`) or document
    that it requires a non-empty list.

The docstring already says *"the maximum element of a **non-empty** list"*, so the
non-emptiness is **intended** — but it is **not enforced**, and the failure mode is an
opaque `IndexError` from the indexing internals rather than a domain error.

**Recommendation:** document and/or enforce `len(a) >= 1` (e.g. `if not a: raise
ValueError("array_max() arg is an empty list")`). The formal contract `(MAX)` is
stated with `requires size(A) >=Int 1` to make this precondition explicit; the loop's
soundness side condition `1 <= i <= len(a)` is the same fact propagated through the
scan (it is what keeps the "max of the visited prefix" defined on a non-empty prefix).

---

## Finding 2 — implicit precondition: elements must be **totally ordered** under `>`

The algorithm assumes `>` is a **total order** on the elements: that for any two
elements exactly one of `x > y`, `y > x`, `x == y` holds, and `>` is transitive. Real
Python values can break this, and the result then silently depends on **position**,
not value — the postcondition "`result` is the maximum" fails.

### 2a — `NaN` (a float that is incomparable to everything, itself included)

Every comparison involving `NaN` is `False`, so `NaN` is neither `>` nor `<=` anything.

| input | observed (executed) | expected (a true maximum) |
|---|---|---|
| `[nan, 1, 2]` | `nan` | (no well-defined max; `nan` is incomparable) |
| `[1, 2, nan]` | `2`   | — |
| `[1, nan, 3]` | `3`   | — |
| `[3, nan, 1]` | `3`   | — |

The result **changes with the position** of `nan` (`nan` when first, otherwise the max
of the non-`nan` part). Neither the upper-bound clause (`nan` is not `<=` the result)
nor a meaningful "maximum" holds. This is a textbook total-order violation: the spec's
postcondition `forall j. a[j] <= result` is **false** for any input containing `nan`.

### 2b — mixed incomparable types

- input: `array_max([1, 'a', 2])`
  → **observed:** `TypeError: '>' not supported between instances of 'str' and 'int'`
    (executed).
  → **expected:** comparison is simply undefined across these types.

**Recommendation:** document that elements must be mutually comparable under a total
order (e.g. all numbers and non-`NaN`, or all the same orderable type). The formal
model **restricts elements to `Int`**, on which K's `>` is a genuine total order — the
faithful analogue of the `sum` example restricting to `Int`. That restriction is what
makes the clean postcondition provable; the genericity gap (and this total-order
precondition) is reported here rather than modeled away silently. This is a
**capability/scope** restriction of the model, not a code bug per se — but the `NaN`
case (2a) **is** a real silent-wrong-answer bug on the float domain Python admits.

---

## Finding 3 — no `else` is correct; the `>` (strict) vs `>=` choice is benign

The loop has `if a[i] > largest:` with **no** `else`, and uses **strict** `>`. Both
are correct:

- The missing `else` is fine — when `a[i] <= largest`, `largest` should indeed be left
  unchanged.
- Using `>` (strict) rather than `>=` only affects **which** equal-max element's slot
  is conceptually "kept"; since equal elements have equal value, the **returned value**
  is identical either way. Verified by the equal-element tests
  (`array_max([0,0,0]) == 0`, `array_max([2,2,2,2]) == 2`,
  `array_max([-10,5,0,5,-10]) == 5`), all of which pass. No finding here — noted to
  pre-empt a false positive.

---

## Finding 4 — the input list is never mutated (positive finding)

`array_max` only **reads** `a` (`a[0]`, `a[i]`, `len(a)`); it performs no assignment to
any element or to `a` itself. In the K model `List` is an immutable **value** sort, so
non-mutation holds **by construction**. Callers can rely on `a` being unchanged. (No
action needed; recorded because it is part of the contract a caller cares about.)

---

## Spec-difficulty signal: NONE (clean spec ⇒ no hidden structural bug)

A clean precondition (`len(a) >= 1`), a clean ∀-quantified postcondition (upper bound +
membership), and a clean loop invariant (`largest = max of a[0:i)`) **all exist and were
easy to write**. Per the kit's "spec-difficulty is a bug signal" heuristic, the *absence*
of difficulty here is itself reassuring: the only issues are the two **domain
preconditions** above (#1 non-empty, #2 total order), not a structural defect in the
scan. The core max-finding logic is correct on its intended domain.
