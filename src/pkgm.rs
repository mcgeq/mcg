mod cargo;
mod detect;
mod manager;
mod npm;
mod pdm;
mod pip;
mod pnpm;
mod poetry;
mod types;
mod yarn;

pub use detect::detect;
pub use manager::execute_with_prompt;
pub use types::PackageOptions;
