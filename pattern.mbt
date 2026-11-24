///|
/// A pattern matches operators and binds variables to e-classes.
struct Pattern[Op] {
  tree : @graph.Pattern[Op]
}

///|
pub fn[Op] Pattern::variable(name : String) -> Pattern[Op] {
  { tree: Variable(name), }
}

///|
pub fn[Op] Pattern::node(
  op : Op,
  children~ : ArrayView[Pattern[Op]] = [],
) -> Pattern[Op] {
  {
    tree: Node(
      op,
      ReadOnlyArray::from_array([ for child in children => child.tree ]),
    ),
  }
}

///|
pub struct Match {
  eclass : Id
  priv bindings : Map[String, Id]
}

///|
/// Read the class bound to a variable by name.
pub fn Match::get(self : Match, name : String) -> Id? {
  self.bindings.get(name)
}

///|
/// Search all classes after rebuilding the graph.
pub fn[Op : Hash + Eq, Data : Eq] Pattern::search(
  self : Pattern[Op],
  graph : EGraph[Op, Data],
) -> Array[Match] {
  graph.rebuild()
  let matches = []
  self.visit_matches(graph, found => matches.push(found))
  matches
}

///|
fn[Op : Eq, Data] Pattern::visit_matches(
  self : Pattern[Op],
  graph : EGraph[Op, Data],
  visit : (Match) -> Unit,
) -> Unit {
  self.tree.visit_matches(graph.graph, fn(eclass, bindings) {
    visit({ eclass, bindings, })
  })
}

///|
fn[Op] visit_vars(
  pattern : @graph.Pattern[Op],
  visit : (String) -> Unit,
) -> Unit {
  match pattern {
    Variable(name) => visit(name)
    Node(_, children) =>
      for child in children {
        visit_vars(child, visit)
      }
  }
}

///|
fn[Op : Hash + Eq, Data] instantiate(
  pattern : @graph.Pattern[Op],
  graph : EGraph[Op, Data],
  found : Match,
) -> Id {
  match pattern {
    Variable(name) => found.bindings[name]
    Node(op, children) => {
      let children = [
        for child in children => instantiate(child, graph, found)
      ]
      graph.add_node(op, children~)
    }
  }
}

///|
/// Parse a pattern. An unquoted leaf such as ?x binds that exact variable name.
pub fn Pattern::Pattern(input : String) -> Pattern[String] raise ParseError {
  parse_sexp(input, fn(op, children) {
    let text = op.text
    if !op.quoted && children.is_empty() && text is ['?', _, ..] {
      Pattern::variable(text)
    } else {
      Pattern::node(text, children~)
    }
  })
}
