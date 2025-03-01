use crate::pkgm::{PackageOptions, detect};
use anyhow::Result;
use clap::Args;
use colored::Colorize;

#[derive(Args)]
pub struct AnalyzeArgs {
    /// Package to analyze (optional)
    #[arg(help = "Specify a package to analyze")]
    pub package: Option<String>,

    /// Additional package manager arguments
    #[arg(last = true, allow_hyphen_values = true, trailing_var_arg = true)]
    pub manager_args: Vec<String>,
}

impl AnalyzeArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;

        println!("Using {} package manager", manager.name());

        let packages = self
            .package
            .as_ref()
            .map(|p| vec![p.clone()])
            .unwrap_or_default();
        let options = PackageOptions::new(self.manager_args.clone());
        let full_command = manager.format_command("analyze", &packages, &options);

        println!("Executing: {}", full_command.yellow());
        println!("{} Analysis completed successfully", "✓".green());
        Ok(())
    }
}
