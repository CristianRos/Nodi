pub type Error {
  // ---- Structural errors ---------------------
  //
  SeparatorWithNoDeclarations
  DeclarationWithoutSeparator

  // ---- Declaration errors (one req=/opt= line in isolation) ----
  //
  EmptyDeclaration(kind: SlotKind, line: Int)
  DuplicateSlotName(kind: SlotKind, name: String, line: Int)
  InvalidSlotName(
    kind: SlotKind,
    name: String,
    reason: ValueIdentifierError,
    line: Int,
  )
  UnknownDeclarationKeyword(keyword: String, line: Int)

  // ---- Cross-reference errors (Metadata vs Body, or kind vs kind) ----
  //
  SlotDeclaredAsBothKinds(name: String)
  DuplicateSlotKind(kind: SlotKind, line: Int)
  UndeclaredSlotRef(name: String, line: Int, column: Int)
  UnusedDeclaration(kind: SlotKind, name: String)

  // ---- Body syntax errors ---------------------
  //
  MissingWhitespaceAroundSlotRef(name: String, line: Int, column: Int)
}

pub type SlotKind {
  Required
  Optional
}

pub type ValueIdentifierError {
  ValueContainsInvalidGrapheme(at: Int, grapheme: String)
  ValueIsEmpty
}
