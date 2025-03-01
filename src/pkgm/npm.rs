use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Context, Result};
use std::process::Command;

pub struct Npm;

impl PackageManager for Npm {
    fn name(&self) -> &'static str {
        "npm"
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
            "upgrade" => "update",
            "analyze" => "list",
            _ => command,
        };
        let mut args = vec!["npm".to_string(), cmd.to_string()];
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
            "upgrade" => "update",
            "analyze" => "list",
            _ => command,
        };
        Command::new("npm")
            .arg(cmd)
            .args(packages)
            .args(&options.args)
            .status()?;
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
