import gleam/option.{type Option, None, Some}

pub type TwoOptionals(foo, bar) {
  TwoOptionals(foo: Option(String), bar: Option(String))
}

pub type NoFoo

pub type HasFoo

pub type NoBar

pub type HasBar

pub fn new() -> TwoOptionals(NoFoo, NoBar) {
  TwoOptionals(foo: None, bar: None)
}

pub fn with_foo(
  two_optionals: TwoOptionals(NoFoo, bar),
  foo: String,
) -> TwoOptionals(HasFoo, bar) {
  TwoOptionals(..two_optionals, foo: Some(foo))
}

pub fn with_bar(
  two_optionals: TwoOptionals(foo, NoBar),
  bar: String,
) -> TwoOptionals(foo, HasBar) {
  TwoOptionals(..two_optionals, bar: Some(bar))
}

pub fn to_string(two_optionals: TwoOptionals(foo, bar)) -> String {
  let foo = case two_optionals.foo {
    Some(slot) -> slot
    None -> ""
  }
  let bar = case two_optionals.bar {
    Some(slot) -> slot
    None -> ""
  }

  "
<div>
    " <> foo <> "
    " <> bar <> "
</div>"
}
