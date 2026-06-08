# Specification note — `even_odd.py`

Plain-English companion to the formal artifacts, for a developer who will never
open the `.k` files. Produced by the formal-verification-kit `/formalize` step.

- **Program:** [`even_odd.py`](even_odd.py) — two **mutually recursive** functions,
  `is_even(n)` and `is_odd(n)`, that decide the parity of a non-negative integer by
  bouncing back and forth: `is_even(n)` returns `True` at `n == 0` else
  `is_odd(n - 1)`; `is_odd(n)` returns `False` at `n == 0` else `is_even(n - 1)`.
- **Artifacts:** [`mini-python.k`](mini-python.k) (the mini-X fragment semantics),
  [`mini-python-spec.k`](mini-python-spec.k) (the four K `claim`s — two circularities,
  two function contracts).
- **Status:** specs **constructed, not machine-checked** (the MVP does not run
  `kompile`/`kprove`). The Findings (see [`FINDINGS.md`](FINDINGS.md)) hold today
  regardless of machine-checking.
- **Default scope:** **partial correctness** — the contract constrains terminating
  runs; termination is a recommendation, not proved. And for *this* program
  termination has a sharp, real caveat: for `n < 0` the mutual recursion **never
  terminates** (Finding 1), and for large `n` it hits CPython's recursion limit
  (Finding 3).

## What is specified

### Function contracts — `(EVENFN)` / `(ODDFN)`

> **Precondition:** `n >= 0`.
> **Postcondition:** `is_even(n) = (n mod 2 == 0)` and `is_odd(n) = (n mod 2 == 1)`.

For every non-negative `n`, `is_even` returns exactly the boolean "n is even" and
`is_odd` returns exactly "n is odd". Encoded as reachability claims: from a
configuration that *defines both* functions and *calls* one of them on a symbolic
`N >= 0`, execution terminates with `r |-> (N mod 2 == 0)` (resp. `== 1`).

