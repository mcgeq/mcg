use crate::pkgm::{detect, PackageOptions};
use anyhow::Result;
use clap::Args;
use colored::Colorize;

#[derive(Args)]
pub struct UpgradeArgs {
    #[arg(help = "Packages to upgrade (empty for all)")]
    pub packages: Vec<String>,

    #[arg(last = true, help = "Package manager specific arguments")]
    pub manager_args: Vec<String>,
}

impl UpgradeArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;
        let options = PackageOptions::new(self.manager_args.clone());

        manager.upgrade(&self.packages, &options).map(|_| {
            println!("{} Successfully upgraded packages", "✓".green());
        })
    }
}
