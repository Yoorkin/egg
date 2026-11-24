///|
/// A finite expression over a caller-defined set of operators.
#derive(Eq, Debug)
struct Expr[Op] {
  op : Op
  children : ReadOnlyArray[Expr[Op]]
}

///|
#alias(new)
pub fn[Op] Expr::Expr(
  op : Op,
  children~ : ArrayView[Expr[Op]] = [],
) -> Expr[Op] {
  { op, children: ReadOnlyArray::from_array(children), }
}

///|
pub fn[Op] Expr::op(self : Expr[Op]) -> Op {
  self.op
}

///|
pub fn[Op] Expr::children(self : Expr[Op]) -> ReadOnlyArray[Expr[Op]] {
  self.children
}

///|
/// The position is a zero-based offset in Unicode code points.
#derive(Eq, Debug)
pub(all) suberror ParseError {
  InvalidSyntax(position~ : Int32, String)
}

///|
fn[T] parse_sexp(
  input : String,
  build : (@sexp.Symbol, ArrayView[T]) -> T,
) -> T raise ParseError {
  match @sexp.parse(input, build) {
    Ok(value) => value
    Err((position, message)) => raise InvalidSyntax(position~, message)
  }
}

///|
/// Parse a single expression in prefix S-expression notation.
pub fn Expr::parse(input : String) -> Expr[String] raise ParseError {
  parse_sexp(input, (op, children) => Expr(op.text, children~))
}

///|
fn write_expr(out : StringBuilder, expr : Expr[String]) -> Unit {
  if expr.children.is_empty() {
    @sexp.write_symbol(out, expr.op)
  } else {
    out.write_char('(')
    @sexp.write_symbol(out, expr.op)
    for child in expr.children {
      out.write_char(' ')
      write_expr(out, child)
    }
    out.write_char(')')
  }
}

///|
/// Render a string expression in S-expression notation.
pub fn Expr::to_sexp(self : Expr[String]) -> String {
  let out = StringBuilder()
  write_expr(out, self)
  out.to_string()
}
