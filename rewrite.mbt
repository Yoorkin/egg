///|
#derive(Eq, Debug)
pub(all) suberror RewriteError {
  UnboundVariable(String)
}

///|
/// A directed rule that adds an equivalent expression for each match.
struct Rewrite[Op, Data] {
  name : String
  lhs : Pattern[Op]
  rhs : Pattern[Op]
  condition : ((Match, (Id) -> Data) -> Bool)?
}

///|
/// Every right-hand variable must occur on the left. The optional condition
/// reads analysis facts from the graph at the start of the saturation round.
#alias(new)
pub fn[Op, Data] Rewrite::Rewrite(
  name : String,
  lhs : Pattern[Op],
  rhs : Pattern[Op],
  condition? : (Match, (Id) -> Data) -> Bool,
) -> Rewrite[Op, Data] raise RewriteError {
  let vars : Map[String, Unit] = Map([])
  visit_vars(lhs.tree, name => vars[name] = ())
  let mut missing = None
  visit_vars(rhs.tree, fn(name) {
    if missing is None && !vars.contains(name) {
      missing = Some(name)
    }
  })
  if missing is Some(name) {
    raise UnboundVariable(name)
  }
  { name, lhs, rhs, condition, }
}

///|
pub fn[Op, Data] Rewrite::name(self : Rewrite[Op, Data]) -> String {
  self.name
}
