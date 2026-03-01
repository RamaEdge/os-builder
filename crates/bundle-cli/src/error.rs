use thiserror::Error;

#[derive(Error, Debug)]
pub enum BundleError {
    #[error("image pull failed: {0}")]
    PullFailed(String),

    #[error("skopeo not found — install skopeo to create bundles")]
    SkopeoNotAvailable,

    #[error("output directory already contains a bundle")]
    OutputExists,

    #[error("manifest.json not found in {0}")]
    ManifestNotFound(String),

    #[error("invalid manifest: {0}")]
    ManifestInvalid(String),

    #[error("unsupported schema version: {0}")]
    UnsupportedSchema(String),

    #[error("checksum mismatch: expected {expected}, got {actual}")]
    ChecksumMismatch { expected: String, actual: String },

    #[error("size mismatch: expected {expected}, got {actual}")]
    SizeMismatch { expected: u64, actual: u64 },

    #[error("referenced file not found: {0}")]
    FileNotFound(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_error_variants_have_descriptive_messages() {
        let errors: Vec<(BundleError, &str)> = vec![
            (BundleError::PullFailed("timeout".into()), "image pull failed: timeout"),
            (BundleError::SkopeoNotAvailable, "skopeo not found"),
            (BundleError::OutputExists, "output directory already contains"),
            (BundleError::ManifestNotFound("/tmp".into()), "manifest.json not found in /tmp"),
            (BundleError::ManifestInvalid("bad json".into()), "invalid manifest: bad json"),
            (BundleError::UnsupportedSchema("2.0".into()), "unsupported schema version: 2.0"),
            (BundleError::ChecksumMismatch { expected: "aaa".into(), actual: "bbb".into() }, "checksum mismatch"),
            (BundleError::SizeMismatch { expected: 100, actual: 200 }, "size mismatch"),
            (BundleError::FileNotFound("missing.tar".into()), "referenced file not found: missing.tar"),
        ];
        for (err, expected_substring) in errors {
            let msg = err.to_string();
            assert!(msg.contains(expected_substring), "Error message '{}' should contain '{}'", msg, expected_substring);
        }
    }

    #[test]
    fn io_error_converts() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "gone");
        let bundle_err: BundleError = io_err.into();
        assert!(bundle_err.to_string().contains("IO error"));
    }
}
