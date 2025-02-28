use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};
use anyhow::Result;

pub struct Pdm;

impl PackageManager for Pdm {
    fn detect() -> bool
    where
        Self: Sized,
    {
        Path::new("pyproject.toml").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("pdm");
        cmd.arg("add").args(packages).args(&options.manager_args);
        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pdm")
            .arg("remove")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pdm")
            .arg("update")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("pdm").args(["list"]).status()?;
        Ok(())
    }
}
