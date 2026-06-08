# Specification note — `factorial.py`

Plain-English companion to the formal artifacts, for a developer who will never
open the `.k` files. Produced by the formal-verification-kit `/formalize` step.

- **Program:** [`factorial.py`](factorial.py) — `factorial(n)` returns `n!`
  (`n! = 1 * 2 * ... * n`, with `0! = 1`) by **recursion**
  (`if n == 0: return 1; return n * factorial(n - 1)`), guarded by a value check
  (`if n < 0: raise ValueError`).
- **Artifacts:** [`mini-python.k`](mini-python.k) (the mini-X fragment semantics),
  [`mini-python-spec.k`](mini-python-spec.k) (the two K `claim`s).
- **Status:** specs **constructed, not machine-checked** (the kit does not run
  `kompile`/`kprove`). The Findings (see [`FINDINGS.md`](FINDINGS.md)) hold today
  regardless of machine-checking — each was checked by running the real code.
- **Default scope:** **partial correctness** — the contract constrains terminating
  runs; termination is a recommendation, not proved (and see Finding 3 — for this
  *recursive* function termination has a real, measured implementation caveat).

## What is specified

### Function contract — `(FACT)`

> **Precondition:** `n >= 0`.
> **Postcondition:** `factorial(n) = fact(n)`, where `fact` is the mathematical
> factorial `n!`.

For every non-negative `n`, the function returns `n!`. Encoded as a reachability
claim: from a configuration that *defines* `factorial` and *calls* it on a symbolic
`N >= 0`, execution terminates with `result |-> fact(N)`.

### Recursion circularity — `(REC)`

> Evaluating a call `factorial(N)` (with the function already defined, side
> condition `N >= 0`) reduces to the value `fact(N)`, threading the caller's
> continuation through and leaving the store and stack net-unchanged.

**This replaces the loop invariant of the `sum-up`/`sum-down` examples.** There is
no loop here, so there is **no `(LOOP)` claim**. Instead the *function's own
contract is the coinductive hypothesis*: K's reachability prover treats every claim
in the module as a circularity, so `(REC)` **discharges its own recursive call**
`factorial(N-1)`. The recursive call plays the role of the loop back-edge.

## The distinctive payload: there is no polynomial closed form

This is the one real difference from the `sum-recursive` sibling. `sum_recursive(n)`
has the **polynomial closed form** `n*(n+1)/2`, so its postcondition is an ordinary
arithmetic term and its recursive-step verification condition closes via an
exact-halving lemma over integer division.

`factorial(n) = n!` has **no polynomial — indeed no fixed algebraic — closed form**:
`n!` grows faster than every polynomial and cannot be written as a finite arithmetic
expression in `n`. The kit's reachability-and-circularities primer (§7) names this
exact case as needing "a recursively-defined symbol and its own simplification
lemmas." So we do the honest thing and introduce a **spec-only recursive function
symbol**

```
fact(Int)  [function]
    fact(0)  = 1
    fact(N)  = N *Int fact(N - 1)     for N > 0
```

declared in the `VERIFICATION` module of [`mini-python-spec.k`](mini-python-spec.k).
This is **spec vocabulary, not a language construct** — the program never names
`fact`; it exists only to *state* the postcondition `result |-> fact(N)`. It mirrors
`factorial`'s own recursion, which is precisely why the step VC discharges cleanly
(see below).

## How the function proof composes (for `/verify`)

`def` files the body → `result = factorial(N)` evaluates the argument and the call
heats to the head of `<k>` → **apply `(REC)` at the symbolic `N`** (side condition
`N >= 0` is the function precondition) → the call delivers `fact(N)` → the
assignment lands `result |-> fact(N)`.

`(REC)` itself is proved by symbolic execution + coinduction: run the call one step
(the `(call)` rule — the genuine `=>⁺` step that earns the hypothesis), bind `n = N`
in a fresh scope, evaluate the guard `n == 0`, and case-split:

- **base (`N == 0`):** `if true: return 1` returns `1`, and `fact(0) = 1` by `fact`'s
  base rule. ✓ (VC-BASE)
- **recursive (`N >= 1`):** the guard is false and falls through to
  `return n * factorial(n - 1)`; the inner call is closed by **`(REC)` on `N-1`**
  giving `fact(N-1)`, then `n * …` makes `N * fact(N-1)`, which equals `fact(N)`
  **by `fact`'s own defining rule** `fact(N) = N * fact(N-1)` for `N > 0`. ✓ (VC-STEP)

## Arithmetic the proof will need

- **Map extensionality** `{M[K<-V] #Equals M[K<-V']} => {V #Equals V'}` — to close
  the post-store implication that pins `result`. (Same lemma as every sibling.)
- **`fact`'s defining rules** — the recursive-step VC `N * fact(N-1) = fact(N)`
  (for `N > 0`) is discharged by **definitional unfolding**: it is `fact`'s own
  defining rule read right-to-left, a syntactic rewrite. **No exact-halving lemma,
  and no nonlinear `/Int` reasoning, is needed** — factorial uses no division at
  all. So the VC *tier* here is actually **simpler** than `sum-recursive`'s; the
  whole difficulty of "no closed form" has been paid up front, in *defining* the
  spec symbol `fact`. The base VC `N == 0 => fact(N) = 1` is `fact`'s base rule.

## Mini-X semantics scope (only what the in-domain core touches)

Integer literals/names, `*` (**the new operator vs. `sum-recursive`, which had
`+`**), `-`, `==`, assignment, `if` (no `else`), `def`, `return`, call. **No
`while`**, **no `+=`**, **no `+`**, **no `<=`/`<`** (the recursive core uses none of
them). **Set aside, deliberately:** the value **guard layer** (`if n < 0: raise
ValueError`) — Python exceptions are an escalation case for this kit, and on the
verified domain `n >= 0` that guard is a no-op, so the modeled body is value-faithful
(the guard only changes behavior *outside* the domain, where it raises — itself the
subject of Finding 1). Note there is **no `isinstance`/`TypeError` guard** in this
program (a difference from `sum-recursive`), which is recorded as Finding 2.

## Next step

Run the kit's **`/verify`** to construct the proof of `(FACT)`/`(REC)`, emit the
`kompile`/`kprove` commands, and get the test-redundancy recommendation.
