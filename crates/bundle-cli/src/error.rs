use thiserror::Error;

#[derive(Error, Debug)]
pub enum BundleError {
    #[error("not yet implemented")]
    NotImplemented,

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}
