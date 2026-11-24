///|
#derive(Eq, Debug)
pub(all) enum StopReason {
  Saturated
  IterationLimit
  NodeLimit
}

///|
#derive(Eq, Debug)
pub struct RunResult {
  iterations : Int32
  reason : StopReason
}

///|
/// Search every rule on a stable graph, apply the matches, then rebuild once
/// per round. Check the node threshold after each rewrite and rebuild.
pub fn[Op : Hash + Eq, Data : Eq] EGraph::run(
  self : EGraph[Op, Data],
  rules : ArrayView[Rewrite[Op, Data]],
  iteration_limit~ : Int32 = 30,
  node_limit~ : Int32 = 10_000,
) -> RunResult {
  self.rebuild()
  if self.node_count() >= node_limit {
    return { iterations: 0, reason: NodeLimit, }
  }
  for iteration in 0..<iteration_limit {
    let matches : Array[(Pattern[Op], Match)] = []
    let read_data = id => self.data(id)
    for rule in rules {
      rule.lhs.visit_matches(self, fn(found) {
        if rule.condition is Some(condition) && !condition(found, read_data) {
          return
        }
        matches.push((rule.rhs, found))
      })
    }
    let old_entries = self.graph.allocated_node_count()
    let old_classes = self.class_count()
    let mut reached_limit = false
    for (rhs, found) in matches {
      let result = instantiate(rhs.tree, self, found)
      ignore(self.merge(found.eclass, result))
      if self.node_count() >= node_limit {
        reached_limit = true
        break
      }
    }
    self.rebuild()
    let iterations = iteration + 1
    if reached_limit || self.node_count() >= node_limit {
      return { iterations, reason: NodeLimit, }
    }
    if self.graph.allocated_node_count() == old_entries &&
      self.class_count() == old_classes {
      return { iterations, reason: Saturated, }
    }
  }
  { iterations: iteration_limit.max(0), reason: IterationLimit, }
}
