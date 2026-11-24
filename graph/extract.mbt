///|
/// Rebuild the graph and extract a cheapest finite tree.
pub fn[Op : Hash + Eq, Data : Eq, Tree] Graph::extract(
  self : Graph[Op, Data],
  root : Id,
  weight : (Op) -> UInt64,
  build : (Op, ArrayView[Tree]) -> Tree,
) -> (UInt64, Tree)? {
  self.extract_with_cost(
    root,
    fn(op, child_costs) {
      let mut cost = weight(op)
      for child_cost in child_costs {
        let total = cost + child_cost
        if total < cost {
          return None
        }
        cost = total
      }
      Some(cost)
    },
    build,
  )
}

///|
/// Rebuild the graph and extract a cheapest finite tree under a local cost.
pub fn[Op : Hash + Eq, Data : Eq, Tree] Graph::extract_with_cost(
  self : Graph[Op, Data],
  root : Id,
  local_cost : (Op, ArrayView[UInt64]) -> UInt64?,
  build : (Op, ArrayView[Tree]) -> Tree,
) -> (UInt64, Tree)? {
  self.rebuild()
  let best : Array[(UInt64, Tree)?] = Array::make(self.classes.length(), None)
  let child_costs : Array[UInt64] = []
  // Each candidate uses finite child expressions already found in prior steps.
  // Accepting only strict improvements also handles cycles of weight zero.
  for ;; {
    let mut changed = false
    for index, eclass in self.classes {
      guard eclass.leader == Id(index) else { continue }
      for node_index, _ in eclass.nodes {
        let node = self.entries[node_index].node
        child_costs.clear()
        for child in node.children {
          guard best[child.0] is Some((child_cost, _)) else { break }
          child_costs.push(child_cost)
        }
        guard child_costs.length() == node.children.length() else { continue }
        guard local_cost(node.op, child_costs) is Some(cost) else { continue }
        if best[index] is None ||
          (best[index] is Some((old_cost, _)) && cost < old_cost) {
          // The complete cost list guarantees that each child has a tree.
          let children = node.children.filter_map(child => {
            best[child.0].map(result => result.1)
          })
          best[index] = Some((cost, build(node.op, children)))
          changed = true
        }
      }
    }
    if !changed {
      break best[self.find(root).0]
    }
  }
}
