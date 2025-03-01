use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Pdm;

impl PackageManager for Pdm {
    fn name(&self) -> &'static str {
        "pdm"
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
        let mut args = vec!["pdm".to_string(), cmd.to_string()];
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
        Command::new("pdm")
            .arg(cmd)
            .args(packages)
            .args(&options.args)
            .status()?;
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
