use crate::pkgm::{PackageOptions, detect};
use anyhow::Result;
use clap::Args;

#[derive(Args)]
pub struct AddArgs {
    /// Packages to install
    #[arg(required = true, num_args = 1..)]
    pub packages: Vec<String>,

    #[arg(
        last = true,
        allow_hyphen_values = true,
        allow_negative_numbers = true,
        value_parser = clap::value_parser!(String),
        help = "Package manager specific arguments"
    )]
    pub manager_args: Vec<String>,
}

impl AddArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;
        let options = PackageOptions::new(self.manager_args.clone());
        crate::pkgm::execute_with_prompt(&*manager, "add", &self.packages, &options)
    }
}
