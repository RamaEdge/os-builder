use crate::error::BundleError;

/// A validated OCI image reference with extracted tag.
///
/// Accepts references like `registry.example.com/repo:1.2.0` and
/// port-containing registries like `registry:5000/repo:1.2.0`.
///
/// Rejects shell metacharacters to prevent command injection.
pub(crate) struct ImageRef {
    pub full: String,
    pub tag: String,
}

impl ImageRef {
    /// Parse and validate an OCI image reference string.
    ///
    /// Uses `rfind(':')` (not `find`) to correctly handle port-containing
    /// registries where the first colon separates host from port.
    ///
    /// Returns `Err(BundleError::InvalidImageRef)` if:
    /// - The input is empty
    /// - The input contains shell metacharacters (`$`, `` ` ``, `|`, `;`, `&`, `<`, `>`, whitespace)
    /// - No tag separator (`:`) is found
    /// - The tag portion is empty
    pub fn parse(raw: &str) -> Result<Self, BundleError> {
        if raw.is_empty() {
            return Err(BundleError::InvalidImageRef(
                "image reference must not be empty".to_string(),
            ));
        }

        // Character allowlist: reject anything not in the safe set
        for c in raw.chars() {
            if !(c.is_ascii_alphanumeric()
                || matches!(c, '/' | ':' | '.' | '_' | '-'))
            {
                return Err(BundleError::InvalidImageRef(format!(
                    "disallowed character {:?} in image reference",
                    c
                )));
            }
        }

        // Use rfind to skip port colons in "registry:5000/repo:tag"
        let colon_pos = raw.rfind(':').ok_or_else(|| {
            BundleError::InvalidImageRef(
                "image reference must include a tag (e.g., registry/repo:1.2.0)".to_string(),
            )
        })?;

        let tag = &raw[colon_pos + 1..];
        if tag.is_empty() {
            return Err(BundleError::InvalidImageRef(
                "image tag must not be empty".to_string(),
            ));
        }

        Ok(Self {
            full: raw.to_string(),
            tag: tag.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_standard_ref() {
        let r = ImageRef::parse("registry.example.com/repo:1.2.0").unwrap();
        assert_eq!(r.full, "registry.example.com/repo:1.2.0");
        assert_eq!(r.tag, "1.2.0");
    }

    #[test]
    fn test_parse_port_registry() {
        let r = ImageRef::parse("registry:5000/repo:1.2.0").unwrap();
        assert_eq!(r.tag, "1.2.0");
    }

    #[test]
    fn test_parse_simple_ref() {
        let r = ImageRef::parse("myrepo:latest").unwrap();
        assert_eq!(r.tag, "latest");
    }

    #[test]
    fn test_parse_empty_rejected() {
        assert!(ImageRef::parse("").is_err());
    }

    #[test]
    fn test_parse_no_tag_rejected() {
        assert!(ImageRef::parse("registry/repo").is_err());
    }

    #[test]
    fn test_parse_empty_tag_rejected() {
        assert!(ImageRef::parse("registry/repo:").is_err());
    }

    #[test]
    fn test_parse_dollar_rejected() {
        assert!(ImageRef::parse("registry/repo:tag$evil").is_err());
    }

    #[test]
    fn test_parse_backtick_rejected() {
        assert!(ImageRef::parse("registry/repo:tag`cmd`").is_err());
    }

    #[test]
    fn test_parse_pipe_rejected() {
        assert!(ImageRef::parse("registry/repo:tag|pipe").is_err());
    }

    #[test]
    fn test_parse_semicolon_rejected() {
        assert!(ImageRef::parse("registry/repo:tag;cmd").is_err());
    }

    #[test]
    fn test_parse_ampersand_rejected() {
        assert!(ImageRef::parse("registry/repo:tag&bg").is_err());
    }

    #[test]
    fn test_parse_angle_brackets_rejected() {
        assert!(ImageRef::parse("registry/repo:tag<in").is_err());
        assert!(ImageRef::parse("registry/repo:tag>out").is_err());
    }

    #[test]
    fn test_parse_space_rejected() {
        assert!(ImageRef::parse("registry/repo:tag with space").is_err());
    }
}
