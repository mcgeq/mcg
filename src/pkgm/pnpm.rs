use std::{path::Path, process::Command};

use super::{manager::PackageManager, PackageOptions};

use anyhow::Result;

pub struct Pnpm;

impl PackageManager for Pnpm {
    fn detect() -> bool
    where
        Self: Sized,
    {
        Path::new("pnpm-lock.yaml").exists()
    }

    fn add(
        &self,
        packages: &[String],
        options: &super::manager::PackageOptions,
    ) -> anyhow::Result<()> {
        let mut cmd = Command::new("pnpm");
        cmd.arg("add").args(packages).args(&options.manager_args);
        cmd.status()?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pnpm")
            .arg("remove")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pnpm")
            .arg("upgrade")
            .args(packages)
            .args(&options.manager_args)
            .status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<()> {
        Command::new("pnpm").args(["list"]).status()?;
        Ok(())
    }
}
