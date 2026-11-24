///|
/// An e-class analysis computes a fact for each node and joins facts in each
/// equivalence class. The optional modify function supplies an equivalent term.
struct Analysis[Op, Data] {
  make : (Op, ReadOnlyArray[Data]) -> Data
  join : (Data, Data) -> Data
  modify : ((Data) -> Expr[Op]?)?
}

///|
/// Use a monotone make and an associative, commutative, idempotent join.
/// Modify must be idempotent at a fixed fact and the analysis must converge.
#alias(new)
pub fn[Op, Data] Analysis::Analysis(
  make~ : (Op, ReadOnlyArray[Data]) -> Data,
  join~ : (Data, Data) -> Data,
  modify? : (Data) -> Expr[Op]?,
) -> Analysis[Op, Data] {
  { make, join, modify, }
}
