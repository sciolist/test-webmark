use actix_web::{
    error, http::header, http::StatusCode, HttpResponse,
    HttpResponseBuilder
};
use derive_more::{Display, Error as DeriveError};

#[derive(Debug, Display, DeriveError)]
pub enum Error {
    #[display(fmt = "internal error")]
    InternalError,

    #[display(fmt = "bad request")]
    BadClientData,

    #[display(fmt = "timeout")]
    Timeout,

    #[display(fmt = "not found")]
    NotFound,
}

impl error::ResponseError for Error {
    fn error_response(&self) -> HttpResponse {
        HttpResponseBuilder::new(self.status_code())
            .insert_header((header::CONTENT_TYPE, "text/html; charset=utf-8"))
            .body(self.to_string())
    }

    fn status_code(&self) -> StatusCode {
        match *self {
            Error::InternalError => StatusCode::INTERNAL_SERVER_ERROR,
            Error::BadClientData => StatusCode::BAD_REQUEST,
            Error::Timeout => StatusCode::GATEWAY_TIMEOUT,
            Error::NotFound => StatusCode::NOT_FOUND,
        }
    }
}

impl From<sqlx::Error> for Error {
    fn from(error: sqlx::Error) -> Self {
        match error {
            sqlx::Error::RowNotFound => Error::NotFound,
            _ => Error::InternalError
        }
    }
}
