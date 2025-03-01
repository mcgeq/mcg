use crate::pkgm::{detect, PackageOptions};
use anyhow::Result;
use clap::Args;
use colored::Colorize;

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

        manager.add(&self.packages, &options).map(|_| {
            println!("{} Successfully added packages", "✓".green());
        })
    }
}
