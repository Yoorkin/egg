# egg for MoonBit

A small equality saturation library based on [egg: Fast and Extensible Equality Saturation](https://arxiv.org/abs/2004.03082). An e-graph stores equivalent expressions in e-classes. Rewrites add alternatives, and extraction picks an inexpensive expression from the resulting graph.

## Simplify an expression

In the paper's Figure 2, rewriting `(* a 2)` as a shift can hide the opportunity to cancel the division. Both forms remain available in the e-graph, so the cancellation can still produce `a`. The rule `(/ ?x ?x) → 1` uses `moonbitlang/core/string` to recognize nonzero integer literals.

```moonbit check
///|
test {
  let nonzero : @egg.Analysis[String, Bool] = Analysis(
    make=fn(op, children) {
      guard children.is_empty() else { return false }
      let integer = @string.parse_bigint(op, radix=10) catch {
        _ => return false
      }
      !integer.is_zero()
    },
    join=(left, right) => left || right,
  )

  let graph = @egg.EGraph::with_analysis(nonzero)
  let root = graph.add(@egg.Expr::parse("(/ (* a 2) 2)"))

  let rules = [
    @egg.Rewrite(
      "shift",
      @egg.Pattern::parse("(* ?x 2)"),
      @egg.Pattern::parse("(<< ?x 1)"),
    ),
    Rewrite(
      "reassociate division",
      @egg.Pattern::parse("(/ (* ?x ?y) ?z)"),
      @egg.Pattern::parse("(* ?x (/ ?y ?z))"),
    ),
    Rewrite(
      "divide nonzero by itself",
      @egg.Pattern::parse("(/ ?x ?x)"),
      @egg.Pattern::parse("1"),
      condition=fn(found, read) {
        guard found.get("?x") is Some(id) else { return false }
        read(id)
      },
    ),
    Rewrite(
      "multiply by one",
      @egg.Pattern::parse("(* ?x 1)"),
      @egg.Pattern::parse("?x"),
    ),
  ]

  ignore(graph.run(rules))
  assert_eq(graph.extract(root).map(best => best.expr.to_sexp()), Some("a"))
}
```

These rules use the algebra in Figure 2. Choose rules that preserve equality in your expression language. String operators support prefix S-expressions and double-quoted symbols. An unquoted leaf beginning with `?` and followed by a name is a pattern variable. Use `Expr(...)`, `Pattern::node`, and `Pattern::variable` for operators of any type implementing `Eq` and `Hash`. Keep their equality and hash stable after insertion.

## Fold constants with an e-class analysis

The analysis interface follows Section 4 of the paper. This example tracks whether an e-class denotes Boolean `true`. Its `make` computes that fact from a node and its child facts. The `join` takes the logical OR of facts from equivalent nodes. When a class is known to be true, `modify` adds the literal `true` to it.

```moonbit check
///|
pub fn fold_boolean_constants() -> Bool raise @egg.ParseError {
  let analysis : @egg.Analysis[String, Bool] = Analysis(
    make=fn(op, children) {
      match (op, children) {
        ("true", []) => true
        ("and", [left, right]) => left && right
        _ => false
      }
    },
    join=(left, right) => left || right,
    modify=known => if known { Some(Expr("true")) } else { None },
  )

  let graph = @egg.EGraph::with_analysis(analysis)
  let root = graph.add(@egg.Expr::parse("(and a (and true true))"))

  let a = graph.add_node("a")
  let literal = graph.add_node("true")
  let _ = graph.merge(a, literal)

  graph.rebuild()
  graph.data(root)
}
```

After the merge and rebuild, `fold_boolean_constants()` returns `true`.

Use an associative, commutative, idempotent `join` and a monotone `make`. The term returned by `modify` must be equivalent to its class. Use immutable facts and ensure the analysis reaches a fixed point. To read facts during matching, pass a `condition` to `Rewrite(...)`. It receives the match and a function that reads an e-class's fact.

## Rebuilding and extraction

- `add` interns nodes by operator and child class IDs. `merge` unions two classes and queues parent nodes whose child IDs may have changed. `rebuild` repairs those nodes in batches and propagates analysis facts until both worklists empty.
- Pass IDs back to the graph that issued them. After manual merges, call `rebuild` before reading transitive congruence or final analysis facts. `Pattern::search`, `EGraph::run`, and `EGraph::extract` rebuild automatically.
- Each round of `run` searches all rules on a stable graph, applies their matches, then rebuilds. It reports saturation, the iteration limit, or the node limit. The node limit is a threshold checked between complete rewrites and rebuilds, so one rewrite or analysis pass can overshoot it.
- `extract` minimizes the sum of operator weights in the expression tree. The default weight is one. Pass a stable `weight` function for a custom cost. The result is `None` if the minimum cost exceeds `UInt64`.

### Extract a balanced sum

Associativity makes a balanced sum available in the graph. Use `extract_with_cost` to minimize tree depth by adding one to the largest child cost.

```moonbit check
///|
test {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let root = graph.add(@egg.Expr::parse("(+ (+ (+ a b) c) d)"))
  let associate = @egg.Rewrite(
    "associate addition to the right",
    @egg.Pattern::parse("(+ (+ ?x ?y) ?z)"),
    @egg.Pattern::parse("(+ ?x (+ ?y ?z))"),
  )
  ignore(graph.run([associate]))
  let best = graph.extract_with_cost(root, cost=(_, children) => {
    Some(1UL + children.fold(init=0UL, UInt64::max))
  })
  assert_eq(best.map(term => term.expr.to_sexp()), Some("(+ (+ a b) (+ c d))"))
}
```

Use `moon check` to check the examples and `moon test` to run the library tests.

## Package layout

- `Yoorkin/egg` is the application entry point. It owns expressions, patterns, rewrite rules, and the saturation runner.
- `Yoorkin/egg/graph` holds e-classes, congruence rebuilding, analysis propagation, e-matching, and the cost search used by extraction.
- `internal/sexp` implements the shared S-expression syntax. Integration tests live in `tests/` and import the root package.
