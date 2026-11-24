///|
/// Restore congruence and propagate analysis facts to a fixed point.
pub fn[Op : Hash + Eq, Data : Eq] Graph::rebuild(
  self : Graph[Op, Data],
) -> Unit {
  while self.repairs.length() > 0 || self.data_updates.length() > 0 {
    // Merges discovered during repair may create another batch.
    while self.repairs.length() > 0 {
      let batch = self.repairs
      self.repairs = {}
      for index, _ in batch {
        self.repair(index)
      }
    }
    if self.data_updates.length() > 0 {
      self.propagate_analysis()
    }
  }
}

///|
fn[Op : Hash + Eq, Data : Eq] Graph::repair(
  self : Graph[Op, Data],
  index : Int32,
) -> Unit {
  let entry = self.entries[index]
  guard entry.live else { return }
  let old = entry.node
  let canonical = {
    ..old,
    children: old.children.map(child => self.find(child)),
  }
  guard old != canonical else { return }
  self.memo.remove(old)
  if self.memo.get(canonical) is Some(other) {
    // Every canonical child already received the losing class's parent links.
    for child in canonical.children {
      self.classes[child.0].parents.remove(index)
    }
    self.classes[self.find(entry.owner).0].nodes.remove(index)
    entry.live = false
    ignore(self.merge(entry.owner, self.entries[other].owner))
  } else {
    entry.node = canonical
    self.memo[canonical] = index
  }
}

///|
fn[Op, Data : Eq] Graph::propagate_analysis(self : Graph[Op, Data]) -> Unit {
  let pending = self.data_updates
  self.data_updates = {}
  let classes : Map[Id, Unit] = Map([])
  let parents : Map[Int32, Unit] = Map([])
  for id, _ in pending {
    let id = self.find(id)
    classes[id] = ()
  }
  for id, _ in classes {
    for index, _ in self.classes[id.0].parents {
      parents[index] = ()
    }
  }
  for index, _ in parents {
    let entry = self.entries[index]
    let id = self.find(entry.owner)
    let eclass = self.classes[id.0]
    let node = entry.node
    let made = (self.make)(
      node.op,
      node.children.map(child => self.data(child)),
    )
    let joined = (self.join)(eclass.data, made)
    if joined != eclass.data {
      eclass.data = joined
      self.data_updates[id] = ()
    }
  }
  if self.modify is Some(modify) {
    for id, _ in classes {
      if modify(self, self.data(id)) is Some(equivalent) {
        ignore(self.merge(id, equivalent))
      }
    }
  }
}
