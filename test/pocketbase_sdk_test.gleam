import gleam/dynamic
import gleam/io
import gleam/string
import gleeunit
import pocketbase_sdk/cli
import pocketbase_sdk/codegen

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn generate_types_emits_decoder_code_test() {
  let schema_text = case read_file_text("pb_schema_for_tests.json") {
    Ok(text) -> text
    Error(_) -> panic as "failed to load pb_schema_for_tests.json"
  }

  let generated =
    codegen.generate_types_from_json_string(schema_text, "pocketbase")

  let generated_file =
    codegen.generate_gleam_file_from_json_string(
      schema_text,
      "src/pocketbase_sdk/generated",
    )

  io.println(generated)

  assert generated_file.path == "src/pocketbase_sdk/generated.gleam"
  assert generated_file.contents == generated

  assert string.contains(generated, "pub type Animal {")
  assert string.contains(
    generated,
    "Animal(\n    id: String,\n    name: String,\n    created: String,\n    updated: String,\n  )",
  )
  assert string.contains(generated, "pub type User {")
  assert string.contains(generated, "    email_visibility: Bool,")
  assert string.contains(
    generated,
    "pub fn animal_decoder() -> decode.Decoder(Animal)",
  )
  assert string.contains(
    generated,
    "use name <- decode.optional_field(\"name\", \"\", decode.string)",
  )
  assert string.contains(
    generated,
    "pub fn user_decoder() -> decode.Decoder(User)",
  )
  assert string.contains(
    generated,
    "use email <- decode.field(\"email\", decode.string)",
  )
  assert string.contains(
    generated,
    "decode.success(Animal(id, name, created, updated))",
  )
  assert string.contains(
    generated,
    "decode.success(User(id, password, token_key, email, email_visibility, verified, name, avatar, created, updated))",
  )

  assert string.contains(
    generated,
    "use likes <- decode.optional_field(\"likes\", 0.0, decode.float)",
  )
}

pub fn cli_run_with_args_writes_generated_file_test() {
  let output_path = "tmp/generated_from_cli_test.gleam"

  case
    cli.run_with_args([
      "pb_schema_for_tests.json",
      output_path,
    ])
  {
    Ok(path) -> {
      assert path == output_path

      let file_text = case read_file_text(output_path) {
        Ok(text) -> text
        Error(_) -> panic as "expected generated file to be written to disk"
      }

      assert string.contains(file_text, "pub type Animal {")
      assert string.contains(
        file_text,
        "pub fn animal_decoder() -> decode.Decoder(Animal)",
      )
    }
    Error(message) -> panic as message
  }
}

@external(javascript, "../gleeunit/gleeunit_ffi.mjs", "read_file")
fn read_file_text(path: String) -> Result(String, dynamic.Dynamic)
