use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Yarn;

impl PackageManager for Yarn {
    fn name(&self) -> &'static str {
        "yarn"
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
            "upgrade" => "upgrade",
            "analyze" => "list",
            _ => command,
        };
        let mut args = vec!["yarn".to_string(), cmd.to_string()];
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
            "upgrade" => "upgrade",
            "analyze" => "list",
            _ => command,
        };
        Command::new("yarn")
            .arg(cmd)
            .args(packages)
            .args(&options.args)
            .status()?;
        Ok(())
    }

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("yarn")
            .args(["list", "--depth=0"])
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
