///|
pub using @graph {type ENode, type Id}

///|
/// An e-graph with an optional e-class analysis.
struct EGraph[Op, Data] {
  graph : @graph.Graph[Op, Data]
}

///|
#alias(new)
pub fn[Op : Hash + Eq] EGraph::EGraph() -> EGraph[Op, Unit] {
  EGraph::with_analysis(Analysis(make=fn(_, _) { () }, join=fn(_, _) { () }))
}

///|
pub fn[Op : Hash + Eq, Data] EGraph::with_analysis(
  analysis : Analysis[Op, Data],
) -> EGraph[Op, Data] {
  let modify = analysis.modify.map(modify => {
    fn(graph, data) { modify(data).map(expr => add_expr(graph, expr)) }
  })
  { graph: Graph(make=analysis.make, join=analysis.join, modify?), }
}

///|
/// Find the canonical identifier using path halving.
pub fn[Op, Data] EGraph::find(self : EGraph[Op, Data], id : Id) -> Id {
  self.graph.find(id)
}

///|
/// Test whether two identifiers belong to the same class. Call rebuild first
/// to account for indirect equalities implied by recent merges.
pub fn[Op, Data] EGraph::equivalent(
  self : EGraph[Op, Data],
  left : Id,
  right : Id,
) -> Bool {
  self.find(left) == self.find(right)
}

///|
pub fn[Op, Data] EGraph::class_count(self : EGraph[Op, Data]) -> Int32 {
  self.graph.class_count()
}

///|
/// Return the number of e-nodes. Rebuild removes any pending duplicates.
pub fn[Op, Data] EGraph::node_count(self : EGraph[Op, Data]) -> Int32 {
  self.graph.node_count()
}

///|
/// Read the class's analysis fact. Call rebuild to finish propagating updates.
pub fn[Op, Data] EGraph::data(self : EGraph[Op, Data], id : Id) -> Data {
  self.graph.data(id)
}

///|
/// View the nodes of a class. Call rebuild to canonicalize every child.
pub fn[Op, Data] EGraph::nodes(
  self : EGraph[Op, Data],
  id : Id,
) -> ReadOnlyArray[ENode[Op]] {
  self.graph.nodes(id)
}

///|
/// Add an operator applied to existing classes and return its class.
pub fn[Op : Hash + Eq, Data] EGraph::add_node(
  self : EGraph[Op, Data],
  op : Op,
  children~ : ArrayView[Id] = [],
) -> Id {
  self.graph.add_node(op, children~)
}

///|
/// Add a finite expression and return its root class.
pub fn[Op : Hash + Eq, Data] EGraph::add(
  self : EGraph[Op, Data],
  expr : Expr[Op],
) -> Id {
  add_expr(self.graph, expr)
}

///|
fn[Op : Hash + Eq, Data] add_expr(
  graph : @graph.Graph[Op, Data],
  expr : Expr[Op],
) -> Id {
  let children = [ for child in expr.children => add_expr(graph, child) ]
  graph.add_node(expr.op, children~)
}

///|
/// Assert that two classes are equivalent. Return whether the classes merged.
/// Rebuild after a batch of merges to propagate congruence and analysis facts.
pub fn[Op, Data : Eq] EGraph::merge(
  self : EGraph[Op, Data],
  left : Id,
  right : Id,
) -> Bool {
  self.graph.merge(left, right)
}

///|
/// Restore congruence and propagate analysis facts to a fixed point.
pub fn[Op : Hash + Eq, Data : Eq] EGraph::rebuild(
  self : EGraph[Op, Data],
) -> Unit {
  self.graph.rebuild()
}
