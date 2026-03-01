use clap::{Parser, Subcommand};
use std::path::PathBuf;

mod create;
mod error;
mod inspect;
mod manifest;
mod verify;

#[derive(Parser)]
#[command(
    name = "edgeworks-bundle",
    version,
    about = "Create, verify, and inspect offline update bundles for air-gapped edge devices"
)]
struct Cli {
    /// Output machine-readable JSON instead of human-friendly text
    #[arg(long, global = true)]
    json: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new bundle from a registry image
    Create {
        /// Full OCI image reference to pull (e.g. registry/repo:tag)
        #[arg(long)]
        image: String,

        /// Output directory path (created if it does not exist)
        #[arg(long)]
        output: PathBuf,

        /// Free-text notes included in the manifest
        #[arg(long, default_value = "")]
        notes: String,

        /// Device filter for the bundle
        #[arg(long, default_value = "any")]
        target_device: String,
    },

    /// Verify an existing bundle's integrity
    Verify {
        /// Path to the bundle directory
        path: PathBuf,
    },

    /// Display bundle metadata without verifying checksums
    Inspect {
        /// Path to the bundle directory
        path: PathBuf,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match &cli.command {
        Commands::Create {
            image,
            output,
            notes,
            target_device,
        } => create::run(image, output, notes, target_device, cli.json),
        Commands::Verify { path } => {
            match verify::run_verify(path) {
                Ok(result) => {
                    if cli.json {
                        print!("{}", verify::format_verify_json(&result, path));
                    } else {
                        print!("{}", verify::format_verify_human(&result, path));
                    }
                    if result.valid {
                        std::process::exit(0);
                    } else {
                        std::process::exit(1);
                    }
                }
                Err(e) => {
                    // Bundle directory not found -> exit 2
                    eprintln!("Error: {e}");
                    std::process::exit(2);
                }
            }
        }
        Commands::Inspect { path } => {
            match inspect::run_inspect(path) {
                Ok(manifest) => {
                    if cli.json {
                        print!("{}", inspect::format_inspect_json(&manifest));
                    } else {
                        print!("{}", inspect::format_inspect_human(&manifest, path));
                    }
                    std::process::exit(0);
                }
                Err(e) => {
                    eprintln!("Error: {e}");
                    // ManifestNotFound means path doesn't exist -> exit 2
                    // ManifestInvalid means bad manifest -> exit 1
                    match e {
                        crate::error::BundleError::ManifestNotFound(_) => std::process::exit(2),
                        _ => std::process::exit(1),
                    }
                }
            }
        }
    };

    if let Err(e) = result {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }
}
