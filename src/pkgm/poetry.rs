use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Poetry;

impl PackageManager for Poetry {
    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("poetry")
            .arg("add")
            .args(packages)
            .args(&options.args)
            .status()
            .context("poetry add failed")?;
        Ok(())
    }

    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        Command::new("poetry")
            .arg("remove")
            .args(packages)
            .args(&options.args)
            .status()
            .context("poetry remove failed")?;
        Ok(())
    }

    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()> {
        let mut cmd = Command::new("poetry");
        cmd.arg("update");
        if !packages.is_empty() {
            cmd.args(packages);
        }
        cmd.args(&options.args)
            .status()
            .context("poetry update failed")?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("poetry")
            .args(["show", "--tree"])
            .output()
            .context("Failed to get poetry dependencies")?;

        parse_poetry_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_poetry_output(output: &str) -> Result<Vec<DependencyInfo>> {
    let mut dependencies = Vec::new();
    let mut current_dep: Option<DependencyInfo> = None;

    for line in output.lines() {
        if let Some(name_version) = line.split_whitespace().next() {
            let parts: Vec<&str> = name_version.splitn(2, "==").collect();
            if parts.len() == 2 {
                if let Some(dep) = current_dep.take() {
                    dependencies.push(dep);
                }
                current_dep = Some(DependencyInfo {
                    name: parts[0].to_string(),
                    version: parts[1].to_string(),
                    dependencies: Vec::new(),
                });
            } else if let Some(dep) = &mut current_dep {
                dep.dependencies.push(name_version.to_string());
            }
        }
    }

    if let Some(dep) = current_dep.take() {
        dependencies.push(dep);
    }

    Ok(dependencies)
}
