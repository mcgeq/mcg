use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};

use anyhow::Result;

pub struct Cargo;

impl PackageManager for Cargo {
    fn detect() -> bool
    where
        Self: Sized,
    {
        Path::new("Cargo.toml").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("cargo");
        cmd.arg("add").args(packages).args(&options.manager_args);
        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("cargo")
            .arg("remove")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("cargo")
            .arg("upgrade")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("cargo")
            .args(["tree", "--depth", "1"])
            .status()?;
        Ok(())
    }
}
