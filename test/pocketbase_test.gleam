import fetch_sse
import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string

import pocketbase_sdk/internal/generated
import pocketbase_sdk/pocketbase

const base_url = "localhost"

type Animal {
  Animal(name: String)
}

type User {
  User(
    id: String,
    name: String,
    email: String,
    created: String,
    updated: String,
    avatar: String,
  )
}

pub fn new_pocketbase_test() {
  let pb =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)

  assert pb.base_url == base_url
  assert pb.scheme == http.Http
  assert pb.port == 8090
  assert pb.auth_store == None
}

pub fn get_collection_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case
          decode.run(res.body, pocketbase.list_result_decoder(animal_decoder))
        {
          Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
            assert page == 1
            assert total_items == 3
            case list.first(items) {
              Ok(first_item) -> {
                assert first_item == Animal(name: "lion")
              }
              Error(Nil) -> panic as "expected 3 items, found none"
            }
          }
          Error(_) -> panic as "failed to decode"
        }
      Error(_) -> panic as "fetch failed"
    }
  })
}

pub fn get_collection_codegen_generated_decoder_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.list(1, 50)

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case
          decode.run(
            res.body,
            pocketbase.list_result_decoder(generated.animal_decoder()),
          )
        {
          Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
            assert page == 1
            assert total_items == 3
            case list.first(items) {
              Ok(first_item) -> {
                assert first_item.name == "lion"
              }
              Error(Nil) -> panic as "expected 3 items, found none"
            }
          }
          Error(_) -> panic as "failed to decode generated animal list"
        }
      Error(_) -> panic as "fetch failed"
    }
  })
}

pub fn get_collection_sort_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.sort("+name")
    |> pocketbase.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case
          decode.run(res.body, pocketbase.list_result_decoder(animal_decoder))
        {
          Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
            assert page == 1
            assert total_items == 3
            case list.first(items) {
              Ok(first_item) -> {
                assert first_item == Animal(name: "bear")
              }
              Error(Nil) -> panic as "expected 3 items, found none"
            }
          }
          Error(_) -> panic as "failed to decode"
        }
      Error(_) -> panic as "fetch failed"
    }
  })
}

pub fn get_collection_filter_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.filter("name = \"bear\"")
    |> pocketbase.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case
          decode.run(res.body, pocketbase.list_result_decoder(animal_decoder))
        {
          Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
            assert page == 1
            assert total_items == 1
            case list.first(items) {
              Ok(first_item) -> {
                assert first_item == Animal(name: "bear")
              }
              Error(Nil) -> panic as "expected 1 item, found none"
            }
          }
          Error(_) -> panic as "failed to decode"
        }
      Error(_) -> panic as "fetch failed"
    }
  })
}

pub fn get_collection_filter_sort_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.filter("name = 'bear' || name = 'tiger'")
    |> pocketbase.sort("-name")
    |> pocketbase.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case
          decode.run(res.body, pocketbase.list_result_decoder(animal_decoder))
        {
          Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
            assert page == 1
            assert total_items == 2
            case list.first(items) {
              Ok(first_item) -> {
                assert first_item == Animal(name: "tiger")
              }
              Error(Nil) -> panic as "expected 2 items, found none"
            }
          }
          Error(_) -> panic as "failed to decode"
        }
      Error(_) -> panic as "fetch failed"
    }
  })
}

pub fn get_collection_one_valid_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.one("p7m2ga6mbkciygd")

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        case decode.run(res.body, animal_decoder) {
          Ok(animal) -> {
            assert animal == Animal(name: "lion")
          }
          Error(_) -> panic as "failed to decode animal"
        }
      }

      Error(_) -> panic as "fetch failed in test"
    }
  })
}

pub fn get_collection_users_list_none_unauthenticated_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("users")
    |> pocketbase.list(1, 50)

  let user_decoder = {
    use email <- decode.field("email", decode.string)
    decode.success(User(
      id: "",
      name: "",
      email: email,
      created: "",
      updated: "",
      avatar: "",
    ))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case
          decode.run(res.body, pocketbase.list_result_decoder(user_decoder))
        {
          Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
            assert page == 1
            assert total_items == 0
            case list.first(items) {
              Ok(_first_item) -> {
                panic as "expected 0 items, found some"
              }
              Error(Nil) -> Nil
            }
          }
          Error(_) -> panic as "failed to decode"
        }
      Error(_) -> panic as "fetch failed"
    }
  })
}

