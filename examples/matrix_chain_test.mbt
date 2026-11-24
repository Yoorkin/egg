///|
test "matrix chain chooses the least work" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let weights : Map[String, UInt64] = Map([])
  let mul = fn(rows : UInt64, inner : UInt64, cols : UInt64) {
    let op = "m\{rows}x\{inner}x\{cols}"
    weights[op] = rows * inner * cols
    op
  }

  // A, B, C, and D have shapes 10×100, 100×5, 5×50, and 50×2.
  let ab = mul(10UL, 100UL, 5UL)
  let abc = mul(10UL, 5UL, 50UL)
  let abcd = mul(10UL, 50UL, 2UL)
  let root = graph.add(@egg.Expr::parse("(\{abcd} (\{abc} (\{ab} A B) C) D)"))

  // Each tuple gives the four boundary dimensions of three consecutive subchains.
  let rotations = [
    (10UL, 100UL, 5UL, 50UL),
    (10UL, 100UL, 5UL, 2UL),
    (10UL, 100UL, 50UL, 2UL),
    (10UL, 5UL, 50UL, 2UL),
    (100UL, 5UL, 50UL, 2UL),
  ]
  let rules : Array[@egg.Rewrite[String, Unit]] = []
  for (m, k, p, n) in rotations {
    let xy = mul(m, k, p)
    let xy_z = mul(m, p, n)
    let yz = mul(k, p, n)
    let x_yz = mul(m, k, n)
    rules.push(
      Rewrite(
        "associate-\{m}-\{k}-\{p}-\{n}",
        Pattern("(\{xy_z} (\{xy} ?x ?y) ?z)"),
        Pattern("(\{x_yz} ?x (\{yz} ?y ?z))"),
      ),
    )
  }

  ignore(graph.run(rules))
  let best = graph.extract(root, weight=op => weights.get_or_default(op, 0UL))
  assert_eq(
    best.map(term => (term.expr.to_sexp(), term.cost)),
    Some(("(m10x100x2 A (m100x5x2 B (m5x50x2 C D)))", 3500UL)),
  )
}
