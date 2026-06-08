# Findings report — `even_odd.py`

Plain-language findings from formalizing [`even_odd.py`](even_odd.py). Each is
`input → observed vs expected`. **Non-blocking** — this report never edits or
deletes your code; it is advice. These findings **do not** depend on
machine-checking the proof — they are solid today. (Each observed value below was
checked by running the actual functions.)

---

## Finding 1 — `n < 0` does NOT terminate: `n >= 0` is load-bearing for TERMINATION (the headline)

This is the headline finding and the sharpest contrast with the loop examples. The
two functions descend by `n - 1` and the **only** base case is `if n == 0`. For a
negative argument the chain `n, n-1, n-2, …` **never reaches `0`**, so the mutual
recursion runs forever — in CPython it blows the stack and raises `RecursionError`:

| input `n` | code does (observed) | expected for a parity check | verdict |
|---|---|---|---|
| `-1` | **`is_even(-1)` raises `RecursionError`** (infinite mutual recursion: `is_even(-1) → is_odd(-2) → is_even(-3) → …`) | undefined / rejected | unguarded non-termination |
| `-2` | **`is_odd(-2)` raises `RecursionError`** | undefined / rejected | unguarded non-termination |
| `0`  | `is_even(0) = True`, `is_odd(0) = False` | `True`, `False` | ✓ |
| `10` | `is_even(10) = True` | `True` | ✓ |

Unlike the `sum-up`/`sum-down` loop examples — where a negative input *silently
returns the wrong value* (`0`) and the bug is invisible — and unlike
`sum-recursive` — where `if n < 0: raise ValueError` **enforces** the precondition —
this program has **no guard at all**. So negative input neither returns a value nor
raises a *meaningful* error; it simply **fails to terminate** (until the interpreter
gives up with `RecursionError`).

The formal contracts `(EVEN)`/`(ODD)`/`(EVENFN)`/`(ODDFN)` are all stated with
`requires N >= 0`. That side condition is **not** merely a closed-form bound (as
`i <= n+1` is for the sum loop): here it is what makes the recursion **well-founded
at all**. The measure is `n` itself — it strictly decreases by 1 each call and is
bounded below by `0` exactly when `n >= 0`; remove the precondition and there is no
measure and no termination.

**Recommendation:** if `even_odd` may ever be called on possibly-negative input, add
an explicit guard — e.g. `if n < 0: raise ValueError("n must be non-negative")` at
the top of each function (or normalize with `abs(n)` if that matches intent) — so a
bad input is **rejected** rather than spinning into a `RecursionError`. As written,
the functions are correct *only* for `n >= 0`, and that domain is currently
undocumented and unenforced.

## Finding 2 — on the verified domain, the two functions are exact, total, and complementary (a positive finding)

For every returnable `n >= 0`, the functions agree exactly with true parity and are
mutually exclusive — confirmed against the inline tests and an extended scan:

| property | checked | result |
|---|---|---|
| `is_even(n) == (n % 2 == 0)` | all `n` in `[0, 997]` | ✓ holds |
| `is_odd(n) == (n % 2 == 1)`  | all `n` in `[0, 997]` | ✓ holds |
| `is_even(n) != is_odd(n)`    | all `n` in `[0, 500]` | ✓ always opposite |

The base cases are off-by-one-clean: `is_even(0) = True`, `is_odd(0) = False`, and
each recursive step flips the parity, so the mutual recursion computes exact parity.
This is the positive twin of Finding 1: *inside* `n >= 0` the code is correct and
total; the only problem is the *unstated domain boundary*. **No action needed for
the in-domain behavior.**

## Finding 3 — recursion-depth limit: a real corner case (measured `n = 998`)