The evenness predicate is the **spec-only** expression `N mod 2 == 0` (built from
K's builtin `modInt`); we do not introduce a custom inductive `isEven` symbol —
none is needed (see "Arithmetic the proof will need").

### Mutual-recursion circularities — `(EVEN)` / `(ODD)` (this example's distinctive shape)

> **(EVEN):** evaluating a call `is_even(N)` (both functions defined, `N >= 0`)
> reduces to `N mod 2 == 0`, threading the caller's continuation through and leaving
> the store and stack net-unchanged.
> **(ODD):** symmetrically, `is_odd(N)` reduces to `N mod 2 == 1`.

**This replaces the loop invariant of the `sum-*` loop examples and generalizes the
single `(REC)` of `sum-recursive`.** There is no loop, so there is **no `(LOOP)`
claim**. And unlike `sum-recursive` — where one claim `(REC)` discharged *its own*
recursive call — here the recursion is **mutual**, so the circularity **spans two
claims that discharge each other**:

1. **The circularity crosses between two contracts.** K's reachability prover
   treats *every* claim in the module as a coinduction hypothesis, so while proving
   `(EVEN)` the hypothesis `(ODD)` is available, and vice versa. `(EVEN)`'s
   recursive branch calls `is_odd(N-1)` → discharged by `(ODD)`; `(ODD)`'s recursive
   branch calls `is_even(N-1)` → discharged by `(EVEN)`. Neither claim discharges
   its own call; **each is the other's coinduction hypothesis.** That mutual
   cross-discharge is the new teaching payload over `sum-recursive`. **Guardedness**
   is paid, in each, by the `(call)` step that fires before the *other* hypothesis
   is reused.

2. **The side condition `N >= 0` is load-bearing for TERMINATION, not just for the
   value.** The only base case on a *descending* `n` chain is `n == 0`. For `N >= 1`
   the recursive branch is taken and the other circularity is applied at `N-1`
   (precondition `N-1 >= 0` from `N >= 1`), so the chain `N, N-1, …, 0` bottoms out.
   For `N < 0` the chain `N, N-1, N-2, …` **never reaches 0** — the mutual recursion
   does not terminate (a `RecursionError` in CPython; see [`FINDINGS.md`](FINDINGS.md)
   Finding 1). So `requires N >= 0` is not cosmetic and not merely a closed-form
   bound — it is what makes the recursion well-founded at all.

## How the function proofs compose (for `/verify`)

Both `def`s file their bodies (both must be in `<funcs>` — the functions are
mutually dependent) → `r = is_even(N)` evaluates the argument and the call heats to
the head of `<k>` → **apply `(EVEN)` at the symbolic `N`** (side condition `N >= 0`
is the precondition) → the call delivers `N mod 2 == 0` → the assignment lands
`r |-> (N mod 2 == 0)`. `(ODDFN)` is symmetric via `(ODD)`.

`(EVEN)`/`(ODD)` themselves are proved by symbolic execution + **mutual** coinduction
(each may assume the *other*, reused only after a real step): run the call one step
(the `(call)` rule — the genuine `=>⁺` that earns the hypothesis), bind `n = N` in a
fresh scope, evaluate the guard `n == 0`, and case-split:

- **base (`N == 0`):**
  - `(EVEN)`: `if true: return True`; and `0 mod 2 == 0` is `True`. ✓ (VC-EVEN-BASE)
  - `(ODD)`:  `if true: return False`; and `0 mod 2 == 1` is `False`. ✓ (VC-ODD-BASE)
- **recursive (`N >= 1`):**
  - `(EVEN)`: guard false → `return is_odd(n - 1)`; the inner call is closed by
    **`(ODD)` on `N-1`** giving `(N-1) mod 2 == 1`, which equals `N mod 2 == 0`. ✓
    (VC-EVEN-STEP)
  - `(ODD)`: guard false → `return is_even(n - 1)`; closed by **`(EVEN)` on `N-1`**
    giving `(N-1) mod 2 == 0`, which equals `N mod 2 == 1`. ✓ (VC-ODD-STEP)

## Arithmetic the proof will need

- **Map extensionality** `{M[K<-V] #Equals M[K<-V']} => {V #Equals V'}` — to close
  the post-store implication that pins `r` (here `V` is a `Bool`).
- **Parity mod-shift lemmas** — the recursive step equates `(N-1) mod 2 == 1` with
  `N mod 2 == 0` (and the mirror). These are **single-decrement parity facts**
  ("subtracting 1 flips the parity bit"), *not* an induction over `N`: the induction
  is carried by the **circularity**, not by the predicate. They are supplied as two
  `[simplification]` rules in [`mini-python-spec.k`](mini-python-spec.k), each guarded
  by `requires N >= 1`. Because they are non-inductive single-step facts, **no
  custom inductive predicate is needed and the proof does not hit an escalation
  boundary** (contrast the insertion-sort example, whose `isSorted`/`bag` VCs do).
  The base-case VCs (`0 mod 2 == 0` is `True`; `0 mod 2 == 1` is `False`) are
  concrete and fall to Z3 directly.

## Mini-X semantics scope (only what the in-domain core touches)

Integer literals/names, `-`, `==`, **Bool literals** (`True`/`False` as return
values), assignment, `if` (no `else`), `def`, `return`, call. **No `while`**, **no
`+=`**, **no `+`**, **no `<=`/`<`** (the program uses none of them). The one
generalization over `sum-recursive` in the *semantics*: `return` and the call/return
plumbing carry a **`Val` = `Int | Bool`** value, because these functions return a
`Bool` (parity) rather than an `Int`. The `if __name__ == "__main__"` test block
(asserts, a `for` loop, `print`) is I/O outside the verified core and is
intentionally **not** modeled.

## Next step

Run the kit's **`/verify`** to construct the proof of
`(EVEN)`/`(ODD)`/`(EVENFN)`/`(ODDFN)`, emit the `kompile`/`kprove` commands, and get
the test-redundancy recommendation.
