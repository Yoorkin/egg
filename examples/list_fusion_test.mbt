///|
test "fuse a filter and maps into one fold" {
  let graph : @egg.EGraph[String, Unit] = EGraph()
  let sum = graph.add(
    @egg.Expr::parse("(foldl add 0 (map square (map inc (filter even xs))))"),
  )
  let maximum = graph.add(
    @egg.Expr::parse("(foldl max 10 (map abs (filter nonzero ys)))"),
  )

  // The callbacks are closed, pure, and total. Lambda binds acc and item.
  // compose(g, f) applies f first and g second.
  let rules : Array[@egg.Rewrite[String, Unit]] = [
    Rewrite(
      "compose consecutive maps",
      Pattern("(map ?g (map ?f ?xs))"),
      Pattern("(map (compose ?g ?f) ?xs)"),
    ),
    Rewrite(
      "fuse map and filter into fold",
      Pattern("(foldl ?step ?init (map ?f (filter ?pred ?xs)))"),
      Pattern(
        (
          #|(foldl
          #|  (lambda acc item
          #|    (if (apply ?pred item)
          #|        (apply ?step acc (apply ?f item))
          #|        acc))
          #|  ?init ?xs)
        ),
      ),
    ),
  ]

  ignore(graph.run(rules))
  let weight = op => {
    match op {
      "map" | "filter" | "foldl" => 1UL
      _ => 0UL
    }
  }

  let expected_sum = @egg.Expr::parse(
    (
      #|(foldl
      #|  (lambda acc item
      #|    (if (apply even item)
      #|        (apply add acc (apply (compose square inc) item))
      #|        acc))
      #|  0 xs)
    ),
  )
  assert_eq(
    graph.extract(sum, weight~).map(term => (term.expr, term.cost)),
    Some((expected_sum, 1UL)),
  )

  let expected_maximum = @egg.Expr::parse(
    (
      #|(foldl
      #|  (lambda acc item
      #|    (if (apply nonzero item)
      #|        (apply max acc (apply abs item))
      #|        acc))
      #|  10 ys)
    ),
  )
  assert_eq(
    graph.extract(maximum, weight~).map(term => (term.expr, term.cost)),
    Some((expected_maximum, 1UL)),
  )
}
