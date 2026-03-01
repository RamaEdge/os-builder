use std::fs;
use std::io::{BufReader, Read};
use std::path::Path;
use std::process::Command;

use chrono::Utc;
use indicatif::{ProgressBar, ProgressStyle};
use serde::Serialize;
use sha2::{Digest, Sha256};

use crate::error::BundleError;
use crate::manifest::{BundleImage, BundleManifest};

/// Machine-readable JSON output for a successful bundle creation (design doc §3.1).
#[derive(Serialize)]
pub struct CreateOutput {
    pub status: String,
    pub directory: String,
    pub image: String,
    pub version: String,
    pub digest: String,
    pub size_bytes: u64,
    pub files: Vec<String>,
}

/// Format a byte count as a human-readable string (e.g., "2.0 GiB").
fn format_bytes(bytes: u64) -> String {
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    const KIB: u64 = 1024;

    if bytes >= GIB {
        format!("{:.1} GiB", bytes as f64 / GIB as f64)
    } else if bytes >= MIB {
        format!("{:.1} MiB", bytes as f64 / MIB as f64)
    } else if bytes >= KIB {
        format!("{:.1} KiB", bytes as f64 / KIB as f64)
    } else {
        format!("{} B", bytes)
    }
}

/// Internal result of the bundle creation pipeline.
struct BundleResult {
    manifest: BundleManifest,
    tarball_filename: String,
    digest: String,
    size_bytes: u64,
}

/// Core bundle creation pipeline — shared by human and JSON output modes.
/// When `json` is true, progress bars are suppressed so stdout is clean for JSON output.
fn create_bundle(image: &str, output: &Path, notes: &str, target_device: &str, json: bool) -> Result<BundleResult, BundleError> {
    // 1. Validate inputs

    // Check skopeo is in PATH
    let skopeo_check = Command::new("skopeo").arg("--version").output();
    match skopeo_check {
        Err(_) => return Err(BundleError::SkopeoNotAvailable),
        Ok(result) if !result.status.success() => return Err(BundleError::SkopeoNotAvailable),
        Ok(_) => {}
    }

    // Parse image reference to extract version from tag
    let version = match image.rfind(':') {
        Some(pos) => {
            let tag = &image[pos + 1..];
            if tag.is_empty() {
                return Err(BundleError::PullFailed(
                    "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
                ));
            }
            tag.to_string()
        }
        None => {
            return Err(BundleError::PullFailed(
                "image reference must include a tag (e.g., registry/repo:1.2.0)".into(),
            ));
        }
    };

    // Check if output directory already exists and contains a bundle
    if output.exists() {
        if output.join("manifest.json").exists() {
            return Err(BundleError::OutputExists);
        }
    } else {
        fs::create_dir_all(output)?;
    }

    // 2. Pull image via skopeo
    let tarball_filename = format!("edge-os-{}.oci.tar", version);
    let tarball_path = output.join(&tarball_filename);

    // In JSON mode, suppress progress output so stdout is clean for JSON
    let spinner = if json {
        ProgressBar::hidden()
    } else {
        let pb = ProgressBar::new_spinner();
        pb.set_message("Pulling image...");
        pb.enable_steady_tick(std::time::Duration::from_millis(100));
        pb
    };

    let skopeo_output = Command::new("skopeo")
        .arg("copy")
        .arg(format!("docker://{}", image))
        .arg(format!("oci-archive:{}", tarball_path.display()))
        .output()
        .map_err(|e| BundleError::PullFailed(format!("failed to execute skopeo: {}", e)))?;

    spinner.finish_and_clear();

    if !skopeo_output.status.success() {
        let stderr = String::from_utf8_lossy(&skopeo_output.stderr).to_string();
        return Err(BundleError::PullFailed(stderr));
    }

    // 3. Compute SHA256 checksum with progress bar
    let file_size = fs::metadata(&tarball_path)?.len();

    let progress = if json {
        ProgressBar::hidden()
    } else {
        let pb = ProgressBar::new(file_size);
        pb.set_message("Computing checksum...");
        pb.set_style(
            ProgressStyle::default_bar()
                .template("[{bar:40}] {bytes}/{total_bytes} ({eta})")
                .unwrap_or_else(|_| ProgressStyle::default_bar())
                .progress_chars("#>-"),
        );
        pb
    };

    let file = fs::File::open(&tarball_path)?;
    let mut reader = BufReader::new(file);
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 8192];

    loop {
        let bytes_read = reader.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        hasher.update(&buffer[..bytes_read]);
        progress.inc(bytes_read as u64);
    }

    progress.finish_and_clear();

    let hex_digest = format!("{:x}", hasher.finalize());
    let digest = format!("sha256:{}", hex_digest);

    // 4. Get file size (already fetched above)
    let size_bytes = file_size;

    // 5. Write checksums.sha256 (GNU coreutils two-space format)
    let checksum_line = format!("{}  {}\n", hex_digest, tarball_filename);
    fs::write(output.join("checksums.sha256"), &checksum_line)?;

    // 6. Build and write manifest.json
    let manifest = BundleManifest {
        schema_version: "1.0".to_string(),
        created_at: Utc::now(),
        created_by: format!("edgeworks-bundle v{}", env!("CARGO_PKG_VERSION")),
        image: BundleImage {
            reference: image.to_string(),
            file: tarball_filename.clone(),
            digest: digest.clone(),
            size_bytes,
            version,
        },
        target_device: target_device.to_string(),
        notes: notes.to_string(),
    };

    let manifest_json = serde_json::to_string_pretty(&manifest)
        .map_err(|e| BundleError::ManifestInvalid(e.to_string()))?;
    fs::write(output.join("manifest.json"), manifest_json)?;

    Ok(BundleResult {
        manifest,
        tarball_filename,
        digest,
        size_bytes,
    })
}

pub fn run(image: &str, output: &Path, notes: &str, target_device: &str, json: bool) -> Result<(), BundleError> {
    match create_bundle(image, output, notes, target_device, json) {
        Ok(result) => {
            if json {
                // Canonicalize the output directory path to an absolute path
                let abs_dir = fs::canonicalize(output)
                    .unwrap_or_else(|_| output.to_path_buf());

                let out = CreateOutput {
                    status: "ok".to_string(),
                    directory: abs_dir.display().to_string(),
                    image: image.to_string(),
                    version: result.manifest.image.version.clone(),
                    digest: result.digest.clone(),
                    size_bytes: result.size_bytes,
                    files: vec![
                        "manifest.json".to_string(),
                        "checksums.sha256".to_string(),
                        result.tarball_filename.clone(),
                    ],
                };
                println!("{}", serde_json::to_string_pretty(&out).unwrap());
            } else {
                // Human-readable summary (design doc §3.1)
                println!("Bundle created successfully.");
                println!("  Directory: {}", output.display());
                println!("  Image:     {}", image);
                println!("  Size:      {}", format_bytes(result.size_bytes));
                println!("  Digest:    {}", result.digest);
                println!(
                    "  Files:     3 (manifest.json, checksums.sha256, {})",
                    result.tarball_filename
                );
            }
            Ok(())
        }
        Err(e) => {
            if json {
                // In JSON mode, error output goes to stdout as JSON (not stderr)
                let err_out = serde_json::json!({
                    "status": "error",
                    "message": e.to_string()
                });
                println!("{}", serde_json::to_string_pretty(&err_out).unwrap());
                std::process::exit(1);
            } else {
                Err(e)
            }
        }
    }
}