pub fn post_collection_auth_with_valid_password_then_get_users_test() {
  let pb =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)

  let req =
    pb
    |> pocketbase.collection("users")
    |> pocketbase.auth_with_password("test@example.com", "password")

  let user_decoder = {
    use avatar <- decode.field("avatar", decode.string)
    use created <- decode.field("created", decode.string)
    use updated <- decode.field("updated", decode.string)
    use email <- decode.field("email", decode.string)
    use id <- decode.field("id", decode.string)
    use name <- decode.field("name", decode.string)
    decode.success(User(id, name, email, created, updated, avatar))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.await(fn(result) {
    case result {
      Ok(res) -> {
        case pocketbase.auth_response_decode(res, user_decoder) {
          Ok(pocketbase.AuthSuccess(token, record)) -> {
            assert token != ""
            assert record.email == "test@example.com"

            let pb2 = pb |> pocketbase.auth(token)

            let req2 =
              pb2
              |> pocketbase.collection("users")
              |> pocketbase.page(1)
              |> pocketbase.per_page(20)

            fetch.send(req2)
            |> promise.try_await(fetch.read_json_body)
            |> promise.map(fn(result2) {
              case result2 {
                Ok(res2) -> {
                  case
                    decode.run(
                      res2.body,
                      pocketbase.list_result_decoder(user_decoder),
                    )
                  {
                    Ok(pocketbase.ListResult(page:, total_items:, items:, ..)) -> {
                      assert page == 1
                      assert total_items == 1
                      case list.first(items) {
                        Ok(first_item) -> {
                          assert first_item
                            == User(
                              id: record.id,
                              name: record.name,
                              email: record.email,
                              created: record.created,
                              updated: record.updated,
                              avatar: record.avatar,
                            )
                        }

                        Error(Nil) -> panic as "expected 1 item, found none"
                      }
                    }

                    Error(_) ->
                      panic as "failed to decode post auth collection list"
                  }
                }

                Error(_) -> panic as "fetch failed in test"
              }
            })
          }

          Error(pocketbase.AuthFailure(status, message)) ->
            panic as {
              "authentication failed with status "
              <> int.to_string(status)
              <> ": "
              <> message
            }

          Error(pocketbase.AuthDecodeError(status, message)) ->
            panic as {
              "authentication response decode failed with status "
              <> int.to_string(status)
              <> ": "
              <> message
            }
        }
      }

      Error(_) -> panic as "auth post failed in test"
    }
  })
}

pub fn post_collection_create_record_test() {
  let body = json.to_string(json.object([#("name", json.string("elephant"))]))

  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.create(body)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        case decode.run(res.body, animal_decoder) {
          Ok(animal) -> {
            assert animal == Animal(name: "elephant")
          }
          Error(_) -> panic as "failed to decode created animal"
        }
      }
      Error(_) -> panic as "fetch failed in create test"
    }
  })
}

pub fn patch_collection_update_record_test() {
  let body = json.to_string(json.object([#("name", json.string("giraffe"))]))

  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.update("p7m2ga6mbkciygd", body)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        case decode.run(res.body, animal_decoder) {
          Ok(animal) -> {
            assert animal == Animal(name: "giraffe")
          }
          Error(_) -> panic as "failed to decode updated animal"
        }
      }
      Error(_) -> panic as "fetch failed in update test"
    }
  })
}

pub fn delete_collection_delete_record_test() {
  let body = json.to_string(json.object([]))

  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.delete("p7m2ga6mbkciygd", body)

  fetch.send(req)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        assert res.status == 204
      }
      Error(_) -> panic as "fetch failed in delete test"
    }
  })
}

pub fn post_collection_auth_with_invalid_password_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("users")
    |> pocketbase.auth_with_password("test@example.com", "wrong_password")

  let auth_decoder = {
    use avatar <- decode.field("avatar", decode.string)
    use created <- decode.field("created", decode.string)
    use updated <- decode.field("updated", decode.string)
    use email <- decode.field("email", decode.string)
    use id <- decode.field("id", decode.string)
    use name <- decode.field("name", decode.string)
    decode.success(User(id, name, email, created, updated, avatar))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        case pocketbase.auth_response_decode(res, auth_decoder) {
          Ok(_auth) -> {
            panic as "invalid password provided, authentication should fail"
          }
          Error(pocketbase.AuthFailure(status:, message:)) -> {
            assert status == 400
            assert string.contains(message, "Failed to authenticate")
          }
          Error(_) ->
            panic as "unexpected error decoding auth response in invalid password test, should be AuthFailure with 400 status"
        }
      }

      Error(_) -> panic as "auth post failed in test"
    }
  })
}

pub fn get_realtime_connect_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.realtime_connect()

  fetch.send(req)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        assert res.status == 200
      }
      Error(_) -> panic as "fetch failed in realtime connect test"
    }
  })
}

// type RealtimeMessage {
//   RealtimeMessage(client_id: String)
// }

fn pocketbase_decoder() -> decode.Decoder(String) {
  use client_id <- decode.field("clientId", decode.string)
  decode.success(client_id)
}

pub fn get_realtime_connect_client_id_test() {
  let req =
    pocketbase.new(base_url)
    |> pocketbase.https(False)
    |> pocketbase.port(8090)
    |> pocketbase.collection("animals")
    |> pocketbase.realtime_connect()
  // let assert Ok(req) = request.to("http://localhost:8090/api/realtime")
  // let get_req = req |> request.set_method(http.Get)

  fetch_sse.fetch_event_data(
    req,
    Some(1),
    Some(fn(message) {
      case decode.run(message, pocketbase_decoder()) {
        Ok(client_id) -> {
          io.println("Received realtime message with client id: " <> client_id)

          let req2 =
            pocketbase.new(base_url)
            |> pocketbase.https(False)
            |> pocketbase.port(8090)
            |> pocketbase.collection("animals")
            |> pocketbase.realtime_set_subscriptions(client_id, [
              "animals/*",
            ])

          fetch.send(req2)
          |> promise.try_await(fetch.read_json_body)
          |> promise.map(fn(result) {
            case result {
              Ok(res) -> {
                assert res.status == 207
              }
              Error(_) ->
                panic as "fetch failed in realtime set subscriptions test"
            }
          })

          assert client_id != ""
        }
        Error(_) -> panic as "failed to decode realtime message with client id"
      }

      Nil
    }),
    Some(fn(_error) {
      panic as "realtime stream failed or callback assertion failed"
    }),
    None,
    None,
  )
}
