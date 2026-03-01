// Manifest types — implemented in plan 02
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleManifest {
    pub schema_version: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleImage {
    pub reference: String,
}
