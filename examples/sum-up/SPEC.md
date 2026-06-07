# Specification note — `sum.py`

Plain-English companion to the formal artifacts, for a developer who will never
open the `.k` files. Produced by the formal-verification-kit `/formalize` step.

- **Program:** [`sum.py`](sum.py) — `sum_to_n(n)` sums the integers `1..n` with an
  **up-counting** loop (`s = 0; i = 1; while i <= n: s += i; i += 1`).
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

> From any state with `s = S`, `i = I`, `n = N`, and **`I <= N+1`**, running the
> loop adds the running sum `cfA(I,N) = Σ_{k=I}^{N} k = (I+N)*(N-I+1)/2` to `s` and
> leaves `i = N+1`.

Generalized over the accumulator `S` and counter `I` (not pinned to entry values),
this is the loop's reachability claim; K's prover uses it as its own coinduction
hypothesis, so it **discharges its own loop** — replacing a hand-written invariant.
The closed form `cfA(I,N) = (N*(N+1) - (I-1)*I)/2` plays the role the classical
invariant used to.

**Two things specific to this up-counting program** (the mirror of the down-counting
`sum`'s two):

1. **The loop spec depends on `n`.** The guard `i <= n` reads `n`, so the value of
   `n` is needed every iteration — and `(LOOP)` therefore carries `n |-> N` in its
   store. Unlike the down-counting `sum` example (whose `i >= 1` guard compares to
   the constant `1`, framing `n` out of the loop claim entirely), here `n` appears
   in `(LOOP)`. The loop's effect depends on `s`, `i`, **and** `n`.
2. **There is an "init" VC.** The loop is entered at `i = 1`, so landing the
   function postcondition owes one closed-form fact: `cfA(1,N) = N*(N+1)/2`. Unlike
   the down-counting `sum` (which enters at `i = N`, where the closed form is
   *syntactically* the target `N*(N+1)/2` already), entry here is at `1` and the
   running sum must be reduced to the target. Composition is otherwise clean:
   `(LOOP)`'s side condition at entry is `1 <= N+1`, which is *exactly* the function
   precondition `N >= 0`.

## How the function proof composes (for `/verify`)

`def` files the body → `call` binds `n = N` in a fresh scope → `s = 0`, `i = 1` →
**apply `(LOOP)` at `{S := 0, I := 1}`** (side condition `1 <= N+1` discharged by
`N >= 0`) → `s = N*(N+1)/2` → `return` delivers it → `result |-> N*(N+1)/2`.

## Arithmetic the proof will need

- **Map extensionality** `{M[K<-V] #Equals M[K<-V']} => {V #Equals V'}` — to close
  the post-store implication that pins `result`.
- **Exact-halving** lemmas — the up-counting invariant divides a *symbolic* product
  and the inductive step equates two distinct products under truncating `/Int`;
  since a product of consecutive integers is even, each halving is exact. **Both**
  `[simplification]` rules in [`mini-python-spec.k`](mini-python-spec.k) are
  exercised here (the simple `X*(X+1)/2 *2` cancellation *and* the guarded
  `(A+B)*C/2 *2` cancellation) — unlike the down-counting `sum`, where only one
  fires.

## Mini-X semantics scope (only what the code touches)

Integer literals/names, `+`, `<=`, `=`, assignment, `+=`, `while`, `def`,
`return`, call. **No `if`**, **no `>=`**, **no `-=`** (this program never uses them).
`sum.py` is the **pure function only** — there is no `__main__`/I/O wrapper, so
there is nothing outside the verified core to set aside.

## Next step

Run the kit's **`/verify`** to construct the proof of these claims, emit the
`kompile`/`kprove` commands, and get the test-redundancy recommendation.
