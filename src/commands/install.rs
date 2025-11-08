use crate::pkgm::{PackageOptions, detect};
use anyhow::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct InstallArgs {}

impl InstallArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;

        let options = PackageOptions::new(vec![]);
        crate::pkgm::execute_with_prompt(&*manager, "install", &[], &options)
    }
}
