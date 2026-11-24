///|
test "push a customer filter below an inner join" {
  // Relation facts track output column origins. Predicate facts track references.
  // Bit 0 denotes customers and bit 1 denotes orders.
  let analysis : @egg.Analysis[String, UInt32] = Analysis(
    make=fn(op, children) {
      match (op, children) {
        ("customers" | "region_hk", []) => 1U
        ("orders" | "amount_high", []) => 2U
        ("join_full" | "join_small", [left, right]) => left | right
        ("filter_join" | "filter_customers", [_, columns]) => columns
        _ => 0U
      }
    },
    join=(left, right) => left | right,
  )
  let graph = @egg.EGraph::with_analysis(analysis)
  let root = graph.add(
    @egg.Expr::parse("(filter_join region_hk (join_full customers orders))"),
  )
  let order_filter = graph.add(
    @egg.Expr::parse("(filter_join amount_high (join_full customers orders))"),
  )
  let push_filter = @egg.Rewrite(
    "push filter into left input",
    Pattern("(filter_join ?pred (join_full ?left ?right))"),
    Pattern("(join_small (filter_customers ?pred ?left) ?right)"),
    condition=fn(found, read) {
      guard found.get("?pred") is Some(pred) else { return false }
      guard found.get("?left") is Some(left) else { return false }
      let needed = read(pred)
      needed != 0U && (needed & read(left)) == needed
    },
  )

  ignore(graph.run([push_filter]))
  // Count rows tested by filters and rows used to build the hash table.
  let weight = op => {
    match op {
      "filter_join" => 5_000_000UL
      "filter_customers" => 1_000_000UL
      "join_full" => 1_000_000UL
      "join_small" => 10_000UL
      _ => 0UL
    }
  }
  let best = graph.extract(root, weight~)
  assert_eq(
    best.map(term => (term.expr.to_sexp(), term.cost)),
    Some(
      (
        "(join_small (filter_customers region_hk customers) orders)", 1_010_000UL,
      ),
    ),
  )
  assert_eq(
    graph.extract(order_filter, weight~).map(term => term.expr.to_sexp()),
    Some("(filter_join amount_high (join_full customers orders))"),
  )
}
