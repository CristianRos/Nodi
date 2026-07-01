pub type Error {
  // ---- Template errors -----------------------
  // 
  InvalidTemplateName(name: String, reason: ValueIdentifierError)
  SeparatorWithNoMetadata

  EmptyDeclaration(keyword: String)
  DuplicateSlotName(name: String)
  InvalidKeywordName(name: String)
  InvalidSlotName(keyword: String, name: String, reason: ValueIdentifierError)
  MissingDeclarationEquals(declaration: String)

  DuplicateKeyword(keyword: String)
  UndeclaredSlotRef(name: String)
  UnusedDeclaration(name: String)

  UnterminatedSlotRef
  InvalidSlotRef(name: String, reason: ValueIdentifierError)
}

// ---- Gleam Identifier Errors ---------------------
// These errors come from Giaccomo Cavalieri's
// implementation of Squirrel.
// https://github.com/giacomocavalieri/squirrel

pub type ValueIdentifierError {
  ValueContainsInvalidGrapheme(at: Int, grapheme: String)
  ValueIsEmpty
}

pub type TypeIdentifierError {
  TypeContainsInvalidGrapheme(at: Int, grapheme: String)
  TypeIsEmpty
}
