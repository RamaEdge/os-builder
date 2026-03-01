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
        Commands::Create { image, output, notes, target_device } => {
            create::run(image, output, notes, target_device, cli.json)
        }
        Commands::Verify { path } => verify::run(path),
        Commands::Inspect { path } => inspect::run(path),
    };

    if let Err(e) = result {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }
}
