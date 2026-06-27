import gleam/string
import justin
import nodi/internal/error.{
  type TypeIdentifierError, type ValueIdentifierError,
  TypeContainsInvalidGrapheme, TypeIsEmpty, ValueContainsInvalidGrapheme,
  ValueIsEmpty,
}

// Gleam identifiers types and validation come from Giaccomo Cavalieri's
// implementation of Squirrel.
// https://github.com/giacomocavalieri/squirrel

/// A Gleam identifier, that is a String that starts with a lowercase letter,
/// is in snake_case, and can only contain lowercase letters, numbers and
/// underscores.
/// 
/// This can only be built using the `gleam.value_identifier` function that
/// ensures that a string is a valid Gleam identifier.
/// 
pub type ValueIdentifier {
  ValueIdentifier(String)
}

/// A Gleam type identifier, that is a string that starts with an uppercase
/// letter, is in PascalCase and can only contain lowercase letters, numbers and
/// uppercase letters.
///
/// > 💡 This can only be built using the `gleam.type_identifier` function that
/// > ensures that a string is a valid Gleam type identifier.
///
pub opaque type TypeIdentifier {
  TypeIdentifier(String)
}

/// Validates if the given string is a valid Gleam value identifier (that is not
/// a discard identifier, that is starting with an '_').
///
/// > 💡 A valid identifier can be described by the following regex:
/// > `[a-z][a-z0-9_]*`.
///
pub fn value_identifier(
  from name: String,
) -> Result(ValueIdentifier, ValueIdentifierError) {
  // A valid identifier needs to start with a lowercase letter.
  // We do not accept _discard identifier as valid.
  case string.pop_grapheme(name) {
    Error(_) -> Error(ValueIsEmpty)
    Ok(#(char, rest)) ->
      case is_lowercase_letter(char) {
        True -> to_value_identifier_rest(name, rest, 1)
        False -> Error(ValueContainsInvalidGrapheme(0, char))
      }
  }
}

fn to_value_identifier_rest(
  name: String,
  rest: String,
  position: Int,
) -> Result(ValueIdentifier, ValueIdentifierError) {
  // Only valid values are '_', lowercase letters and digits, 
  case string.pop_grapheme(rest) {
    Error(_) -> Ok(ValueIdentifier(name))
    Ok(#(char, rest)) -> {
      let is_valid_char =
        char == "_" || is_lowercase_letter(char) || is_digit(char)
      case is_valid_char {
        True -> to_value_identifier_rest(name, rest, position + 1)
        False -> Error(ValueContainsInvalidGrapheme(position, char))
      }
    }
  }
}

pub fn value_identifier_to_string(identifier: ValueIdentifier) -> String {
  let ValueIdentifier(name) = identifier
  name
}

/// Validates if the given string is a valid Gleam type identifier.
///
/// > 💡 A valid type identifier can be described by the following regex:
/// > `[A-Z][A-Za-z0-9]*`.
///
pub fn type_identifier(
  from name: String,
) -> Result(TypeIdentifier, TypeIdentifierError) {
  // A valid type identifier needs to start with an uppercase letter.
  case string.pop_grapheme(name) {
    Error(_) -> Error(TypeIsEmpty)
    Ok(#(char, rest)) ->
      case is_uppercase_letter(char) {
        False -> Error(TypeContainsInvalidGrapheme(0, char))
        True -> to_type_identifier_rest(name, rest, 1)
      }
  }
}

fn to_type_identifier_rest(
  name: String,
  rest: String,
  position: Int,
) -> Result(TypeIdentifier, TypeIdentifierError) {
  // The rest of an identifier can only contain lowercase or uppercase letters,
  // numbers, or be empty. In all other cases it's not valid.
  case string.pop_grapheme(rest) {
    Error(_) -> Ok(TypeIdentifier(name))
    Ok(#(char, rest)) -> {
      let is_valid_char =
        is_lowercase_letter(char) || is_uppercase_letter(char) || is_digit(char)
      case is_valid_char {
        True -> to_type_identifier_rest(name, rest, position + 1)
        False -> Error(TypeContainsInvalidGrapheme(position, char))
      }
    }
  }
}

pub fn type_identifier_to_string(identifier: TypeIdentifier) -> String {
  let TypeIdentifier(name) = identifier
  name
}

pub fn value_to_type_identifier(from: ValueIdentifier) -> TypeIdentifier {
  let name = from |> value_identifier_to_string |> justin.pascal_case
  let assert Ok(identifier) = type_identifier(from: name)
    as {
      "value_to_type_identifier: PascalCase("
      <> name
      <> ") should always be a valid TypeIdentifier"
    }
  identifier
}

pub fn phantom_type_names(
  from: ValueIdentifier,
) -> #(TypeIdentifier, TypeIdentifier) {
  let name =
    from
    |> value_to_type_identifier
    |> type_identifier_to_string

  let assert Ok(no) = type_identifier(from: "No" <> name)
    as {
      "phantom_type_names: \"No\" + "
      <> name
      <> " should always be a valid identifier"
    }
  let assert Ok(has) = type_identifier(from: "Has" <> name)
    as {
      "phantom_type_names: \"Has\" + "
      <> name
      <> " should always be a valid identifier"
    }

  #(no, has)
}

// ---- UTILS ------------------------------------------------------------------------

fn is_lowercase_letter(char: String) -> Bool {
  case char {
    "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" -> True
    "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" -> True
    "w" | "x" | "y" | "z" -> True
    _ -> False
  }
}

fn is_uppercase_letter(char: String) -> Bool {
  case char {
    "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" -> True
    "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" -> True
    "W" | "X" | "Y" | "Z" -> True
    _ -> False
  }
}

fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}
