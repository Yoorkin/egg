///|
#derive(Eq, Hash, Debug)
enum Op {
  Yes
  Unknown
  And
  IsKnown
}

///|
test "analysis propagation enables a conditional rewrite on a custom language" {
  let analysis : @egg.Analysis[Op, Bool] = Analysis(
    make=fn(op, children) {
      match (op, children) {
        (Yes, []) => true
        (And, [left, right]) => left && right
        _ => false
      }
    },
    join=(a, b) => a || b,
  )
  let graph = @egg.EGraph::with_analysis(analysis)
  let yes = graph.add_node(Yes)
  let unknown = graph.add_node(Unknown)
  let inner = graph.add_node(And, children=[unknown, yes])
  let outer = graph.add_node(And, children=[inner, inner])
  let root = graph.add_node(IsKnown, children=[outer])
  let rule = @egg.Rewrite(
    "known",
    @egg.Pattern::node(IsKnown, children=[@egg.Pattern::variable("value")]),
    @egg.Pattern::node(Yes),
    condition=fn(found, read) {
      guard found.get("value") is Some(id) else { return false }
      read(id)
    },
  )
  assert_eq(graph.run([rule]).reason, Saturated)
  assert_false(graph.equivalent(root, yes))
  ignore(graph.merge(unknown, yes))
  // The runner must propagate the child's new fact before searching rules.
  assert_eq(graph.run([rule]).reason, Saturated)
  assert_true(graph.data(outer))
  assert_true(graph.equivalent(root, yes))
}

///|
test "Boolean constant folding" {
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
  assert_false(graph.data(root))
  ignore(graph.merge(a, literal))
  graph.rebuild()
  assert_true(graph.data(root))
  assert_true(graph.equivalent(root, literal))
}
