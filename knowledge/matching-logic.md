# Matching Logic — a primer for the agent

This is the fast path: enough matching logic to read, write, and trust the specs and
proofs this kit produces. It is **not** a paper. For the common case (verifying a
function with arithmetic, maps, and a loop — like the `sum` example) this is all you
need. For deep cases, see **LIMITS + ESCALATION** at the bottom and route to
[`sources.md`](sources.md).

The single idea: **one logic for both terms and formulas, because a pattern denotes a
set.** That is why K can write a program configuration and a logical constraint in the
*same* formula — and why `#And`/`#Or`/`#Equals`/`#Not`/`#Exists` in a K claim are
literally matching-logic connectives.

## 1. One-line model: patterns are sets

Fix a carrier set `M` (the model). Every **pattern** `φ` is interpreted as a **subset**
`|φ| ⊆ M`: *the set of elements that match it*. A term like `5` or `cons(x, xs)` is just
a pattern whose set happens to be a singleton (or empty, for a partial application). A
formula like `x = 5` is a pattern whose set is `M` (true everywhere) or `∅` (false). So
terms and formulas are the same kind of object — they differ only in *how big* their set
is. This collapse is what unifies "structure" (terms) and "constraints" (formulas).

## 2. Connectives are set operations

The logical connectives are just Boolean algebra on subsets of `M`:

| pattern | meaning | as a set |
| --- | --- | --- |
| `⊥` | bottom | `∅` |
| `⊤` | top | `M` |
| `φ₁ ∧ φ₂` | and | `|φ₁| ∩ |φ₂|` |
| `φ₁ ∨ φ₂` | or | `|φ₁| ∪ |φ₂|` |
| `¬φ` | not | `M \ |φ|` (complement) |
| `∃x. φ` | exists | `⋃` over all witnesses for `x` |
| `φ₁ → φ₂` | implies | `¬φ₁ ∨ φ₂`, i.e. `(M \ |φ₁|) ∪ |φ₂|` |

A pattern is **valid** iff its set is all of `M`. Note `∃` is *union over witnesses*,
which is why `∃` mixes freely with structure: `∃x. cons(x, nil)` denotes "all one-element
lists" (lowercase `x` is an element variable; capitals are reserved for the set variables of §5). `∀x. φ ≡ ¬∃x. ¬φ` as usual.

## 3. Symbols, application, functions

Each sort's elements live in `M`; a **symbol** is interpreted as a relation, lifted to
the powerset, and **application is pointwise**: `|σ(φ)| = ⋃ { |σ|(a) : a ∈ |φ| }`. This
one mechanism subsumes the usual cases as **special shapes**, not extra primitives:

- a **function** symbol returns a singleton for each argument tuple → ordinary term;
- a **partial function** may return `∅` (undefined) on some inputs → naturally models
  partiality (e.g. `head(nil)`), with no error value needed;
- a **relation** returns any subset.

So "K builtins" like `+Int`, `<=Int`, `/Int` (truncates toward zero) are total/partial
function symbols; `_|->_` and `_[_<-_]` on `MAP` are symbols; a configuration cell is a
symbol applied to its contents. Nothing special — all patterns.

## 4. The definedness ladder (everything below is DERIVED)

Matching logic has *one* extra ingredient beyond FOL-style syntax: a single **definedness
symbol** `⌈_⌉` with the axiom `⌈x⌉ = ⊤` (for a variable `x`). Read `⌈φ⌉` as "`φ` is
defined" — i.e. matches *something*. The axiom is the only thing fixed; from it, *in any
model of the axiom*, it follows that `|⌈φ⌉| = M` when `|φ| ≠ ∅` and `∅` otherwise. From this one
symbol the whole reasoning toolkit is **defined, not assumed**:

- **Totality:** `⌊φ⌋ ≡ ¬⌈¬φ⌉` — "`φ` matches everything."
- **Equality:** `φ₁ = φ₂ ≡ ⌊φ₁ ↔ φ₂⌋`. This is **two-valued** (its set is `M` or `∅`),
  which plain FOL `↔` *cannot* express: in FOL `φ₁ ↔ φ₂` is true wherever the two agree
  pointwise, but it does not say the two *sets are equal*. Matching logic can — that is the
  whole point, and it is what makes `#Equals` in K a real equality.
- **Membership:** `x ∈ φ ≡ ⌈x ∧ φ⌉` — "`x` is one of the elements matching `φ`."
- **Sorts:** a sort `s` is given by an **inhabitant symbol** `⟦s⟧` whose set is exactly the
  elements of that sort; "`φ` has sort `s`" is `φ → ⟦s⟧`. Sorts are thus patterns too, so
  sorted reasoning needs no separate machinery.

This ladder is why a single uniform logic gives you equality, definedness, membership, and
sorts — the day-to-day vocabulary of the specs in this kit.

