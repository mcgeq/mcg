use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};

use anyhow::Result;

pub struct Pip;

impl PackageManager for Pip {
    fn detect() -> bool
    where
        Self: Sized,
    {
        Path::new("requements.txt").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("pip");
        cmd.arg("install")
            .args(packages)
            .args(&options.manager_args);
        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pip")
            .arg("uninstall")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pip")
            .arg("install")
            .arg("--upgrade")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("pip").args(["list"]).status()?;
        Ok(())
    }
}
