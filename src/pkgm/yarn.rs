use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Yarn;

impl PackageManager for Yarn {
    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("yarn")
            .arg("add")
            .args(packages)
            .args(&options.args)
            .status()
            .context("yarn add failed")?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("yarn")
            .arg("remove")
            .args(packages)
            .args(&options.args)
            .status()
            .context("yarn remove failed")?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("yarn");
        cmd.arg("upgrade");
        if !packages.is_empty() {
            cmd.args(packages);
        }
        cmd.args(&options.args)
            .status()
            .context("yarn upgrade failed")?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("yarn")
            .args(["list", "--json", "--depth=0"])
            .output()
            .context("Failed to get yarn dependencies")?;

        parse_yarn_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_yarn_output(output: &str) -> Result<Vec<DependencyInfo>> {
    #[derive(serde::Deserialize)]
    struct YarnPackage {
        name: String,
        version: String,
    }

    let packages: Vec<YarnPackage> = output
        .lines()
        .filter_map(|line| serde_json::from_str::<YarnPackage>(line).ok())
        .collect();

    Ok(packages
        .into_iter()
        .map(|pkg| DependencyInfo {
            name: pkg.name,
            version: pkg.version,
            dependencies: Vec::new(),
        })
        .collect())
}
