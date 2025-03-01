mod auto_detect;
mod cargo;
mod manager;
mod npm;
mod pdm;
mod pip;
mod pnpm;
mod poetry;
mod yarn;

pub use auto_detect::detect_manager;
pub use manager::{ManagerType, PackageManager, PackageOptions};
