import filepath
import glam/doc
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import nodi/internal/codegen
import nodi/internal/error.{CannotReadFile}
import nodi/internal/template as templ
import simplifile

pub fn main() -> Nil {
  generate_files()
}

pub fn generate_files() -> Nil {
  let root = get_project_root_path(from: ".")
  let files = get_nodi_file_paths(from: root)

  let results =
    files
    |> list.map(fn(f) {
      let raw_name = f |> filepath.strip_extension |> filepath.base_name
      use nodi_file <- result.try(
        simplifile.read(f) |> result.map_error(CannotReadFile(f, _)),
      )
      templ.template(raw_name:, nodi_file:)
      |> result.map(fn(template) { #(f, template) })
    })

  let #(templates_by_path, errors) = result.partition(results)

  case errors {
    [_, ..] -> {
      errors
      |> list.each(fn(err) { io.println_error(error.describe_error(err)) })
    }
    [] -> {
      templates_by_path
      |> list.each(fn(pair) {
        let #(path, template) = pair
        let output_path =
          filepath.join(
            filepath.directory_name(path),
            filepath.strip_extension(filepath.base_name(path)) <> ".gleam",
          )
        let content = codegen.emit_file(template) |> doc.to_string(80)
        let assert Ok(_) = simplifile.write(content, to: output_path)
          as { "Couldn't write to " <> output_path }
      })

      io.println("All .nodi files were turned into .gleam components")
    }
  }
}

fn get_project_root_path(from path: String) -> String {
  let toml = filepath.join(path, "gleam.toml")
  case simplifile.is_file(toml) {
    Ok(True) -> path
    Ok(False) | Error(_) -> get_project_root_path(filepath.join("..", path))
  }
}

fn get_nodi_file_paths(from path: String) -> List(String) {
  let files_and_folders = case simplifile.read_directory(path) {
    Ok(files_and_folders) -> files_and_folders
    Error(simplifile.Enoent) -> []
    Error(_) -> panic as { "couldn't read directory " <> path }
  }

  files_and_folders
  |> list.flat_map(fn(f) {
    let full_path = filepath.join(path, f)
    case simplifile.is_directory(full_path) {
      Ok(True) -> get_nodi_file_paths(full_path)
      Ok(False) ->
        case full_path |> string.ends_with(".nodi") {
          True -> [full_path]
          False -> []
        }
      Error(_) -> []
    }
  })
}
