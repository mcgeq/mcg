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
        let mut args = vec!["cargo".to_string(), get_command(command)];
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
        Command::new("cargo")
            .arg(get_command(command))
            .args(packages)
            .args(&options.args)
            .status()?;
        Ok(())
    }
}

fn get_command(cmd: &str) -> String {
    match cmd {
        "add" => "add".to_string(),
        "install" => "check".to_string(),
        "remove" => "remove".to_string(),
        "upgrade" => "update".to_string(),
        "analyze" => "tree".to_string(),
        _ => cmd.to_string(),
    }
}