The contracts are **partial correctness** — `is_even(n) = (n mod 2 == 0)` *if and
when it returns*. For this mutually-recursive, non-tail implementation that "if"
bites at a concrete, measured boundary: each step down consumes one Python stack
frame, so it hits CPython's default recursion limit (`sys.getrecursionlimit() ==
1000`):

| input `n` | code does (observed) | mathematically expected |
|---|---|---|
| `997`    | `is_even(997) = False`     | `False` (997 is odd) ✓ |
| `998`    | **raises `RecursionError`** | `True`  (998 is even)  |
| `100000` | **raises `RecursionError`** | `True` |

Measured: the smallest `n` that raises is **998** (so the functions return correctly
only for `0 <= n <= 997` at the default limit). As in `sum-recursive`, this is
*sharper* than "termination is unproved": for `n >= 998` the implementation
**provably fails to return**, so the partial-correctness postcondition is only
vacuously satisfied there. Note this is **distinct** from Finding 1: here the
recursion *is* well-founded (it would terminate in idealized semantics — `n`
decreases to `0`); the limit is purely a CPython stack-depth artifact. In Finding 1
the recursion is **not** well-founded at all.

**Recommendation:** for unbounded `n`, prefer the O(1) closed form `n % 2 == 0` /
`n % 2 == 1` (or an iterative loop). If the mutual-recursion form is kept for
pedagogy, document the input-range limit, or raise the limit deliberately
(`sys.setrecursionlimit(...)`), or rewrite to a tail-recursive + trampoline form.

## Finding 4 — spec-difficulty / methodology signal: this is the MUTUAL-recursion shape

Writing the spec was clean, but it required **generalizing the kit's
single-recursion case** (`sum-recursive`'s `(REC)`) to **mutual** recursion: the
circularity now **spans two claims**, `(EVEN)` and `(ODD)`, that **discharge each
other's** recursive call (K makes every claim a coinduction hypothesis, so each is
available while proving the other). That is a documented use of the same
reachability/Circularity machinery (primer §3 "the same principle covers recursion";
sources route to Roșu & Ștefănescu, FM 2012 / LICS 2013). Recorded here for honesty,
not as a code bug: the artifacts are **constructed, not machine-checked**, and the
mutual cross-discharge (two reachability claims each closing the other's inner call)
is the one piece a reviewer should scrutinize first when `kprove` is eventually run.

**No escalation boundary was hit.** The evenness predicate is the spec-only builtin
expression `N mod 2 == 0`; the step verification conditions about it are
**single-decrement parity facts** (`(N-1) mod 2 == 1 ⇔ N mod 2 == 0`, for `N >= 1`),
which are linear-after-mod and discharge without induction over `N` — the induction
lives in the circularity. So, unlike the insertion-sort example's inductive
`isSorted`/`bag` obligations, nothing here is left as an `[ESCALATION BOUNDARY]`
obligation, and nothing is faked as `[trusted]`.

## Finding 5 — no overflow, no `bool`/type guard present (a deliberate non-finding + a watch-item)

Two things worth stating explicitly:

- **No overflow.** Python integers are arbitrary-precision; the parity result is a
  pure boolean and never overflows for any magnitude of `n` (whenever the recursion
  is allowed to complete — see Finding 3).
- **No type guard (watch-item, not a bug today).** Unlike `sum-recursive`, this code
  has no `isinstance` check. In Python `bool` is a subclass of `int`, so
  `is_even(True)` would recurse on `True - 1 == 0` and return `is_even`'s base-case
  `True` (treating `True` as `1` → `is_odd(0) == False`); a non-integer `n` (e.g. a
  float like `2.5`) would also never hit `n == 0` and would not terminate. These are
  out-of-spec inputs (the precondition is "`n` a non-negative **int**"); flagged so a
  caller knows the functions assume an integer and do not defend against other types.

---

*Next: run `/verify` to construct the proof of `(EVEN)`/`(ODD)`/`(EVENFN)`/`(ODDFN)`
and get the test-redundancy recommendation (benefit 1). Finding 1 describes the
out-of-domain non-termination any `n < 0` test should pin; Finding 3 is a
termination/robustness matter the partial-correctness proof does not cover — keep
(or add) a test for it.*
