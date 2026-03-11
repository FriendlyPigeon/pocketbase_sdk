import gleam/dict
import gleam/dynamic
import gleam/javascript/promise
import gleam/list

import collection.{PbRecords, collection, filter, get_list, sort}
import pocketbase

const base_url = "localhost"

pub fn get_collection_test() {
  let pb = pocketbase.new(base_url)

  pb
  |> collection("animals")
  |> get_list(1, 50)
  |> promise.map(fn(result) {
    case result {
      Ok(PbRecords(page:, per_page:, total_items:, total_pages:, items:)) -> {
        assert page == 1
        assert per_page == 50
        assert total_items == 3
        assert total_pages == 1
        assert list.all(items, fn(item) { dict.has_key(item, "name") })
      }
      Error(_err) -> panic as { "fetch failed in test" }
    }
  })
}

pub fn get_collection_sort_test() {
  let pb = pocketbase.new(base_url)

  pb
  |> collection("animals")
  |> sort("+name")
  |> get_list(1, 50)
  |> promise.map(fn(result) {
    case result {
      Ok(PbRecords(page:, per_page:, total_items:, total_pages:, items:)) -> {
        assert page == 1
        assert per_page == 50
        assert total_items == 3
        assert total_pages == 1
        assert list.all(items, fn(item) { dict.has_key(item, "name") })
        case list.first(items) {
          Ok(first_item) -> {
            assert dict.get(first_item, "name") == Ok(dynamic.string("bear"))
          }
          Error(_) -> panic as { "expected at least one item" }
        }
      }
      Error(_err) -> panic as { "fetch failed in test" }
    }
  })
}

pub fn get_collection_filter_test() {
  let pb = pocketbase.new(base_url)

  pb
  |> collection("animals")
  |> filter("name = \"bear\"")
  |> get_list(1, 50)
  |> promise.map(fn(result) {
    case result {
      Ok(PbRecords(page:, per_page:, total_items:, total_pages:, items:)) -> {
        assert page == 1
        assert per_page == 50
        assert total_items == 1
        assert total_pages == 1
        case list.first(items) {
          Ok(first_item) -> {
            assert dict.get(first_item, "name") == Ok(dynamic.string("bear"))
          }
          Error(_) -> panic as { "expected at least one filtered item" }
        }
      }
      Error(_err) -> panic as { "fetch failed in test" }
    }
  })
}

pub fn get_collection_filter_sort_test() {
  let pb = pocketbase.new(base_url)

  pb
  |> collection("animals")
  |> filter("name = 'bear' || name = 'tiger'")
  |> sort("-name")
  |> get_list(1, 50)
  |> promise.map(fn(result) {
    case result {
      Ok(PbRecords(page:, per_page:, total_items:, total_pages:, items:)) -> {
        assert page == 1
        assert per_page == 50
        assert total_items == 2
        assert total_pages == 1
        case list.first(items) {
          Ok(first_item) -> {
            assert dict.get(first_item, "name") == Ok(dynamic.string("tiger"))
          }
          Error(_) -> panic as { "expected at least one filtered item" }
        }
      }
      Error(_err) -> panic as { "fetch failed in test" }
    }
  })
}
