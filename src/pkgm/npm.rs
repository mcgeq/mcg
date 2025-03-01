use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Npm;

impl PackageManager for Npm {
    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("npm")
            .arg("install")
            .args(packages)
            .args(&options.args)
            .status()
            .context("Failed to execute npm install")?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("npm")
            .arg("uninstall")
            .args(packages)
            .args(&options.args)
            .status()
            .context("npm uninstall failed")?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("npm");
        cmd.arg("update");
        if !packages.is_empty() {
            cmd.args(packages);
        }
        cmd.args(&options.args)
            .status()
            .context("npm update failed")?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("npm")
            .args(["list", "--json", "--depth=0"])
            .output()
            .context("Failed to get npm dependencies")?;

        parse_npm_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_npm_output(output: &str) -> Result<Vec<DependencyInfo>> {
    #[derive(serde::Deserialize)]
    struct NpmDependency {
        version: String,
    }

    #[derive(serde::Deserialize)]
    struct NpmTree {
        dependencies: std::collections::HashMap<String, NpmDependency>,
    }

    let tree: NpmTree = serde_json::from_str(output)?;
    Ok(tree
        .dependencies
        .into_iter()
        .map(|(name, dep)| DependencyInfo {
            name,
            version: dep.version,
            dependencies: Vec::new(),
        })
        .collect())
}
