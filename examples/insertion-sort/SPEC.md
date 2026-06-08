# Specification note — `insertion_sort.py`

Plain-English companion to the formal artifacts, for a developer who will never
open the `.k` files. Produced by the formal-verification-kit `/formalize` step.

- **Program:** [`insertion_sort.py`](insertion_sort.py) — `insertion_sort(array)`
  returns a new list holding the elements of `array` in non-decreasing order,
  using the classic **two-nested-`while`-loop** insertion sort (outer loop walks
  `i` up the array; inner loop shifts larger elements right to open a slot for
  `key = result[i]`).
- **Artifacts:** [`mini-python.k`](mini-python.k) (the mini-X fragment semantics,
  now over **lists**), [`mini-python-spec.k`](mini-python-spec.k) (three K
  `claim`s: the function contract and the two loop circularities).
- **Status:** specs **constructed, not machine-checked** (the MVP does not run
  `kompile`/`kprove`). The Findings (see [`FINDINGS.md`](FINDINGS.md)) hold today
  regardless of machine-checking.
- **Default scope:** **partial correctness** — the contract constrains terminating
  runs; termination itself is a recommendation (see Findings), not proved.

> **Up front — this is a kit *escalation* target, not a fast-path one.** Every
> bundled example (`sum-up`, `sum-down`, `sum-recursive`) has a **polynomial
> closed-form** postcondition (`n*(n+1)/2`). Sorting does not. Its contract is two
> **non-arithmetic** predicates — *sortedness* and *permutation (multiset
> equality)* — over a **list**. The kit explicitly lists "array / list loop" as a
> roadmap shape and "recursive data structures / inductively-defined predicates"
> as an escalation case. So the claims below are **constructed at the fragment
> level and well-formed**, but some of their verification conditions need an
> inductive list/multiset theory the bundled simplification tier does not supply.
> Those are flagged `[ESCALATION BOUNDARY]` in the spec file and itemized in
> [`FINDINGS.md`](FINDINGS.md) #6. This honesty *is* the deliverable here.

## What is specified

### Function contract — `(SORT)`

> **Precondition:** none beyond the model (elements are `Int`, which is totally
> ordered — see the modeling note and Finding 1).
> **Postcondition:** `insertion_sort(A)` returns `R` with
> **(a)** `len(R) == len(A)`, **(b)** `R` is sorted (non-decreasing), and
> **(c)** `R` is a permutation of `A` (same multiset of elements).

All three conjuncts are needed: (b) alone is met by `[]`; (c) alone is met by
returning `A` unchanged. Together they pin "sorted *rearrangement* of the input."

### Outer-loop invariant — `(OUTER)` (circularity #1)

> At the head of `while i < len(result)`, with `1 <= i <= len`: the prefix
> `result[0:i]` is **sorted**, and `result` as a whole is a **permutation** of the
> original input (length is invariant — insertion sort never grows or shrinks the
> array). Running the loop to exit (`i = len`) leaves the **whole** array sorted
> and still a permutation.

Generalized over the array value and the counter `i` (not pinned to entry
values), this is the loop's reachability claim; K's prover uses it as its own
coinduction hypothesis, so it **discharges its own loop**. The "sorted prefix that
grows by one each iteration" plays the role a hand-written invariant used to.

### Inner-loop invariant — `(INNER)` (circularity #2, the crux)

> At the head of `while j >= 0 and result[j] > key`, the array is in a **"hole"**
> state: positions `[0, j+1)` are the original sorted prefix (untouched);
> positions `[j+2, i]` hold the elements that have been **shifted one step right**
> and are all `> key`; and position `j+1` is a *duplicate hole*. The key invariant
> is that **filling the hole with `key` recovers the entry multiset** — that is
> what makes the whole insert a permutation. The loop exits when it runs off the
> front (`j = -1`) or finds `result[j] <= key`; the following statement
> `result[j+1] = key` fills the hole, restoring both sortedness of `[0, i+1)` and
> the multiset.

This nested "insert into a hole" invariant is the genuinely intricate part, and is
exactly where multiset-preservation-under-a-shift and sorted-prefix-composition
arguments are required — the `[ESCALATION BOUNDARY]` obligations.

## How the function proof composes (for `/verify`)

`def` files the body → `call` binds `array = A` in a fresh scope →
`result = list(array)` (a copy; **free** in this model because `List` is a value
sort, so the caller's `array` can never be mutated — see Finding 4) → `i = 1` →
**apply `(OUTER)` at `{B := result, I := 1}`**; its precondition `isSorted(take(A,1))`
holds because any 0- or 1-element prefix is trivially sorted (the analogue of the
sum example's `1 <= N+1` following from `N >= 0`) → the loop yields a fully sorted
permutation → `return result` delivers it → `out |-> R`. Each outer iteration in
turn **applies `(INNER)` as a lemma** to perform one insertion.

So the lemma chain is **nested**: `(SORT)` reuses `(OUTER)` reuses `(INNER)` —
one level deeper than the sum example's `(SUM)` reuses `(LOOP)`. That extra nesting
is the teaching payload of this example (a *two-nested-loop* shape).

## Arithmetic / data the proof will need

- **Bundled (supplied here):** map extensionality
  `{M[K<-V] #Equals M[K<-V']} => {V #Equals V'}` (closes the post-store cell
  equality), plus linear index/bounds facts for Z3 (`1 <= I <= size`,
  `-1 <= J < I`, in-bounds index reads/writes).
- **Escalation boundary (stated, NOT bundled-derivable):**
  1. **Multiset preservation under one index-update** — `bag(L[p<-v])` differs
     from `bag(L)` only by swapping one element; the engine of permutation across
     a shift. Needs a multiset/`Bag` theory with element delete.
  2. **Sorted-prefix composition** — a contiguous shifted block of a sorted list
     stays sorted, and `prefix ++ [key] ++ block` is sorted when
     `prefix <= key < block`. Needs inductive `isSorted`/`range` lemmas.
  Route per [`knowledge/sources.md`](../../knowledge/sources.md): **OOPSLA'20** (unified
  fixpoint reasoning over inductive data structures) and **LICS'19** (Matching
  mu-Logic). `/verify --refresh` re-fetches these.

## Mini-X semantics scope (only what the code touches)

Integer literals/names, `len`, `list` (copy), index read `e[e]`, index assign
`x[e]=e`, `+`, `-`, `<`, `>`, `>=`, short-circuit `and`, `=`, `while`, `def`,
`return`, call. **No `if`**, **no `or`/`not`**, **no `*`/`/`**, **no slices**, **no
exceptions**. Elements are modeled as `Int` (faithful restriction; genericity is
Finding 1). `insertion_sort.py` is the **pure function only** — no `__main__`/I/O.

## Next step

Run the kit's **`/verify`** to construct the proof of these claims, emit the
`kompile`/`kprove` commands, and get the test-redundancy recommendation — and to
make the `[ESCALATION BOUNDARY]` obligations concrete (it will get stuck exactly
there, which is itself the honest signal that this shape needs the inductive
theory above).
