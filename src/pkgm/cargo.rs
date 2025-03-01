use super::types::{PackageManager, PackageOptions};
use anyhow::Result;
use std::process::Command;

pub struct Cargo;

impl PackageManager for Cargo {
    fn name(&self) -> &'static str {
        "cargo"
    }

    fn format_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> String {
        let mut cmd = vec!["cargo".to_string(), command.to_string()];
        cmd.extend(packages.iter().cloned());
        cmd.extend(options.args.clone());
        cmd.join(" ")
    }

    fn execute_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> Result<()> {
        Command::new("cargo")
            .arg(command)
            .args(packages)
            .args(&options.args)
            .status()?;
        Ok(())
    }

    fn analyze(&self, packages: &[String], options: &PackageOptions) -> Result<String> {
        let mut cmd = Command::new("cargo");
        cmd.arg("tree");

        if !packages.is_empty() {
            cmd.arg("--package").arg(&packages[0]);
        }

        cmd.args(&options.args);

        let output = cmd.output()?;
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}
