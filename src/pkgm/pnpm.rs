use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Pnpm;

impl PackageManager for Pnpm {
    fn name(&self) -> &'static str {
        "pnpm"
    }

    fn format_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> String {
        let cmd = match command {
            "add" => "add",
            "remove" => "remove",
            "upgrade" => "update",
            "analyze" => "list",
            _ => command,
        };
        let mut args = vec!["pnpm".to_string(), cmd.to_string()];
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
            "add" => "add",
            "remove" => "remove",
            "upgrade" => "update",
            "analyze" => "list",
            _ => command,
        };
        Command::new("pnpm")
            .arg(cmd)
            .args(packages)
            .args(&options.args)
            .status()?;
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
