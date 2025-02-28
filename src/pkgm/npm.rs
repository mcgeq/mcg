use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};

use anyhow::Result;

pub struct Npm;

impl PackageManager for Npm {
    fn detect() -> bool
    where
        Self: Sized,
    {
        Path::new("package-lock.yaml").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("npm");
        cmd.arg("install")
            .args(packages)
            .args(&options.manager_args);

        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("npm")
            .arg("uninstall")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("npm");
        cmd.arg("update");

        if !packages.is_empty() {
            cmd.args(packages);
        }

        cmd.args(&options.manager_args).status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("npm").args(["list", "--depth=0"]).status()?;
        Ok(())
    }
}
