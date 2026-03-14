import gleam/dynamic/decode.{type Decoder, type Dynamic}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type ListResult(a) {
  ListResult(
    page: Int,
    per_page: Int,
    total_items: Int,
    total_pages: Int,
    items: List(a),
  )
}

pub type AuthStore {
  AuthStore(token: String)
}

pub type AuthSuccess(b) {
  AuthSuccess(token: String, record: b)
}

pub type AuthError {
  AuthDecodeError(status: Int, message: String)
  AuthFailure(status: Int, message: String)
}

pub type PocketBase {
  PocketBase(
    base_url: String,
    scheme: http.Scheme,
    port: Int,
    auth_store: Option(AuthStore),
  )
}

pub fn new(base_url: String) -> PocketBase {
  PocketBase(base_url, http.Https, 443, None)
}

pub fn port(pb: PocketBase, port: Int) {
  PocketBase(..pb, port: port)
}

pub fn https(pb: PocketBase, https: Bool) {
  case https {
    True -> PocketBase(..pb, scheme: http.Https)
    False -> PocketBase(..pb, scheme: http.Http)
  }
}

pub fn auth(pb: PocketBase, token: String) {
  PocketBase(..pb, auth_store: Some(AuthStore(token)))
}

// pub fn decode_one(
//   res: Response(Dynamic),
//   decoder: Decoder(a),
// ) -> Result(a, List(decode.DecodeError)) {
//   decode.run(res.body, decoder)
// }

pub fn list_result_decoder(item_decoder: Decoder(a)) -> Decoder(ListResult(a)) {
  use page <- decode.field("page", decode.int)
  use per_page <- decode.field("perPage", decode.int)
  use total_items <- decode.field("totalItems", decode.int)
  use total_pages <- decode.field("totalPages", decode.int)
  use items <- decode.field("items", decode.list(item_decoder))
  decode.success(ListResult(page, per_page, total_items, total_pages, items))
}

// pub fn decode_list(
//   res: Response(Dynamic),
//   item_decoder: Decoder(a),
// ) -> Result(PbRecords(a), List(decode.DecodeError)) {
//   let decoder = {
//     use page <- decode.field("page", decode.int)
//     use per_page <- decode.field("perPage", decode.int)
//     use total_items <- decode.field("totalItems", decode.int)
//     use total_pages <- decode.field("totalPages", decode.int)
//     use items <- decode.field("items", decode.list(item_decoder))
//     decode.success(PbRecords(page, per_page, total_items, total_pages, items))
//   }
//   decode.run(res.body, decoder)
// }

pub fn one(req: Request(String), record_id: String) {
  request.set_path(req, req.path <> "/" <> record_id)
}

pub fn create(req: Request(String), json_body: String) {
  request.set_method(req, http.Post)
  |> request.set_body(json_body)
  |> request.set_header("content-type", "application/json")
}

pub fn update(req: Request(String), record_id: String, json_body: String) {
  request.set_method(req, http.Patch)
  |> request.set_body(json_body)
  |> request.set_header("content-type", "application/json")
  |> request.set_path(req.path <> "/" <> record_id)
}

pub fn delete(req: Request(String), record_id: String, json_body: String) {
  request.set_method(req, http.Delete)
  |> request.set_body(json_body)
  |> request.set_header("content-type", "application/json")
  |> request.set_path(req.path <> "/" <> record_id)
}

// pub fn subscribe(req: Request(String), callback) {
//   todo
// }

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

fn build_base_request(pb: PocketBase, url: String, method: http.Method) {
  request.new()
  |> request.set_method(method)
  |> request.set_scheme(pb.scheme)
  |> request.set_host(pb.base_url)
  |> request.set_port(pb.port)
  |> request.set_path(url)
}

pub fn collection_request(pb: PocketBase, name: String) -> Request(String) {
  let url = "/api/collections/" <> name <> "/records"

  let req = build_base_request(pb, url, http.Get)

  case pb.auth_store {
    None -> req
    Some(AuthStore(token)) ->
      request.set_header(req, "Authorization", "Bearer " <> token)
  }
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
  |> request.set_method(http.Post)
  |> request.set_body(json.to_string(body))
  |> request.set_header("content-type", "application/json")
}

pub fn auth_response_decode(
  res: Response(Dynamic),
  auth_decoder: Decoder(b),
) -> Result(AuthSuccess(b), AuthError) {
  case res.status {
    200 -> {
      let decoder = {
        use token <- decode.field("token", decode.string)
        use record <- decode.field("record", auth_decoder)
        decode.success(AuthSuccess(token:, record:))
      }
      case decode.run(res.body, decoder) {
        Ok(auth) -> Ok(auth)
        Error(_) ->
          Error(AuthDecodeError(
            status: res.status,
            message: "Successful http status code, but failed to decode the response body for auth details",
          ))
      }
    }
    _ -> {
      let error_decoder = {
        use status <- decode.field("status", decode.int)
        use message <- decode.field("message", decode.string)
        decode.success(AuthFailure(status:, message:))
      }
      case decode.run(res.body, error_decoder) {
        Ok(err) -> Error(err)
        Error(_) ->
          Error(AuthDecodeError(
            status: res.status,
            message: "Failure http status code, but failed to decode the response body for error details",
          ))
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
