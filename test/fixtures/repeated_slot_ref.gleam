pub type RepeatedSlotRef {
  RepeatedSlotRef(foo: String)
}

pub fn new(foo: String) -> RepeatedSlotRef {
  RepeatedSlotRef(foo:)
}

pub fn to_string(repeated_slot_ref: RepeatedSlotRef) -> String {
  "
<div>
    " <> repeated_slot_ref.foo <> "
    " <> repeated_slot_ref.foo <> "
</div>"
}
