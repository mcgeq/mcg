use crate::pkgm::{PackageOptions, detect};
use anyhow::Result;
use clap::Args;

#[derive(Args)]
pub struct AnalyzeArgs {
    /// Package to analyze (optional)
    #[arg(help = "Specify a package to analyze")]
    pub package: Vec<String>,

    /// Additional package manager arguments
    #[arg(last = true, allow_hyphen_values = true, trailing_var_arg = true)]
    pub manager_args: Vec<String>,
}

impl AnalyzeArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;

        println!("Using {} package manager", manager.name());

        let options = PackageOptions::new(self.manager_args.clone());
        crate::pkgm::execute_with_prompt(&*manager, "analyze", &self.package, &options)
    }
}
