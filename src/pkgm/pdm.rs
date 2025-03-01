use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Pdm;

impl PackageManager for Pdm {
    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pdm")
            .arg("add")
            .args(packages)
            .args(&options.args)
            .status()
            .context("pdm add failed")?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("pdm")
            .arg("remove")
            .args(packages)
            .args(&options.args)
            .status()
            .context("pdm remove failed")?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("pdm");
        cmd.arg("update");
        if !packages.is_empty() {
            cmd.args(packages);
        }
        cmd.args(&options.args)
            .status()
            .context("pdm update failed")?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("pdm")
            .args(["list", "--json"])
            .output()
            .context("Failed to get pdm dependencies")?;

        parse_pdm_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_pdm_output(output: &str) -> Result<Vec<DependencyInfo>> {
    #[derive(serde::Deserialize)]
    struct PdmPackage {
        name: String,
        version: String,
        dependencies: Vec<String>,
    }

    let packages: Vec<PdmPackage> = serde_json::from_str(output)?;
    Ok(packages
        .into_iter()
        .map(|pkg| DependencyInfo {
            name: pkg.name,
            version: pkg.version,
            dependencies: pkg.dependencies,
        })
        .collect())
}
