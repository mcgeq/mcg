use snafu::{Backtrace, Snafu};
use std::path::PathBuf;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, Snafu)]
#[snafu(visibility(pub))]
pub enum Error {
    #[snafu(display("Package manager not detected in current directory"))]
    ManagerNotDetected { backtrace: Backtrace },

    #[snafu(display("Unsupported package manager: {}", name))]
    UnsupportedManager { name: String, backtrace: Backtrace },

    #[snafu(display("Command execution failed: {} (exit code: {})", command, code))]
    CommandFailed {
        command: String,
        code: i32,
        backtrace: Backtrace,
    },

    #[snafu(display("Package manager '{}' not found. Please install it first", manager))]
    ManagerNotInstalled {
        manager: String,
        source: std::io::Error,
    },

    #[snafu(display("Failed to read config file at {}: {}", path.display(), source))]
    ConfigReadFailed {
        path: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Failed to parse config file at {}: {}", path.display(), source))]
    ConfigParseFailed {
        path: PathBuf,
        source: toml::de::Error,
    },

    #[snafu(display("Invalid package name: {}", name))]
    InvalidPackageName { name: String, backtrace: Backtrace },

    #[snafu(display("Failed to get current directory: {}", source))]
    CurrentDirFailed {
        source: std::io::Error,
    },

    #[snafu(display("I/O error at {}: {}", path.display(), source))]
    #[allow(dead_code)]
    IoError {
        path: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Failed to create directory at {}: {}", path.display(), source))]
    CreateDirFailed {
        path: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Failed to create file at {}: {}", path.display(), source))]
    CreateFileFailed {
        path: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Failed to remove path at {}: {}", path.display(), source))]
    RemoveFailed {
        path: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Failed to copy from {} to {}: {}", from.display(), to.display(), source))]
    CopyFailed {
        from: PathBuf,
        to: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Failed to move from {} to {}: {}", from.display(), to.display(), source))]
    MoveFailed {
        from: PathBuf,
        to: PathBuf,
        source: std::io::Error,
    },

    #[snafu(display("Path not found: {}", path.display()))]
    PathNotFound { path: PathBuf, backtrace: Backtrace },
}
