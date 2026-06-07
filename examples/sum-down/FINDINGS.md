# Findings report — `sum.py`

Plain-language findings from formalizing [`sum.py`](sum.py). Each is
`input → observed vs expected`. **Non-blocking** — this report never edits or
deletes your code; it is advice. These findings **do not** depend on
machine-checking the proof — they are solid today.

---

## Finding 1 — missing precondition `n >= 0` (real bug for `n <= -2`)

Writing a clean contract forced the guard `requires N >= 0`. Outside it, the code
disagrees with its own intent ("sum of the integers from 1 to n", i.e.
`n*(n+1)/2`). For `n < 1` the loop `while i >= 1` never runs (it starts at `i = n`),
so the function returns `total = 0` — but the closed form is not `0` for `n <= -2`:

| input `n` | code returns (observed) | `n*(n+1)/2` (expected) | agree? |
|---|---|---|---|
| `-3` | `0` | `3`  | ✗ |
| `-2` | `0` | `1`  | ✗ |
| `-1` | `0` | `0`  | ✓ (coincidence) |
| `0`  | `0` | `0`  | ✓ |
| `5`  | `15`| `15` | ✓ |

So for `n = -3` the function yields `0` while the formula yields `3` — they
disagree. Note the code is *coincidentally* correct at `n = 0` and `n = -1` (both
give `0`) but genuinely **wrong for `n <= -2`**.

**Recommendation:** document and/or enforce `n >= 0` (the function is only defined
on non-negative inputs — what `(SUM)`'s `requires N >=Int 0` encodes), or split the
contract on the sign of `n` (`sum_to_n(n) = 0` for `n <= 0`; `n*(n+1)/2` for
`n >= 0`).

## Finding 2 — spec-difficulty signal: the load-bearing side condition `I >= 0`

The loop circularity `(LOOP)` only holds with the side condition bounding the
counter. This is the same class of signal as Finding 1, surfaced from the loop:

- The closed form `I*(I+1)/2` is the true added sum **only while the counter stays
  in range**. For `I <= -2` the body never runs (added sum is `0`) yet
  `I*(I+1)/2 > 0`, so the invariant is **false** there.
- The **weakest sound** side condition is actually `I >= -1` (the claim happens to
  survive at `I = -1`, where `I*(I+1)/2 = 0`). We state the cleaner **`I >= 0`**
  because it mirrors the loop exiting at `i = 0` and is exactly what the function
  entry supplies. The gap `I ∈ {-2, -3, …}` is precisely where Finding 1's bug
  lives — the loop spec and the function spec point at the same missing
  precondition from two directions.

## Finding 3 — I/O wrapper is outside the verified core (non-`sum_to_n`)

The `__main__` block `n = int(input("Enter an integer n: ")); print(sum_to_n(n))`
is I/O, not part of the function under verification:

- `int(input(...))` raises `ValueError` on non-integer input (e.g. `"abc"`, `"3.5"`,
  empty) — unhandled, so the program crashes with a traceback.
- This is the I/O shell, not `sum_to_n`. The formal spec covers `sum_to_n` only;
  the wrapper is intentionally not modeled (input parsing / exceptions are outside
  the mini-X fragment).

**Recommendation:** if robust CLI behavior matters, wrap the parse in a try/except
or validate; it does not affect the correctness of `sum_to_n` itself.

## Finding 4 — no overflow corner case (a deliberate non-finding)

Worth stating because a C/Java version would have one: Python integers are
arbitrary-precision, so there is **no overflow** for large `n`. The closed form
`n*(n+1)/2` and the iterative accumulation agree at every magnitude. No action
needed.

## Note — termination (partial vs total correctness)

The contract is **partial correctness**: it says nothing about whether the loop
halts. For `n >= 0` it clearly does — the measure `i` starts at `n`, strictly
decreases by 1 each iteration, and is bounded below by `0`, so total correctness is
easily reachable. **Recommendation-only:** if you want it proved, add the variant
`i` (bounded below by `0`, strictly decreasing) to `(LOOP)` and discharge it
alongside the existing VCs. Not attempted unless you ask.

---

*Next: run `/verify` to construct the proof of `(SUM)`/`(LOOP)` and get the
test-redundancy recommendation (benefit 1). The `n <= -2` case above is exactly the
out-of-domain behavior any `n < 0` test should keep pinning.*
