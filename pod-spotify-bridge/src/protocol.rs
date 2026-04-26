use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Deserialize)]
pub struct Request {
    pub id: u64,
    pub method: String,
    pub params: Option<Value>,
}

#[derive(Serialize)]
pub struct Response {
    pub id: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl Response {
    pub fn ok(id: u64, result: Value) -> Self {
        Self { id, result: Some(result), error: None }
    }

    pub fn error(id: u64, msg: &str) -> Self {
        Self { id, result: None, error: Some(msg.to_string()) }
    }
}

#[derive(Serialize)]
pub struct Event {
    pub event: String,
    #[serde(flatten)]
    pub data: Value,
}

impl Event {
    pub fn new(event: &str, data: Value) -> Self {
        Self { event: event.to_string(), data }
    }
}
