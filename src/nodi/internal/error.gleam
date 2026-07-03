import gleam/int
import simplifile

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

  // ---- File IO errors ------------------------
  CannotReadFile(from: String, reason: simplifile.FileError)
}

pub fn describe_error(error: Error) -> String {
  case error {
    InvalidTemplateName(name:, reason:) ->
      "Invalid template name \""
      <> name
      <> "\": "
      <> value_identifier_describe_error(reason)
    SeparatorWithNoMetadata ->
      "Found \"---\" separator but no declarations before it. Did you forget to add metadata or remove the separator?"
    EmptyDeclaration(keyword:) ->
      "Declaration \""
      <> keyword
      <> "\" is empty. Did you forget to a slot or remove the keyword?"
    DuplicateSlotName(name:) ->
      "Found a duplicate slot name \""
      <> name
      <> "\", please make sure they are unique."
    InvalidKeywordName(name:) ->
      "The keyword \""
      <> name
      <> "\" is not valid. Only \"req\" (Required) and \"opt\" (Optional) are valid names."
    InvalidSlotName(keyword:, name:, reason:) ->
      "Slot \""
      <> name
      <> "\" at keyword \""
      <> keyword
      <> "\" is invalid: "
      <> value_identifier_describe_error(reason)
    MissingDeclarationEquals(declaration:) ->
      "Missing equals sign in the declaration \"" <> declaration <> "\""
    DuplicateKeyword(keyword:) ->
      "The keyword \""
      <> keyword
      <> "\" is duplicated, keywords should be unique."
    UndeclaredSlotRef(name:) ->
      "Slot reference \""
      <> name
      <> "\" is not declared, did you forget to add it in the metadata?"
    UnusedDeclaration(name:) ->
      "Slot declaration \""
      <> name
      <> "\" is not present in the body, did you forget to add it?"
    UnterminatedSlotRef ->
      "There is a slot reference with an opened \"<%\" delimiter"
      <> " but it's missing the closing \"%>\" delimiter, did you forget to add it?"
    InvalidSlotRef(name:, reason:) ->
      "The \""
      <> name
      <> "\" slot reference is invalid: "
      <> value_identifier_describe_error(reason)
    CannotReadFile(from:, reason:) ->
      "Cannot read the file \""
      <> from
      <> "\": "
      <> simplifile.describe_error(reason)
  }
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

fn value_identifier_describe_error(error: ValueIdentifierError) -> String {
  case error {
    ValueIsEmpty -> "name can't be empty"
    ValueContainsInvalidGrapheme(at:, grapheme:) ->
      "unexpected grapheme \""
      <> grapheme
      <> "\" at position "
      <> int.to_string(at)
  }
}
