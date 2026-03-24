import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string

type CollectionSchema {
  CollectionSchema(name: String, system: Bool, fields: List(FieldSchema))
}

type FieldSchema {
  FieldSchema(name: String, field_type: String, required: Bool)
}

pub type GeneratedFile {
  GeneratedFile(path: String, contents: String)
}

fn field_schema_decoder() -> decode.Decoder(FieldSchema) {
  use name <- decode.field("name", decode.string)
  use field_type <- decode.field("type", decode.string)
  use required <- decode.optional_field("required", False, decode.bool)
  decode.success(FieldSchema(name:, field_type:, required:))
}

fn collection_schema_decoder() -> decode.Decoder(CollectionSchema) {
  use name <- decode.field("name", decode.string)
  use system <- decode.optional_field("system", False, decode.bool)
  use fields <- decode.field("fields", decode.list(of: field_schema_decoder()))
  decode.success(CollectionSchema(name:, system:, fields:))
}

pub fn generate_types(pb_schema: json.Json, module_name: String) -> String {
  pb_schema
  |> json.to_string()
  |> generate_types_from_json_string(module_name)
}

pub fn generate_gleam_file(
  pb_schema: json.Json,
  module_name: String,
) -> GeneratedFile {
  pb_schema
  |> json.to_string()
  |> generate_gleam_file_from_json_string(module_name)
}

pub fn generate_types_from_json_string(
  pb_schema_json: String,
  module_name: String,
) -> String {
  let _ = module_name

  case
    json.parse(
      pb_schema_json,
      using: decode.list(of: collection_schema_decoder()),
    )
  {
    Ok(collections) -> render_module(collections)
    Error(_) -> ""
  }
}

pub fn generate_gleam_file_from_json_string(
  pb_schema_json: String,
  module_name: String,
) -> GeneratedFile {
  GeneratedFile(
    path: module_name <> ".gleam",
    contents: generate_types_from_json_string(pb_schema_json, module_name),
  )
}

fn render_module(collections: List(CollectionSchema)) -> String {
  let app_collections = filter_application_collections(collections)
  let type_definitions = app_collections |> list.map(render_collection_type)
  let decoders =
    app_collections
    |> list.map(render_collection_decoder)

  case app_collections {
    [] -> "import gleam/dynamic/decode\n"
    _ -> {
      "import gleam/dynamic/decode\n\n"
      <> string.join(type_definitions, "\n\n")
      <> "\n\n"
      <> string.join(decoders, "\n\n")
    }
  }
}

fn filter_application_collections(
  collections: List(CollectionSchema),
) -> List(CollectionSchema) {
  collections
  |> list.filter(fn(collection) {
    !collection.system && !string.starts_with(collection.name, "_")
  })
}

fn render_collection_type(collection: CollectionSchema) -> String {
  let type_name = collection_type_name(collection.name)
  let field_lines = collection.fields |> list.map(render_type_field)

  let constructor = case field_lines {
    [] -> "  " <> type_name
    _ -> {
      "  " <> type_name <> "(\n" <> string.join(field_lines, "\n") <> "\n  )"
    }
  }

  "pub type " <> type_name <> " {\n" <> constructor <> "\n" <> "}"
}

fn render_type_field(field: FieldSchema) -> String {
  "    "
  <> field_identifier(field.name)
  <> ": "
  <> gleam_type_for_field_type(field.field_type)
  <> ","
}

fn render_collection_decoder(collection: CollectionSchema) -> String {
  let type_name = collection_type_name(collection.name)
  let decoder_name = snake_case(type_name) <> "_decoder"

  let use_lines = collection.fields |> list.map(render_field_use)
  let constructor_args =
    collection.fields
    |> list.map(fn(field) { field_identifier(field.name) })
    |> string.join(with: ", ")

  let body = case use_lines {
    [] -> "    decode.success(" <> type_name <> "())"
    _ -> {
      string.join(use_lines, "\n")
      <> "\n"
      <> "    decode.success("
      <> type_name
      <> "("
      <> constructor_args
      <> "))"
    }
  }

  "pub fn "
  <> decoder_name
  <> "() -> decode.Decoder("
  <> type_name
  <> ") {\n"
  <> "  {\n"
  <> body
  <> "\n"
  <> "  }\n"
  <> "}"
}

fn render_field_use(field: FieldSchema) -> String {
  let key = field.name
  let identifier = field_identifier(field.name)
  let decoder = decoder_for_field_type(field.field_type)

  case field.required {
    True -> {
      "    use "
      <> identifier
      <> " <- decode.field(\""
      <> key
      <> "\", "
      <> decoder
      <> ")"
    }
    False -> {
      "    use "
      <> identifier
      <> " <- decode.optional_field(\""
      <> key
      <> "\", "
      <> default_for_field_type(field.field_type)
      <> ", "
      <> decoder
      <> ")"
    }
  }
}

fn decoder_for_field_type(field_type: String) -> String {
  case field_type {
    "bool" -> "decode.bool"
    "number" -> "decode.float"
    "int" -> "decode.int"
    _ -> "decode.string"
  }
}

fn default_for_field_type(field_type: String) -> String {
  case field_type {
    "bool" -> "False"
    "number" -> "0.0"
    "int" -> "0"
    _ -> "\"\""
  }
}

fn gleam_type_for_field_type(field_type: String) -> String {
  case field_type {
    "bool" -> "Bool"
    "number" -> "Float"
    "int" -> "Int"
    _ -> "String"
  }
}

fn collection_type_name(collection_name: String) -> String {
  let singular = case string.ends_with(collection_name, "s") {
    True ->
      string.slice(
        from: collection_name,
        at_index: 0,
        length: string.length(collection_name) - 1,
      )
    False -> collection_name
  }

  singular
  |> string.split(on: "_")
  |> list.map(capitalize_word)
  |> string.join(with: "")
}

fn capitalize_word(word: String) -> String {
  case string.to_graphemes(word) {
    [] -> word
    [first, ..rest] -> string.uppercase(first) <> string.join(rest, "")
  }
}

fn field_identifier(name: String) -> String {
  snake_case(name)
}

fn snake_case(value: String) -> String {
  snake_case_loop(string.to_graphemes(value), "", True)
}

fn snake_case_loop(chars: List(String), acc: String, is_first: Bool) -> String {
  case chars {
    [] -> acc
    [char, ..rest] -> {
      let lower = string.lowercase(char)
      let upper = string.uppercase(char)
      let is_upper = char == upper && char != lower

      let next_acc = case char {
        "-" -> acc <> "_"
        " " -> acc <> "_"
        "." -> acc <> "_"
        _ ->
          case is_upper {
            True ->
              case is_first {
                True -> acc <> lower
                False -> acc <> "_" <> lower
              }
            False -> acc <> lower
          }
      }

      snake_case_loop(rest, next_acc, False)
    }
  }
}
