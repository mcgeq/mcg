use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};
use anyhow::Result;

pub struct Yarn;

impl PackageManager for Yarn {
    fn detect() -> bool
    where
        Self: Sized,
    {
        Path::new("yarn-lock.yaml").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("yarn");
        cmd.arg("add").args(packages).args(&options.manager_args);

        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("yarn")
            .arg("remove")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("yarn")
            .arg("upgrade")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("yarn").args(["list"]).status()?;
        Ok(())
    }
}
