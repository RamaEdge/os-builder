use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleManifest {
    pub schema_version: String,
    pub created_at: DateTime<Utc>,
    pub created_by: String,
    pub image: BundleImage,
    pub target_device: String,
    #[serde(default)]
    pub notes: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BundleImage {
    pub reference: String,
    pub file: String,
    pub digest: String,
    pub size_bytes: u64,
    pub version: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn make_manifest() -> BundleManifest {
        BundleManifest {
            schema_version: "1.0".to_string(),
            created_at: Utc::now(),
            created_by: "edgeworks-bundle v0.1.0".to_string(),
            image: BundleImage {
                reference: "harbor.theedgeworks.ai/edgeworks/edge-os:1.2.0".to_string(),
                file: "edge-os-1.2.0.oci.tar".to_string(),
                digest: "sha256:abc123".to_string(),
                size_bytes: 2147483648,
                version: "1.2.0".to_string(),
            },
            target_device: "any".to_string(),
            notes: "test note".to_string(),
        }
    }

    #[test]
    fn manifest_round_trip() {
        let manifest = make_manifest();
        let json = serde_json::to_string(&manifest).unwrap();
        let parsed: BundleManifest = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.schema_version, manifest.schema_version);
        assert_eq!(parsed.image.reference, manifest.image.reference);
        assert_eq!(parsed.image.size_bytes, manifest.image.size_bytes);
        assert_eq!(parsed.notes, manifest.notes);
    }

    #[test]
    fn manifest_json_field_names_match_schema() {
        let manifest = make_manifest();
        let value: serde_json::Value = serde_json::to_value(&manifest).unwrap();
        let obj = value.as_object().unwrap();
        assert!(obj.contains_key("schema_version"));
        assert!(obj.contains_key("created_at"));
        assert!(obj.contains_key("created_by"));
        assert!(obj.contains_key("image"));
        assert!(obj.contains_key("target_device"));
        assert!(obj.contains_key("notes"));
        let image = obj["image"].as_object().unwrap();
        assert!(image.contains_key("reference"));
        assert!(image.contains_key("file"));
        assert!(image.contains_key("digest"));
        assert!(image.contains_key("size_bytes"));
        assert!(image.contains_key("version"));
    }

    #[test]
    fn notes_defaults_to_empty() {
        let json = r#"{"schema_version":"1.0","created_at":"2026-03-01T12:00:00Z","created_by":"test","image":{"reference":"r","file":"f","digest":"d","size_bytes":0,"version":"v"},"target_device":"any"}"#;
        let manifest: BundleManifest = serde_json::from_str(json).unwrap();
        assert_eq!(manifest.notes, "");
    }

    #[test]
    fn missing_required_field_fails() {
        let json = r#"{"schema_version":"1.0"}"#;
        let result = serde_json::from_str::<BundleManifest>(json);
        assert!(result.is_err());
    }

    #[test]
    fn unknown_schema_version_parses() {
        let json = r#"{"schema_version":"99.0","created_at":"2026-03-01T12:00:00Z","created_by":"test","image":{"reference":"r","file":"f","digest":"d","size_bytes":0,"version":"v"},"target_device":"any","notes":""}"#;
        let manifest: BundleManifest = serde_json::from_str(json).unwrap();
        assert_eq!(manifest.schema_version, "99.0");
    }
}
