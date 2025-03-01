use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Pnpm;

impl PackageManager for Pnpm {
    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pnpm")
            .arg("add")
            .args(packages)
            .args(&options.args)
            .status()
            .context("pnpm add failed")?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pnpm")
            .arg("remove")
            .args(packages)
            .args(&options.args)
            .status()
            .context("pnpm remove failed")?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("pnpm");
        cmd.arg("update");
        if !packages.is_empty() {
            cmd.args(packages);
        }
        cmd.args(&options.args)
            .status()
            .context("pnpm update failed")?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("pnpm")
            .args(["list"])
            .output()
            .context("Failed to get pnpm dependencies")?;

        parse_pnpm_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_pnpm_output(output: &str) -> Result<Vec<DependencyInfo>> {
    #[derive(serde::Deserialize)]
    struct PnpmPackage {
        name: String,
        version: String,
    }

    let packages: Vec<PnpmPackage> = serde_json::from_str(output)?;
    Ok(packages
        .into_iter()
        .map(|pkg| DependencyInfo {
            name: pkg.name,
            version: pkg.version,
            dependencies: Vec::new(),
        })
        .collect())
}
