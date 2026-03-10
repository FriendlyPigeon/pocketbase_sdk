import gleam/dict
import gleam/javascript/promise
import gleam/list

import collection.{PbRecords, collection, get_list}
import pocketbase

pub fn get_collection_test() {
  let base_url = "localhost"
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
