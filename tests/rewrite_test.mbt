///|
test "strength reduction and cancellation" {
  let nonzero : @egg.Analysis[String, Bool] = Analysis(
    make=fn(op, children) {
      guard children.is_empty() else { return false }
      try @string.parse_bigint(op, radix=10) catch {
        _ => false
      } noraise {
        integer => !integer.is_zero()
      }
    },
    join=(left, right) => left || right,
  )
  let graph = @egg.EGraph::with_analysis(nonzero)
  let root = graph.add(@egg.Expr::parse("(/ (* a 2) 2)"))
  let seven_over_seven = graph.add(@egg.Expr::parse("(/ 7 7)"))
  let zero_over_zero = graph.add(@egg.Expr::parse("(/ 0 0)"))
  let unknown_over_unknown = graph.add(@egg.Expr::parse("(/ a a)"))
  let one = graph.add_node("1")
  let rules = [
    @egg.Rewrite("shift", Pattern("(* ?x 2)"), Pattern("(<< ?x 1)")),
    Rewrite(
      "reassociate division",
      Pattern("(/ (* ?x ?y) ?z)"),
      Pattern("(* ?x (/ ?y ?z))"),
    ),
    Rewrite("divide nonzero by itself", Pattern("(/ ?x ?x)"), Pattern("1"), condition=fn(
      found,
      read,
    ) {
      guard found.get("?x") is Some(id) else { return false }
      read(id)
    }),
    Rewrite("multiply by one", Pattern("(* ?x 1)"), Pattern("?x")),
  ]
  let run = graph.run(rules)
  assert_eq(run.reason, Saturated)
  assert_true(graph.equivalent(seven_over_seven, one))
  assert_false(graph.equivalent(zero_over_zero, one))
  assert_false(graph.equivalent(unknown_over_unknown, one))
  guard graph.extract(root) is Some(best) else {
    fail("expected a finite term")
  }
  assert_eq(best.expr.to_sexp(), "a")
  assert_eq(best.cost, 1UL)
}
