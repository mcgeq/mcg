use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Pip;

impl PackageManager for Pip {
    fn name(&self) -> &'static str {
        "pip"
    }

    fn format_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> String {
        let cmd = match command {
            "add" => "install",
            "remove" => "uninstall",
            "upgrade" => "install --upgrade",
            "analyze" => "list",
            _ => command,
        };
        let mut args = vec!["pip".to_string(), cmd.to_string()];
        args.extend(packages.iter().cloned());
        args.extend(options.args.clone());
        args.join(" ")
    }

    fn execute_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> Result<()> {
        let cmd = match command {
            "add" => "install",
            "remove" => "uninstall",
            "upgrade" => "install --upgrade",
            "analyze" => "list",
            _ => command,
        };
        Command::new("pip")
            .arg(cmd)
            .args(packages)
            .args(&options.args)
            .status()?;
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
