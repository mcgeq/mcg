use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};

use anyhow::Result;

pub struct Poetry;

impl PackageManager for Poetry {
    fn detect() -> bool {
        Path::new("pyproject.toml").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("poetry");
        cmd.arg("add").args(packages).args(&options.manager_args);
        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("poetry")
            .arg("remove")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("poetry");
        cmd.arg("update");

        if !packages.is_empty() {
            cmd.args(packages);
        }

        cmd.args(&options.manager_args).status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("poetry").args(["show", "--tree"]).status()?;
        Ok(())
    }
}
