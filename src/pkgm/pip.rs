use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Pip;

impl PackageManager for Pip {
    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pip")
            .arg("install")
            .args(packages)
            .args(&options.args)
            .status()
            .context("pip install failed")?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pip")
            .arg("uninstall")
            .args(packages)
            .args(&options.args)
            .arg("-y") // 自动确认
            .status()
            .context("pip uninstall failed")?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("pip");
        cmd.arg("install").arg("--upgrade");
        if !packages.is_empty() {
            cmd.args(packages);
        }
        cmd.args(&options.args)
            .status()
            .context("pip upgrade failed")?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("pip")
            .args(["list", "--format=json"])
            .output()
            .context("Failed to get pip packages")?;

        parse_pip_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_pip_output(output: &str) -> Result<Vec<DependencyInfo>> {
    #[derive(serde::Deserialize)]
    struct PipPackage {
        name: String,
        version: String,
    }

    let packages: Vec<PipPackage> = serde_json::from_str(output)?;
    Ok(packages
        .into_iter()
        .map(|pkg| DependencyInfo {
            name: pkg.name,
            version: pkg.version,
            dependencies: Vec::new(),
        })
        .collect())
}
