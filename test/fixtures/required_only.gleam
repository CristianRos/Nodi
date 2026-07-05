pub type RequiredOnly {
  RequiredOnly(foo: String)
}

pub fn new(foo: String) -> RequiredOnly {
  RequiredOnly(foo:)
}

pub fn to_string(required_only: RequiredOnly) -> String {
  "
<div>
    " <> required_only.foo <> "
</div>"
}
