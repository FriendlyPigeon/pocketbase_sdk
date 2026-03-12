import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http.{type Method, Get, Post}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/string

import pocketbase.{type PocketBase}

pub type PbRecords(a) {
  PbRecords(
    page: Int,
    per_page: Int,
    total_items: Int,
    total_pages: Int,
    items: List(a),
  )
}

pub type AuthResponse(b) {
  AuthResponse(token: String, record: b)
}

pub type AuthError {
  AuthError(status: Int, message: String)
}

pub fn decode_one(
  res: Response(Dynamic),
  decoder: Decoder(a),
) -> Result(a, List(decode.DecodeError)) {
  decode.run(res.body, decoder)
}

pub fn decode_list(
  res: Response(Dynamic),
  item_decoder: Decoder(a),
) -> Result(PbRecords(a), List(decode.DecodeError)) {
  let decoder = {
    use page <- decode.field("page", decode.int)
    use per_page <- decode.field("perPage", decode.int)
    use total_items <- decode.field("totalItems", decode.int)
    use total_pages <- decode.field("totalPages", decode.int)
    use items <- decode.field("items", decode.list(item_decoder))
    decode.success(PbRecords(page, per_page, total_items, total_pages, items))
  }
  decode.run(res.body, decoder)
}

pub fn one(req: Request(String), record_id: String) {
  request.set_path(req, req.path <> "/" <> record_id)
}

pub fn create(req: Request(String), body: Dict(String, Dynamic)) {
  request.set_method(req, Post)
  |> request.set_body(body)
}

pub fn collection(pb: PocketBase, name: String) {
  collection_request(pb, name)
}

pub fn filter(req: Request(String), filter: String) {
  add_query(req, [#("filter", filter)])
}

pub fn sort(req: Request(String), sort: String) {
  add_query(req, [#("sort", sort)])
}

pub fn expand(req: Request(String), expand: String) {
  add_query(req, [#("fields", expand)])
}

pub fn page(req: Request(String), page_number: Int) {
  add_query(req, [#("page", int.to_string(page_number))])
}

pub fn per_page(req: Request(String), number_per_page: Int) {
  add_query(req, [#("perPage", int.to_string(number_per_page))])
}

fn build_base_request(pb: PocketBase, url: String, method: Method) {
  request.new()
  |> request.set_method(method)
  |> request.set_scheme(pb.scheme)
  |> request.set_host(pb.base_url)
  |> request.set_port(pb.port)
  |> request.set_path(url)
}

pub fn collection_request(pb: PocketBase, name: String) -> Request(String) {
  let url = "/api/collections/" <> name <> "/records"

  build_base_request(pb, url, Get)
}

pub fn auth_with_password(
  req: Request(String),
  identity: String,
  password: String,
) {
  // Remove the /records added to end of the base collections request,
  // it's not used for the auth-with-password route
  let base_path = string.drop_end(req.path, string.length("/records"))
  let auth_path = base_path <> "/auth-with-password"
  let body =
    json.object([
      #("identity", json.string(identity)),
      #("password", json.string(password)),
    ])

  request.set_path(req, auth_path)
  |> request.set_method(Post)
  |> request.set_body(json.to_string(body))
  |> request.set_header("content-type", "application/json")
}

pub fn decode_auth(
  res: Response(Dynamic),
  auth_decoder: Decoder(b),
) -> Result(AuthResponse(b), AuthError) {
  case res.status {
    200 -> {
      let decoder = {
        use token <- decode.field("token", decode.string)
        use record <- decode.field("record", auth_decoder)
        decode.success(AuthResponse(token:, record:))
      }
      case decode.run(res.body, decoder) {
        Ok(auth) -> Ok(auth)
        Error(_) ->
          Error(AuthError(
            status: res.status,
            message: "Failed to decode with response",
          ))
      }
    }
    _ -> {
      let error_decoder = {
        use status <- decode.field("status", decode.int)
        use message <- decode.field("message", decode.string)
        decode.success(AuthError(status:, message:))
      }
      case decode.run(res.body, error_decoder) {
        Ok(err) -> Error(err)
        Error(_) ->
          Error(AuthError(status: res.status, message: "Unknown error"))
      }
    }
  }
}

pub fn list(
  req: Request(String),
  page_number: Int,
  number_per_page: Int,
) -> Request(String) {
  req
  |> page(page_number)
  |> per_page(number_per_page)
}

fn add_query(
  req: Request(body),
  extra: List(#(String, String)),
) -> Request(body) {
  case request.get_query(req) {
    Ok(existing) -> request.set_query(req, list.append(existing, extra))
    Error(_) -> request.set_query(req, extra)
  }
}
