# Matching Logic — a primer for the agent

The fast path: enough matching logic to read, write, and trust this kit's specs and proofs. For the common case (a function over arithmetic, maps, and a loop — the `sum` example) this is all you need. For deep cases, see **LIMITS + ESCALATION** at the bottom and route to [`sources.md`](sources.md).

The single idea: **one logic for both terms and formulas, because a pattern denotes a set.** That is why K writes a program configuration and a logical constraint in the *same* formula, and why `#And`/`#Or`/`#Equals`/`#Not`/`#Exists` in a K claim are literally matching-logic connectives.

## 1. Patterns are sets

Fix a carrier set `M` (the model). Every **pattern** `φ` denotes a **subset** `|φ| ⊆ M` — the elements that match it. A term (`5`, `cons(x, xs)`) is a pattern whose set is a singleton (or empty, for a partial application). A formula (`x = 5`) is a pattern whose set is `M` (true everywhere) or `∅` (false). Terms and formulas are the same kind of object; they differ only in *how big* their set is. That collapse unifies "structure" (terms) and "constraints" (formulas).

## 2. Connectives are set operations

The connectives are Boolean algebra on subsets of `M`:

| pattern | as a set |
| --- | --- |
| `⊥` / `⊤` | `∅` / `M` |
| `φ₁ ∧ φ₂` / `φ₁ ∨ φ₂` | `|φ₁| ∩ |φ₂|` / `|φ₁| ∪ |φ₂|` |
| `¬φ` | `M \ |φ|` |
| `∃x. φ` | union over all witnesses for `x` |
| `φ₁ → φ₂` | `(M \ |φ₁|) ∪ |φ₂|` |

A pattern is **valid** iff its set is all of `M`. Because `∃` is *union over witnesses*, it mixes freely with structure: `∃x. cons(x, nil)` is "all one-element lists" (lowercase `x` is an element variable; capitals are the set variables of §5). `∀x. φ ≡ ¬∃x. ¬φ`.

## 3. Symbols, application, functions

A **symbol** is interpreted as a relation lifted to the powerset, with **pointwise application**: `|σ(φ)| = ⋃ { |σ|(a) : a ∈ |φ| }`. This one mechanism subsumes the usual cases as *special shapes*, not extra primitives:

- a **function** symbol returns a singleton per argument → ordinary term;
- a **partial function** may return `∅` (undefined) on some inputs → models partiality (e.g. `head(nil)`) with no error value;
- a **relation** returns any subset.

So `+Int`, `<=Int`, `/Int` (truncates toward zero) are total/partial function symbols; `_|->_` and `_[_<-_]` on `MAP` are symbols; a configuration cell is a symbol applied to its contents. All patterns.

## 4. The definedness ladder (everything below is DERIVED)

Matching logic's one extra ingredient beyond FOL syntax is a single **definedness symbol** `⌈_⌉` with the axiom `⌈x⌉ = ⊤` (for a variable `x`). Read `⌈φ⌉` as "`φ` matches *something*": in any model of the axiom, `|⌈φ⌉| = M` when `|φ| ≠ ∅`, else `∅`. From this one symbol the rest is **defined, not assumed**:

- **Totality:** `⌊φ⌋ ≡ ¬⌈¬φ⌉` — "`φ` matches everything."
- **Equality:** `φ₁ = φ₂ ≡ ⌊φ₁ ↔ φ₂⌋`. This is **two-valued** (its set is `M` or `∅`), which plain FOL `↔` *cannot* express: FOL `↔` is true wherever the two agree pointwise but does not say the two *sets are equal*. Matching logic can — and that is what makes `#Equals` in K a real equality.
- **Membership:** `x ∈ φ ≡ ⌈x ∧ φ⌉`.
- **Sorts:** a sort `s` is an **inhabitant symbol** `⟦s⟧` whose set is exactly that sort's elements; "`φ` has sort `s`" is `φ → ⟦s⟧`. Sorts are patterns, so sorted reasoning needs no separate machinery.

This is why one uniform logic gives you equality, definedness, membership, and sorts — the day-to-day vocabulary of this kit's specs.

## 5. μ: matching μ-logic (induction, recursion, reachability)

