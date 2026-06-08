# Findings report — `factorial.py`

Plain-language findings from formalizing [`factorial.py`](factorial.py). Each is
`input → observed vs expected`. **Non-blocking** — this report never edits or deletes
your code; it is advice. These findings **do not** depend on machine-checking the
proof — they are solid today. (Each observed value below was checked by **running the
actual function**.)

---

## Finding 1 — `n >= 0` is ENFORCED, not silently assumed (a *positive* finding)

The precondition the spec needs (`requires N >=Int 0`) is **enforced at runtime** by
`if n < 0: raise ValueError("n must be a non-negative integer")`:

| input `n` | code does (observed) | expected for "n factorial" | verdict |
|---|---|---|---|
| `-3` | **raises `ValueError`** | undefined / rejected | ✓ correct rejection |
| `-1` | **raises `ValueError`** | undefined / rejected | ✓ correct rejection |
| `0`  | `1`   | `1`   | ✓ |
| `5`  | `120` | `120` | ✓ |

`factorial(-3)` and `factorial(-1)` both raise `ValueError` — a defined, intentional
rejection, not a silent wrong answer. The formal contract `(FACT)` is stated with
`requires N >=Int 0`; here that side condition is **not a latent bug but a guard the
code already implements**. **No action needed** — the function does the right thing on
the negative boundary.

## Finding 2 — NO `bool` guard: `True`/`False` slip through (the one real smell)

Unlike the `sum-recursive` sibling (which guards with `isinstance(n, bool)`),
`factorial.py` has **no type guard at all**. In Python `bool` is a **subclass of
`int`** (`isinstance(True, int)` is `True`, and `True == 1`, `False == 0`), so a
boolean is accepted and silently coerced:

| input `n` | code does (observed) | arguably expected |
|---|---|---|
| `True`  | `1` (treats `True` as `1`, computes `1!`) | `TypeError` (a bool is not a count) |
| `False` | `1` (treats `False` as `0`, computes `0!`) | `TypeError` |

This is **out of the verified integer domain** and is the closest thing to a genuine
smell here. It is not *wrong* arithmetically — `factorial(True)` does return `1!` and
`factorial(False)` returns `0!` — but a caller passing a boolean by mistake gets a
silently-accepted answer instead of an error. **Recommendation (optional):** if
booleans should be rejected, add `isinstance(n, bool)` to the guard, mirroring the
`sum-recursive` example. **Keep a regression test** pinning whichever behavior you
intend. (The spec models the genuine-`int` domain only; `bool` is out of domain.)

## Finding 3 — recursion-depth limit: a real corner case (measured boundary)

This is the one finding that recommends action. The contract is **partial
correctness** — `factorial(n) = n!` *if and when it returns*. For this recursive
implementation that "if" bites at a concrete, **measured** boundary: **non-tail
recursion** consumes one Python stack frame per unit of `n`, so it hits CPython's
default recursion limit (`sys.getrecursionlimit() == 1000`):

| input `n` | code does (observed) | mathematically expected |
|---|---|---|
| `998`    | returns `998!` (a 2562-digit integer) | `998!` ✓ |
| `999`    | **raises `RecursionError`** | `999!` |
| `100000` | **raises `RecursionError`** | `100000!` |

Measured in a clean process: the smallest `n` that raises is **999** (so the function
returns correctly only for `0 <= n <= 998` at the default limit). This is *sharper*
than a generic "termination is unproved" caveat: the implementation **provably fails
to return** for `n >= 999`, so the postcondition is *vacuously* (partial-correctness)
satisfied there only because the function never returns at all.

**Recommendation:** for unbounded `n`, prefer an **iterative** loop (`for k in
range(2, n+1): acc *= k`) or `math.factorial(n)` (both O(1) Python stack). If the
recursive form is kept for clarity, document the input-range limit, or raise the
limit deliberately (`sys.setrecursionlimit(...)`), or rewrite to **tail-recursive +
trampoline**. The underlying recursion *is* mathematically well-founded — the measure
`n` strictly decreases by 1 each call and is bounded below by `0` (base case `n == 0`)
— so in idealized semantics it terminates for every `n >= 0`; the limit is purely a
CPython stack-depth artifact.

## Finding 4 — spec-difficulty / methodology signal: NO polynomial closed form

Writing the spec was clean, but it required a step **past even the `sum-recursive`
fast-path**: `factorial(n) = n!` has **no polynomial (or any fixed algebraic) closed
form**, so the postcondition cannot be an ordinary arithmetic term the way
`sum_recursive`'s `n*(n+1)/2` was. The kit's reachability-and-circularities primer §7
names this exact case ("factorial's `N!/(I-1)!`"). The disciplined resolution — *not*
a fudge — is a **spec-only recursive function symbol** `fact(Int) [function]`
(`fact(0)=1`, `fact(N)=N*fact(N-1)`) declared in the `VERIFICATION` module; the
recursive-step VC `N * fact(N-1) = fact(N)` then discharges by `fact`'s **own defining
rule** (definitional unfolding), needing **no exact-halving / `/Int` lemma** at all
(factorial uses no division). Recorded here for honesty, not as a code bug: the
artifacts are **constructed, not machine-checked**, and the `fact` spec symbol plus
the recursion circularity `(REC)` are the pieces a reviewer should scrutinize first
when `kprove` is eventually run. See the `[ESCALATION BOUNDARY]` note in
[`PROOF.md`](PROOF.md) regarding what the bundled VC tier does and does not settle for
a recursively-defined spec symbol.

## Finding 5 — no overflow (a deliberate non-finding)

Worth stating because a C/Java version would have one: Python integers are
arbitrary-precision, so there is **no overflow** for large `n` — `factorial(20)` is
`2432902008176640000` (exact), `factorial(100)` is a 158-digit integer, all exact.
The recursive `n * factorial(n-1)` agrees with `n!` at every magnitude (whenever the
recursion is actually allowed to complete; see Finding 3). The base case is also
off-by-one-clean: `factorial(0) = 1 = 0!`, and `return n * factorial(n-1)` includes
`n` itself, so the recursion computes `1*2*...*n` exactly. No action needed.

---

*Next: run `/verify` to construct the proof of `(FACT)`/`(REC)` and get the
test-redundancy recommendation (benefit 1). Finding 1 describes the enforced negative
boundary any `n < 0` test should keep pinning; Finding 2 (the missing `bool` guard) is
an optional hardening; Finding 3 is a **termination/robustness** matter that the
partial-correctness proof does not cover — keep (or add) a test for it.*
