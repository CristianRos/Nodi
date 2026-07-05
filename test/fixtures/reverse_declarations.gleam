import gleam/option.{type Option, None, Some}

pub type ReverseDeclarations(bar) {
  ReverseDeclarations(foo: String, bar: Option(String))
}

pub type NoBar

pub type HasBar

pub fn new(foo: String) -> ReverseDeclarations(NoBar) {
  ReverseDeclarations(foo:, bar: None)
}

pub fn with_bar(
  reverse_declarations: ReverseDeclarations(NoBar),
  bar: String,
) -> ReverseDeclarations(HasBar) {
  ReverseDeclarations(..reverse_declarations, bar: Some(bar))
}

pub fn to_string(reverse_declarations: ReverseDeclarations(bar)) -> String {
  let bar = case reverse_declarations.bar {
    Some(slot) -> slot
    None -> ""
  }

  "
<div>
    " <> reverse_declarations.foo <> "
    " <> bar <> "
</div>"
}
