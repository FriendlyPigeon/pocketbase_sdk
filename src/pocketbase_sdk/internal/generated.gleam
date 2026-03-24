import gleam/dynamic/decode

pub type User {
  User(
    id: String,
    password: String,
    token_key: String,
    email: String,
    email_visibility: Bool,
    verified: Bool,
    name: String,
    avatar: String,
    created: String,
    updated: String,
  )
}

pub type Animal {
  Animal(id: String, name: String, created: String, updated: String)
}

pub type Post {
  Post(
    id: String,
    message: String,
    likes: Float,
    created: String,
    updated: String,
  )
}

pub fn user_decoder() -> decode.Decoder(User) {
  {
    use id <- decode.field("id", decode.string)
    use password <- decode.field("password", decode.string)
    use token_key <- decode.field("tokenKey", decode.string)
    use email <- decode.field("email", decode.string)
    use email_visibility <- decode.optional_field(
      "emailVisibility",
      False,
      decode.bool,
    )
    use verified <- decode.optional_field("verified", False, decode.bool)
    use name <- decode.optional_field("name", "", decode.string)
    use avatar <- decode.optional_field("avatar", "", decode.string)
    use created <- decode.optional_field("created", "", decode.string)
    use updated <- decode.optional_field("updated", "", decode.string)
    decode.success(User(
      id,
      password,
      token_key,
      email,
      email_visibility,
      verified,
      name,
      avatar,
      created,
      updated,
    ))
  }
}

pub fn animal_decoder() -> decode.Decoder(Animal) {
  {
    use id <- decode.field("id", decode.string)
    use name <- decode.optional_field("name", "", decode.string)
    use created <- decode.optional_field("created", "", decode.string)
    use updated <- decode.optional_field("updated", "", decode.string)
    decode.success(Animal(id, name, created, updated))
  }
}

pub fn post_decoder() -> decode.Decoder(Post) {
  {
    use id <- decode.field("id", decode.string)
    use message <- decode.optional_field("message", "", decode.string)
    use likes <- decode.optional_field("likes", 0.0, decode.float)
    use created <- decode.optional_field("created", "", decode.string)
    use updated <- decode.optional_field("updated", "", decode.string)
    decode.success(Post(id, message, likes, created, updated))
  }
}
