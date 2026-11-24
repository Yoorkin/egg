///|
test "one rebuild merges parents and grandparents after several unions" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let x : @egg.Id = graph.add_node("x")
  let y = graph.add_node("y")
  let z = graph.add_node("z")
  let xy = graph.add_node("f", children=[x, y])
  let yz = graph.add_node("f", children=[y, z])
  let gxy = graph.add_node("g", children=[xy])
  let gyz = graph.add_node("g", children=[yz])
  assert_true(graph.merge(x, y))
  assert_true(graph.merge(y, z))
  // The newly inserted form may coexist with dirty keys until the rebuild.
  let xx = graph.add_node("f", children=[x, x])
  graph.rebuild()
  assert_true(graph.equivalent(gxy, gyz))
  assert_true(graph.equivalent(xy, xx))
  assert_true(graph.equivalent(xy, yz))
  assert_false(graph.merge(x, z))
  assert_eq(graph.class_count(), 3)
  assert_eq(graph.node_count(), 5)
  let nodes : ReadOnlyArray[@egg.ENode[String]] = graph.nodes(yz)
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].children, [graph.find(x), graph.find(x)])
  assert_eq(graph.add_node("f", children=[z, y]), graph.find(xy))
  graph.rebuild()
  assert_eq(graph.node_count(), 5)
}

///|
test "matching backtracks across siblings and checks repeated variables" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let a = graph.add_node("a")
  let f_a = graph.add(@egg.Expr::parse("(f a)"))
  let f_b = graph.add(@egg.Expr::parse("(f b)"))
  let root = graph.add(@egg.Expr::parse("(pair (f b) (f a) a)"))
  ignore(graph.merge(f_a, f_b))
  let matches = @egg.Pattern("(pair (f ?x) (f ?x) ?x)").search(graph)
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].get("?x"), Some(a))
  assert_eq(matches[0].get("?other"), None)
  assert_eq(matches[0].eclass, graph.find(root))
  assert_eq(@egg.Pattern("(pair ?x ?y)").search(graph).length(), 0)
}

///|
test "the runner matches each round against a stable graph" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let root = graph.add(@egg.Expr::parse("(f x)"))
  let rules = [
    @egg.Rewrite("f to g", Pattern("(f ?x)"), Pattern("(g ?x)")),
    Rewrite("g to atom", Pattern("(g ?x)"), Pattern("?x")),
  ]
  let first = graph.run(rules, iteration_limit=1)
  assert_eq(first.reason, IterationLimit)
  assert_eq(first.iterations, 1)
  let x = graph.add_node("x")
  assert_false(graph.equivalent(root, x))
  let second = graph.run(rules)
  assert_eq(second.reason, Saturated)
  assert_true(graph.equivalent(root, x))
}

///|
test "an expansive rule stops at the node limit with a usable graph" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let root = graph.add(@egg.Expr::parse("(f x)"))
  let rule = @egg.Rewrite("grow", Pattern("(f ?x)"), Pattern("(f (g ?x))"))
  let result = graph.run([rule], node_limit=6)
  assert_eq(result.reason, NodeLimit)
  assert_eq(result.iterations, 2)
  guard graph.extract(root) is Some(best) else { fail("expected finite term") }
  assert_eq(best.expr.to_sexp(), "(f x)")
  assert_eq(best.cost, 2UL)
}

///|
test "weighted extraction handles sharing, zero-weight cycles and overflow" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let x = graph.add_node("x")
  let pair = graph.add_node("pair", children=[x, x])
  let expensive = graph.add_node("expensive")
  let cycle = graph.add_node("cycle", children=[pair])
  ignore(graph.merge(pair, expensive))
  ignore(graph.merge(pair, cycle))
  guard graph.extract(pair) is Some(smallest) else {
    fail("expected a finite term")
  }
  assert_eq(smallest.expr.to_sexp(), "expensive")
  guard graph.extract(pair, weight=op => {
      if op == "expensive" {
        10UL
      } else {
        0UL
      }
    })
    is Some(cheapest) else {
    fail("expected a finite term")
  }
  assert_eq(cheapest.cost, 0UL)
  assert_eq(cheapest.expr.to_sexp(), "(pair x x)")
  let only_pair = graph.add_node("only-pair", children=[x, x])
  assert_eq(graph.extract(only_pair, weight=_ => 0xffffffffffffffffUL), None)
  guard graph.extract(x, weight=_ => 0xffffffffffffffffUL) is Some(leaf) else {
    fail("expected a representable maximum cost")
  }
  assert_eq(leaf.cost, 0xffffffffffffffffUL)
}

///|
test "rewrite construction reports an unbound variable" {
  let lhs = @egg.Pattern("(f ?x)")
  let rhs = @egg.Pattern("(g ?y)")
  try (Rewrite("invalid", lhs, rhs) : @egg.Rewrite[String, Unit]) catch {
    UnboundVariable(name) => assert_eq(name, "?y")
  } noraise {
    _ => fail("expected an unbound variable error")
  }
}

///|
test "S-expressions handle Unicode and quoted symbols" {
  let expr = @egg.Expr("⊕", children=[
    Expr("🍳"),
    Expr("a ) \" \\ \n"),
    Expr(""),
  ])
  assert_eq(@egg.Expr::parse(expr.to_sexp()), expr)
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let literal = graph.add_node("?x")
  let bare_question = graph.add_node("?")
  ignore(graph.add_node("y"))
  let matches = @egg.Pattern("\"?x\"").search(graph)
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].eclass, literal)
  let bare_matches = @egg.Pattern("?").search(graph)
  assert_eq(bare_matches.length(), 1)
  assert_eq(bare_matches[0].eclass, bare_question)
  assert_eq(@egg.Pattern("?🍳").search(graph).length(), graph.class_count())
  for input in ["", "()", "(f", "x y", "(f a\"b\")", "\"\\q\""] {
    try @egg.Expr::parse(input) catch {
      InvalidSyntax(_, ..) => ()
    } noraise {
      _ => fail("expected a parse error for \{input}")
    }
  }
}
