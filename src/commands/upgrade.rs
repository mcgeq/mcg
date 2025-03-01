use crate::pkgm::{PackageOptions, detect};
use anyhow::Result;
use clap::Args;

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

        crate::pkgm::execute_with_prompt(&*manager, "upgrade", &self.packages, &options)
    }
}
