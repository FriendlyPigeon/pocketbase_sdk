import gleam/dynamic/decode
import gleam/fetch
import gleam/javascript/promise
import gleam/list

import collection.{PbRecords}
import pocketbase

const base_url = "localhost"

type Animal {
  Animal(name: String)
}

pub fn get_collection_test() {
  let pb = pocketbase.new(base_url)

  let req =
    pb
    |> collection.collection("animals")
    |> collection.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case collection.decode_list(res, animal_decoder) {
          Ok(PbRecords(page:, total_items:, items:, ..)) -> {
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

pub fn get_collection_sort_test() {
  let pb = pocketbase.new(base_url)

  let req =
    pb
    |> collection.collection("animals")
    |> collection.sort("+name")
    |> collection.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case collection.decode_list(res, animal_decoder) {
          Ok(PbRecords(page:, total_items:, items:, ..)) -> {
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
  let pb = pocketbase.new(base_url)

  let req =
    pb
    |> collection.collection("animals")
    |> collection.filter("name = \"bear\"")
    |> collection.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case collection.decode_list(res, animal_decoder) {
          Ok(PbRecords(page:, total_items:, items:, ..)) -> {
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
  let pb = pocketbase.new(base_url)

  let req =
    pb
    |> collection.collection("animals")
    |> collection.filter("name = 'bear' || name = 'tiger'")
    |> collection.sort("-name")
    |> collection.list(1, 50)

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) ->
        case collection.decode_list(res, animal_decoder) {
          Ok(PbRecords(page:, total_items:, items:, ..)) -> {
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
  let pb = pocketbase.new(base_url)

  let req =
    pb
    |> collection.collection("animals")
    |> collection.one("p7m2ga6mbkciygd")

  let animal_decoder = {
    use name <- decode.field("name", decode.string)
    decode.success(Animal(name))
  }

  fetch.send(req)
  |> promise.try_await(fetch.read_json_body)
  |> promise.map(fn(result) {
    case result {
      Ok(res) -> {
        case collection.decode_one(res, animal_decoder) {
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
