# Specification note — `sum.py`

Plain-English companion to the formal artifacts, for a developer who will never
open the `.k` files. Produced by the formal-verification-kit `/formalize` step.

- **Program:** [`sum.py`](sum.py) — `sum_to_n(n)` sums the integers `1..n` with a
  **down-counting** loop (`i = n; while i >= 1: total += i; i -= 1`).
- **Artifacts:** [`mini-python.k`](mini-python.k) (the mini-X fragment semantics),
  [`mini-python-spec.k`](mini-python-spec.k) (the two K `claim`s).
- **Status:** specs **constructed, not machine-checked** (the MVP does not run
  `kompile`/`kprove`). The Findings (see [`FINDINGS.md`](FINDINGS.md)) hold today
  regardless of machine-checking.
- **Default scope:** **partial correctness** — the contract constrains terminating
  runs; termination itself is a recommendation (see Findings), not proved.

## What is specified

### Function contract — `(SUM)`

> **Precondition:** `n >= 0`.
> **Postcondition:** `sum_to_n(n) = n*(n+1)/2`.

For every non-negative `n`, the function returns the closed-form triangular number
`n*(n+1)/2`. Encoded as a reachability claim: from a configuration that *defines*
`sum_to_n` and *calls* it on a symbolic `N >= 0`, execution terminates with
`result |-> N*(N+1)/2`.

### Loop invariant — `(LOOP)` (the circularity)

> From any state with `total = T`, `i = I`, and **`I >= 0`**, running the loop
> adds `Σ_{k=1}^{I} k = I*(I+1)/2` to `total` and leaves `i = 0`.

Generalized over the accumulator `T` and counter `I` (not pinned to entry values),
this is the loop's reachability claim; K's prover uses it as its own coinduction
hypothesis, so it **discharges its own loop** — replacing a hand-written invariant.
The closed form `I*(I+1)/2` plays the role the classical invariant used to.

**Two things specific to this down-counting program:**

1. **The loop spec is independent of `n`.** The guard `i >= 1` compares to the
   constant `1`, so unlike the up-counting `sum` example (whose `i <= n` guard
   pulled `n` into the loop claim), `n` does not appear in `(LOOP)` at all. It is
   framed out with `...` in the store. The loop's effect depends only on `total`
   and `i`.
2. **The side condition `I >= 0` is load-bearing**, not cosmetic — see the Findings
   "spec-difficulty signal." Composition is clean: the body sets `i = n` (so the
   loop is entered at `I = N`), and `(LOOP)`'s side condition `0 <= N` is *exactly*
   the function precondition `N >= 0`.

## How the function proof composes (for `/verify`)

`def` files the body → `call` binds `n = N` in a fresh scope → `total = 0`, `i = n`
(= `N`) → **apply `(LOOP)` at `{T := 0, I := N}`** (side condition discharged by
`N >= 0`) → `total = N*(N+1)/2` → `return` delivers it → `result |-> N*(N+1)/2`.

## Arithmetic the proof will need

- **Map extensionality** `{M[K<-V] #Equals M[K<-V']} => {V #Equals V'}` — to close
  the post-store implication that pins `result`.
- **Exact-halving** lemmas — the inductive step VC equates two symbolic products
  under truncating `/Int` (`I + (I-1)*I/2 = I*(I+1)/2`); since a product of
  consecutive integers is even, halving is exact. Supplied as `[simplification]`
  rules in [`mini-python-spec.k`](mini-python-spec.k).

## Mini-X semantics scope (only what the code touches)

Integer literals/names, `+`, `-`, `>=`, assignment, `+=`, `-=`, `while`, `def`,
`return`, call. **No `if`**, **no `<=`** (this program never uses them). The
`int(input())`/`print()` wrapper in `sum.py`'s `__main__` block is I/O outside the
verified core and is intentionally **not** modeled — see Findings.

## Next step

Run the kit's **`/verify`** to construct the proof of these claims, emit the
`kompile`/`kprove` commands, and get the test-redundancy recommendation.
