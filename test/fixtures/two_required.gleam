pub type TwoRequired {
  TwoRequired(foo: String, bar: String)
}

pub fn new(foo: String, bar: String) -> TwoRequired {
  TwoRequired(foo:, bar:)
}

pub fn to_string(two_required: TwoRequired) -> String {
  "
<div>
    " <> two_required.foo <> "
    " <> two_required.bar <> "
</div>"
}
