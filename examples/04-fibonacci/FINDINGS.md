# Findings report — `fib.py`

Plain-language findings from formalizing [`fib.py`](fib.py). Each is
`input → observed vs expected`. **Non-blocking** — this report never edits or
deletes your code; it is advice. These findings **do not** depend on
machine-checking the proof — they are solid today.

---

## Finding 1 — missing precondition `n >= 0` (negative input returns a meaningless `0`)

Writing a clean contract forced the guard `requires N >= 0`. The Fibonacci function
`fib` is only *defined* for `n >= 0` (its recurrence has base cases at `0` and `1`
and counts upward). For any `n < 0` the loop guard `i < n` is **false on entry**
(`i` starts at `0`, and `0 < n` is false for `n <= 0`), so the loop never runs and
the function returns `prev = 0`:

| input `n` | code returns (observed) | `fib(n)` (expected) | verdict |
|---|---|---|---|
| `-3` | `0` | *undefined* (`fib` has no negative-index value here) | meaningless |
| `-1` | `0` | *undefined* | meaningless |
| `0`  | `0` | `0` | OK |
| `1`  | `1` | `1` | OK |
| `5`  | `5` | `5` | OK |

Unlike the `sum-up` example — where the negative-input return `0` *disagrees with a
defined closed form* (`n*(n+1)/2`) and is an outright wrong answer for `n <= -2` —
here the expected value `fib(n)` is **not defined at all** for negative `n`. So the
returned `0` is not "wrong vs. a known right answer"; it is **meaningless**: the
function silently produces a number for an input on which its result has no meaning.
Either way the conclusion is the same — the contract only holds for `n >= 0`.

**Recommendation:** document and/or enforce `n >= 0` (what `(FIB)`'s
`requires N >=Int 0` encodes). For example raise on negative input, or clamp, rather
than silently returning `0`.

## Finding 2 — POSITIVE: the iterative form is O(n), not exponential (a real strength)

The intended quantity `fib` is *defined* by a recurrence
`fib(n) = fib(n-1) + fib(n-2)`. A **naive recursive** implementation of that
definition makes two recursive calls per level and runs in **exponential** time
(`Theta(phi^n)` calls — `fib(40)` already spawns on the order of 10^8 calls). This
code does **not** do that: it carries the two most recent values (`prev`, `curr`) in
a single **count-up loop** and computes `fib(n)` in **exactly `n` iterations** —
`O(n)` time, `O(1)` extra space. This is the right way to compute Fibonacci numbers,
and the formalization makes the gain explicit: the loop invariant
`prev = fib(I), curr = fib(I+1)` shows each iteration advances the index by exactly
one while doing constant work. No action needed — this is a **good** design choice,
recorded as a positive finding.

## Finding 3 — spec-difficulty signal: the side condition `0 <= I <= N`

The loop circularity `(LOOP)` only holds with the side condition bounding the
counter on **both** ends — and both ends are load-bearing:

- **`I <= N`** (upper) — the count-up bound, analogous to `sum-up`'s `I <= N+1`. It
  is what makes the exit branch pin `i = N` (so `prev = fib(N)`), and without it the
  invariant over-reaches past the loop's true endpoint.
- **`0 <= I`** (lower) — **specific to the recurrence**. The inductive step relies on
  `fib`'s third defining equation `fib(I+2) = fib(I) + fib(I+1)`, which is only stated
  for index `> 1`, i.e. requires `I >= 0`. If `I` could go negative the unfold would
  be unjustified. The loop never reaches `I < 0` on the verified domain (it starts at
  `0` and only increases), so the condition holds on every reachable iteration — but
  having to state it surfaces that `fib`'s domain is `n >= 0`, the same boundary as
  Finding 1, approached from the loop side.

## Finding 4 — no overflow corner case (a deliberate non-finding)

Worth stating because a C/Java version would have one: Python integers are
arbitrary-precision, so there is **no overflow** even for large `n` (e.g. `fib(100)`
is a 21-digit integer, computed exactly). The iterative accumulation and the
mathematical `fib` agree at every magnitude. No action needed.

## Note — termination (partial vs total correctness)

The contract is **partial correctness**: it says nothing about whether the loop
halts. For `n >= 0` it clearly does — the measure `N - i` strictly decreases by 1
each iteration (as `i` rises from `0` toward `N`) and is bounded below by `0`, so
total correctness is easily reachable. **Recommendation-only:** if you want it
proved, add the variant `N - i` (bounded below by `0`, strictly decreasing) to
`(LOOP)` and discharge it alongside the existing VCs. Not attempted unless you ask.

---

*Next: run `/verify` to construct the proof of `(FIB)`/`(LOOP)` and get the
test-redundancy recommendation (benefit 1). The `n < 0` case above is exactly the
out-of-domain behavior any negative-input test should keep pinning.*
