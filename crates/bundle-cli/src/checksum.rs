use crate::error::BundleError;

/// A parsed line from a GNU coreutils `sha256sum` output file.
///
/// Format: `<64-hex-chars>  <filename>\n` (note: two spaces between hash and filename).
pub(crate) struct ChecksumLine {
    pub hex: String,
    pub file: String,
}

impl ChecksumLine {
    /// Parse a single checksum line, enforcing the two-space separator contract.
    ///
    /// Returns `Err(BundleError::ManifestInvalid)` if:
    /// - The line does not contain a two-space separator
    /// - The hex portion is not exactly 64 characters
    /// - The hex portion contains non-hex characters
    /// - The filename portion is empty
    pub fn parse(line: &str) -> Result<Self, BundleError> {
        let trimmed = line.trim_end_matches('\n');

        let parts: Vec<&str> = trimmed.splitn(2, "  ").collect();
        if parts.len() != 2 {
            return Err(BundleError::ManifestInvalid(format!(
                "checksum line missing two-space separator: {:?}",
                trimmed
            )));
        }

        let hex = parts[0];
        let file = parts[1];

        if hex.len() != 64 {
            return Err(BundleError::ManifestInvalid(format!(
                "checksum hex must be 64 characters, got {}",
                hex.len()
            )));
        }

        if !hex.chars().all(|c| c.is_ascii_hexdigit()) {
            return Err(BundleError::ManifestInvalid(
                "checksum hex contains non-hex characters".to_string(),
            ));
        }

        if file.is_empty() {
            return Err(BundleError::ManifestInvalid(
                "checksum filename is empty".to_string(),
            ));
        }

        Ok(Self {
            hex: hex.to_string(),
            file: file.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const VALID_HEX: &str = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789";

    #[test]
    fn test_parse_valid_line() {
        let line = format!("{}  myfile.oci.tar", VALID_HEX);
        let result = ChecksumLine::parse(&line).unwrap();
        assert_eq!(result.hex, VALID_HEX);
        assert_eq!(result.file, "myfile.oci.tar");
    }

    #[test]
    fn test_parse_single_space_rejected() {
        let line = format!("{} myfile.oci.tar", VALID_HEX);
        assert!(
            ChecksumLine::parse(&line).is_err(),
            "Single-space separator must be rejected"
        );
    }

    #[test]
    fn test_parse_short_hex_rejected() {
        let short_hex = &VALID_HEX[..63];
        let line = format!("{}  myfile.oci.tar", short_hex);
        assert!(ChecksumLine::parse(&line).is_err());
    }

    #[test]
    fn test_parse_non_hex_rejected() {
        let bad_hex = format!("g{}", &VALID_HEX[1..]);
        let line = format!("{}  myfile.oci.tar", bad_hex);
        assert!(ChecksumLine::parse(&line).is_err());
    }

    #[test]
    fn test_parse_empty_filename_rejected() {
        let line = format!("{}  ", VALID_HEX);
        assert!(ChecksumLine::parse(&line).is_err());
    }

    #[test]
    fn test_parse_trailing_newline() {
        let line = format!("{}  myfile.oci.tar\n", VALID_HEX);
        let result = ChecksumLine::parse(&line).unwrap();
        assert_eq!(result.hex, VALID_HEX);
        assert_eq!(result.file, "myfile.oci.tar");
    }
}
