use anyhow::Result;
use clap::Args;

use crate::pkgm::{PackageManager, PackageOptions};

#[derive(Args)]
pub struct AddArgs {
    /// Package to add
    packages: Vec<String>,

    /// Additional arguments for package manager
    #[arg(last = true)]
    manager_args: Vec<String>,
}

impl AddArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = PackageManager::detect()?;
        let options = PackageOptions {
            manager_args: self.manager_args.clone(),
        };
        manager.add(&self.packages, &options)
    }
}
