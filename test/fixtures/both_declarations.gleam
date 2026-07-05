import gleam/option.{type Option, None, Some}

pub type BothDeclarations(bar) {
  BothDeclarations(foo: String, bar: Option(String))
}

pub type NoBar

pub type HasBar

pub fn new(foo: String) -> BothDeclarations(NoBar) {
  BothDeclarations(foo:, bar: None)
}

pub fn with_bar(
  both_declarations: BothDeclarations(NoBar),
  bar: String,
) -> BothDeclarations(HasBar) {
  BothDeclarations(..both_declarations, bar: Some(bar))
}

pub fn to_string(both_declarations: BothDeclarations(bar)) -> String {
  let bar = case both_declarations.bar {
    Some(slot) -> slot
    None -> ""
  }

  "
<div>
    " <> both_declarations.foo <> "
    " <> bar <> "
</div>"
}