Add **set variables** `X` (ranging over subsets of `M`, alongside element variables) and a **least-fixpoint** binder `μX. φ`, well-formed when `X` occurs **only positively** in `φ` (under an even number of `¬`). Positivity ⇒ the map `S ↦ |φ|[X := S]` is monotone ⇒ by **Knaster–Tarski** a least fixpoint exists, denoted `μX. φ`. The greatest fixpoint `νX. φ ≡ ¬μX. ¬φ[¬X/X]` is derived. Fixpoints define recursive data (`μX. nil ∨ (∃Y. cons(Y, X))`, where `∃Y.` binds the anonymous head), inductive predicates, and **reachability** (`◇φ`, "eventually `φ`") — and they give **induction** as a proof principle. The Circularity rule in this kit's proofs is fixpoint reasoning in disguise; see [`reachability-and-circularities.md`](reachability-and-circularities.md).

## 6. Proof system (names only)

Sound and (relatively) complete; you won't apply these by hand, but should recognize them in a proof:

- **Propositional** tautologies + **Modus Ponens**;
- **∃-quantifier** rules + **Generalization** (∀/universal generalization over patterns);
- **Frame** (propagate a proof under a symbol context) and **Propagation** (push connectives through application, e.g. `σ(φ₁ ∨ φ₂) = σ(φ₁) ∨ σ(φ₂)`, `σ(⊥) = ⊥`);
- **Pre-Fixpoint** (`φ[μX.φ / X] → μX.φ`) + **Knaster–Tarski** (`φ[ψ/X] → ψ ⊢ μX.φ → ψ`), which together give **induction**.

## 7. What it unifies (as THEORIES, not logic extensions)

You don't *extend* matching logic to get other logics — you write them as ordinary **theories** (axioms/symbols) inside the *same* logic. Captured this way: **FOL (and FOL+LFP)**; **modal and temporal logics** (`◇`/`□` as symbols, LTL/CTL operators as fixpoints); **separation logic** (`*` and `−*` as symbols over a heap model, recursive heap predicates via `μ`); **reachability logic** (`φ ⇒ φ'` rules — the basis of this kit's proofs); **λ-calculus / type systems** (binders, typing judgments). One logic, many theories.

## 8. Why it matters for K (and this kit)

K is matching logic made executable. A K **configuration** is a pattern (cells are symbols); a K **claim** `<k> LHS => RHS …</k> requires P ensures Q` is a **reachability formula** between two patterns; and the prover speaks in matching-logic connectives:

`#And` = `∧`, `#Or` = `∨`, `#Not` = `¬`, `#Exists` = `∃`, `#Equals` = the derived two-valued `=` (§4), `#Top` = `⊤` — the prover's **success token**: when `kprove` reduces a goal to `#Top`, that obligation is discharged (see the `sum` example's `PROOF.md`).

So a `/verify` side condition that proves to `#Top` is a fully matched (discharged) obligation. Reading a K spec *is* reading matching logic.

## LIMITS + ESCALATION

This primer is a fast path for the common case (arithmetic + maps + a loop). It is deliberately incomplete. **Escalate to the papers via [`sources.md`](sources.md)** — and use `/verify --refresh` to pull live sources — when you hit:

- **Separation logic with recursive predicates** (linked lists, trees, frame inference) — needs the heap-model theory and `μ`-defined predicates in full;
- **Binders** (`λ`, quantifier-/substitution-heavy languages) — see the *General Approach to Define Binders* work;
- **Concurrency / full temporal reasoning** beyond simple reachability;
- **Full metatheory** — soundness/completeness, all-path vs one-path reachability, initial-algebra semantics.

When a clean spec is *hard to write*, that difficulty is itself a signal: either the code has a missing precondition / corner case (report it — that's a found bug), or the case is genuinely beyond this primer (escalate). Don't invent matching-logic features to force it.

## See also

- [`reachability-and-circularities.md`](reachability-and-circularities.md) — the reachability rules and the Circularity rule: how these patterns become a *proof*.
- [`sources.md`](sources.md) — citations: the LMCS 2017 foundational paper, Matching μ-Logic (LICS 2019), reachability logic, binders, K docs / Lesson 1.22.
