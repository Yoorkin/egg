///|
#derive(Eq, Debug)
pub struct Extraction[Op] {
  cost : UInt64
  expr : Expr[Op]
}

///|
/// Extract a cheapest finite expression under additive operator weights.
/// The default weight of one minimizes the number of nodes in the expression
/// tree. Weights must be stable. Returns None if the minimum overflows UInt64.
pub fn[Op : Hash + Eq, Data : Eq] EGraph::extract(
  self : EGraph[Op, Data],
  root : Id,
  weight~ : (Op) -> UInt64 = fn(_) { 1UL },
) -> Extraction[Op]? {
  self.graph
  .extract(root, weight, (op, children) => Expr(op, children~))
  .map(fn(result) {
    let (cost, expr) = result
    { cost, expr, }
  })
}

///|
/// Extract a cheapest finite expression using the operator and child costs.
/// The callback receives child costs in operand order for the duration of the call.
/// The cost must be stable, nondecreasing in each child cost, and at least
/// as large as each child cost. Return None for an unrepresentable cost.
pub fn[Op : Hash + Eq, Data : Eq] EGraph::extract_with_cost(
  self : EGraph[Op, Data],
  root : Id,
  cost~ : (Op, ArrayView[UInt64]) -> UInt64?,
) -> Extraction[Op]? {
  self.graph
  .extract_with_cost(root, cost, (op, children) => Expr(op, children~))
  .map(fn(result) {
    let (cost, expr) = result
    { cost, expr, }
  })
}