## 5. μ: matching μ-logic (induction, recursion, reachability)

Add **set variables** `X` (ranging over subsets of `M`, alongside element variables) and a
**least-fixpoint** binder `μX. φ`, well-formed when `X` occurs **only positively** in `φ`
(under an even number of `¬`). Positivity ⇒ the map `S ↦ |φ|[X := S]` is **monotone** ⇒ by
**Knaster–Tarski** a least fixpoint exists, and `μX. φ` denotes it. The greatest fixpoint
`νX. φ ≡ ¬μX. ¬φ[¬X/X]` is **derived**. Fixpoints are what let you define recursive data
(`μX. nil ∨ (∃Y. cons(Y, X))`, where the `∃Y.` binds the anonymous head element),
inductive predicates, and **reachability** (`◇φ`, "eventually
`φ`") — and they give you **induction** as a proof principle. The Circularity rule used in
this kit's proofs is fixpoint reasoning in disguise; see
[`reachability-and-circularities.md`](reachability-and-circularities.md).

## 6. Proof system (names only)

Sound and (relatively) complete; you don't apply these by hand, but you should recognize
them in a proof:

- **Propositional** tautologies + **Modus Ponens**;
- **∃-quantifier** rules (∃-introduction/elimination) + **Generalization** (the FOL-style
  ∀/universal generalization, here over patterns);
- **Frame** (propagate a proof under a symbol context) and **Propagation** (push
  connectives through application — e.g. `σ(φ₁ ∨ φ₂) = σ(φ₁) ∨ σ(φ₂)`, `σ(⊥) = ⊥`);
- **Pre-Fixpoint** (`φ[μX.φ / X] → μX.φ`) + **Knaster–Tarski** (`φ[ψ/X] → ψ ⊢ μX.φ → ψ`),
  which together give **induction**.

## 7. What it unifies (as THEORIES, not logic extensions)

The leverage: you don't *extend* matching logic to get other logics — you write them down
as ordinary **theories** (sets of axioms/symbols) inside the *same* logic. Captured this
way: **FOL (and FOL+LFP)**; **modal and temporal logics** (`◇`/`□` as symbols, `LTL`/`CTL`
operators as fixpoints); **separation logic** (`*` and `−*` as symbols over a heap model,
recursive heap predicates via `μ`); **reachability logic** (`φ ⇒ φ'` rules — the basis of
this kit's proofs); and **λ-calculus / type systems** (binders and typing judgments). One
logic, many theories — that is the unification claim.

## 8. Why it matters for K (and for this kit)

K is matching logic made executable. A K **configuration** is a pattern (cells are
symbols); a K **claim** `<k> LHS => RHS …</k> requires P ensures Q` is a **reachability
formula** between two patterns; and the prover's output speaks in matching-logic
connectives:

- `#And` = `∧`, `#Or` = `∨`, `#Not` = `¬`, `#Exists` = `∃`, `#Equals` = the derived `=`
  (two-valued, §4), `#Top` = `⊤` (the pattern that is always valid; it is the prover's
  *success token* — when `kprove` reduces a goal to `#Top`, that obligation is discharged;
  see the `sum` example's `PROOF.md` for where it appears).

So when `/verify` constructs a proof and emits `#Equals`/`#And` side conditions, those are
matching-logic patterns, and a side condition that proves to `#Top` is a fully matched
(discharged) obligation. Reading a K spec *is* reading matching logic.

## LIMITS + ESCALATION

This primer is a **fast path** distilled for the common case (arithmetic + maps + a loop,
as in the `sum` example). It is deliberately incomplete. **Escalate to the papers via
[`sources.md`](sources.md)** — and use `/verify --refresh` to pull live sources — when you
hit:

- **Separation logic with recursive predicates** (linked lists, trees, frame inference) —
  needs the heap-model theory and `μ`-defined predicates in full;
- **Binders** (`λ`, quantifier-heavy or substitution-heavy languages) — see the
  *General Approach to Define Binders* work;
- **Concurrency / full temporal reasoning** beyond simple reachability;
- **Full metatheory** — soundness/completeness of the proof system, all-path vs one-path
  reachability, initial-algebra semantics.

When a clean spec is *hard to write*, that difficulty is itself a signal: either the code
has a missing precondition / corner case (report it — that's a found bug), or the case is
genuinely beyond this primer (escalate). Don't invent matching-logic features to force it.

## See also

- [`reachability-and-circularities.md`](reachability-and-circularities.md) — the reachability
  rules and the Circularity rule, i.e. how these patterns become a *proof*.
- [`sources.md`](sources.md) — citations: the LMCS 2017 foundational paper, Matching
  μ-Logic (LICS 2019), reachability logic, binders, and the K docs / Lesson 1.22.
