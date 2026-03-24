# pocketbase_sdk

[![Package Version](https://img.shields.io/hexpm/v/pocketbase_sdk)](https://hex.pm/packages/pocketbase_sdk)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pocketbase_sdk/)

```sh
gleam add pocketbase_sdk@1
```

## Usage

### Generate types and decoders from exported PocketBase schema

After adding this package to your project, you can generate a Gleam module from an exported PocketBase schema JSON file:

```sh
gleam run -m pocketbase_sdk -- pb_schema.json src/pocketbase_sdk/generated.gleam
```

- First argument: path to exported PocketBase schema JSON
- Second argument (optional): output `.gleam` path
- Default output path: `src/pocketbase_sdk/generated.gleam`

Then import the generated module and use the generated decoder with `pocketbase.list_result_decoder`:

```gleam
import pocketbase_sdk/generated

let decoder = generated.animal_decoder()
```

### NOTE: This library is very much in active development and should not be used in a production project yet

This package provides two modules:

- `pocketbase` for client configuration and auth token storage
- `collection` for building collection requests and decoding responses

### Create a client

```gleam
import pocketbase

let pb =
  pocketbase.new("localhost")
  |> pocketbase.https(False)
  |> pocketbase.port(8090)
```

### List records

```gleam
import collection
import gleam/fetch
import gleam/javascript/promise

let req =
  pb
  |> collection.collection("animals")
  |> collection.sort("+name")
  |> collection.list(1, 20)

fetch.send(req)
|> promise.try_await(fetch.read_json_body)
```

### Authenticate and reuse token

```gleam
let auth_req =
  pb
  |> collection.collection("users")
  |> collection.auth_with_password("test@example.com", "password")

// ... send auth_req and get response ...
// After decoding a successful auth response Ok(auth) with collection.decode_auth:
case collection decode_auth(res, auth_decoder) {
  Ok(auth) -> {
    let pb2 = pb |> pocketbase.auth(token)

    // Requests built from pb2 include Authorization header.
    let users_req =
      pb2
      |> collection.collection("users")
      |> collection.list(1, 20)
  }
}
// ...
```

### Create / update / delete

```gleam
import gleam/json

let create_body =
  json.to_string(json.object([#("name", json.string("elephant"))]))

let create_req =
  pb
  |> collection.collection("animals")
  |> collection.create(create_body)

let update_body =
  json.to_string(json.object([#("name", json.string("elephant-2"))]))

let update_req =
  pb
  |> collection.collection("animals")
  |> collection.update("RECORD_ID", update_body)

let delete_req =
  pb
  |> collection.collection("animals")
  |> collection.delete("RECORD_ID", "")
```

### Decode helpers

- `collection.decode_one(response, decoder)` used for decoding `one` response
- `collection.decode_list(response, item_decoder)` used for decoding `list` response
- `collection.decode_auth(response, auth_decoder)` used for decoding `auth_with_password` response

Further documentation can be found at <https://hexdocs.pm/pocketbase_sdk>.

## Development

Tests in this repository run like integration tests and expect PocketBase to be provisioned and seeded by:

```sh
./run_tests.sh
```

Please have the gleam tests run via this script instead of using `gleam test` otherwise you will end up with an inconsistent test database that will show tests as failing.