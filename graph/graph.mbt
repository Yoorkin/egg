///|
/// An e-class identifier issued by one graph. Use it only with that graph.
#derive(Eq, Hash, Debug)
struct Id(Int32)

///|
/// An operator applied to e-classes.
#derive(Eq, Hash, Debug)
pub struct ENode[Op] {
  op : Op
  children : ReadOnlyArray[Id]
}

///|
priv struct EClass[Data] {
  mut leader : Id
  mut size : Int32
  mut data : Data
  nodes : Map[Int32, Unit]
  parents : Map[Int32, Unit]
}

///|
/// Node indices stay stable when a node's children are canonicalized.
priv struct NodeEntry[Op] {
  owner : Id
  mut node : ENode[Op]
  mut live : Bool
}

///|
struct Graph[Op, Data] {
  make : (Op, ReadOnlyArray[Data]) -> Data
  join : (Data, Data) -> Data
  modify : ((Graph[Op, Data], Data) -> Id?)?
  classes : Array[EClass[Data]]
  entries : Array[NodeEntry[Op]]
  memo : Map[ENode[Op], Int32]
  mut repairs : Map[Int32, Unit]
  mut data_updates : Map[Id, Unit]
  mut class_count : Int32
}

///|
/// Create a graph with functions for e-class analysis. Modify may add an
/// equivalent term and return its class for merging during rebuild.
#alias(new)
pub fn[Op : Hash + Eq, Data] Graph::Graph(
  make~ : (Op, ReadOnlyArray[Data]) -> Data,
  join~ : (Data, Data) -> Data,
  modify? : (Graph[Op, Data], Data) -> Id?,
) -> Graph[Op, Data] {
  {
    make,
    join,
    modify,
    classes: [],
    entries: [],
    memo: {},
    repairs: {},
    data_updates: {},
    class_count: 0,
  }
}

///|
/// Find the canonical identifier using path halving.
pub fn[Op, Data] Graph::find(self : Graph[Op, Data], id : Id) -> Id {
  for current = id {
    let entry = self.classes[current.0]
    let parent = entry.leader
    if parent == current {
      break current
    }
    let grandparent = self.classes[parent.0].leader
    entry.leader = grandparent
    continue grandparent
  }
}

///|
pub fn[Op, Data] Graph::class_count(self : Graph[Op, Data]) -> Int32 {
  self.class_count
}

///|
/// Return the number of e-nodes. Rebuild removes any pending duplicates.
pub fn[Op, Data] Graph::node_count(self : Graph[Op, Data]) -> Int32 {
  self.memo.length()
}

///|
/// Read the class's analysis fact. Call rebuild to finish propagating updates.
pub fn[Op, Data] Graph::data(self : Graph[Op, Data], id : Id) -> Data {
  self.classes[self.find(id).0].data
}

///|
/// Count node slots ever allocated, including entries removed by rebuild.
pub fn[Op, Data] Graph::allocated_node_count(self : Graph[Op, Data]) -> Int32 {
  self.entries.length()
}

///|
/// View the nodes of a class. Call rebuild to canonicalize every child.
pub fn[Op, Data] Graph::nodes(
  self : Graph[Op, Data],
  id : Id,
) -> ReadOnlyArray[ENode[Op]] {
  let nodes = self.classes[self.find(id).0].nodes
  ReadOnlyArray::from_array(
    [
      for index, _ in nodes => self.entries[index].node
    ],
  )
}

///|
/// Add an operator applied to existing classes and return its class.
pub fn[Op : Hash + Eq, Data] Graph::add_node(
  self : Graph[Op, Data],
  op : Op,
  children~ : ArrayView[Id] = [],
) -> Id {
  let node : ENode[Op] = {
    op,
    children: ReadOnlyArray::from_array(
      [
        for child in children => self.find(child)
      ],
    ),
  }
  self.insert(node)
}

///|
fn[Op : Hash + Eq, Data] Graph::insert(
  self : Graph[Op, Data],
  node : ENode[Op],
) -> Id {
  if self.memo.get(node) is Some(index) {
    return self.find(self.entries[index].owner)
  }
  let id = Id(self.classes.length())
  let index = self.entries.length()
  let nodes = Map([(index, ())])
  let data = (self.make)(node.op, node.children.map(child => self.data(child)))
  self.classes.push({ leader: id, size: 1, data, nodes, parents: {}, })
  self.entries.push({ owner: id, node, live: true, })
  self.memo[node] = index
  self.class_count += 1
  for child in node.children {
    self.classes[child.0].parents[index] = ()
  }
  if self.modify is Some(_) {
    self.data_updates[id] = ()
  }
  id
}

///|
/// Assert that two classes are equivalent. Return whether the classes merged.
/// Rebuild after a batch of merges to propagate congruence and analysis facts.
pub fn[Op, Data : Eq] Graph::merge(
  self : Graph[Op, Data],
  left : Id,
  right : Id,
) -> Bool {
  let left = self.find(left)
  let right = self.find(right)
  if left == right {
    return false
  }
  let (keep, lose) = if self.classes[left.0].size >= self.classes[right.0].size {
    (left, right)
  } else {
    (right, left)
  }
  let winner = self.classes[keep.0]
  let loser = self.classes[lose.0]
  let joined = (self.join)(winner.data, loser.data)
  if joined != winner.data || joined != loser.data {
    self.data_updates[keep] = ()
  }
  winner.data = joined
  winner.size += loser.size
  loser.leader = keep
  self.class_count -= 1
  for index, _ in loser.nodes {
    winner.nodes[index] = ()
  }
  loser.nodes.clear()
  for index, _ in loser.parents {
    winner.parents[index] = ()
    self.repairs[index] = ()
  }
  loser.parents.clear()
  true
}
