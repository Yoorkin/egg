///|
/// A pattern matches operators and binds variables to e-classes.
pub(all) enum Pattern[Op] {
  Variable(String)
  Node(Op, ReadOnlyArray[Pattern[Op]])
}

///|
/// Visit matches on a rebuilt graph.
pub fn[Op : Eq, Data] Pattern::visit_matches(
  self : Pattern[Op],
  graph : Graph[Op, Data],
  visit : (Id, Map[String, Id]) -> Unit,
) -> Unit {
  let bindings : Map[String, Id] = Map([])
  for index, eclass in graph.classes {
    let id = Id(index)
    if eclass.leader == id {
      self.match_at(graph, id, bindings, fn() { visit(id, bindings.copy()) })
    }
  }
}

///|
fn[Op : Eq, Data] Pattern::match_at(
  self : Pattern[Op],
  graph : Graph[Op, Data],
  id : Id,
  bindings : Map[String, Id],
  visit : () -> Unit,
) -> Unit {
  match self {
    Variable(name) =>
      if bindings.get(name) is Some(bound) {
        if bound == id {
          visit()
        }
      } else {
        bindings[name] = id
        visit()
        bindings.remove(name)
      }
    Node(op, children) =>
      for index, _ in graph.classes[id.0].nodes {
        let node = graph.entries[index].node
        if op == node.op && children.length() == node.children.length() {
          match_children(children, node.children, 0, graph, bindings, visit)
        }
      }
  }
}

///|
/// Continue to the next sibling before rolling back this child's bindings.
fn[Op : Eq, Data] match_children(
  patterns : ReadOnlyArray[Pattern[Op]],
  children : ReadOnlyArray[Id],
  index : Int32,
  graph : Graph[Op, Data],
  bindings : Map[String, Id],
  visit : () -> Unit,
) -> Unit {
  if index == patterns.length() {
    visit()
  } else {
    patterns[index].match_at(graph, children[index], bindings, fn() {
      match_children(patterns, children, index + 1, graph, bindings, visit)
    })
  }
}
