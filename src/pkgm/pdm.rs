use super::types::{PackageManager, PackageOptions};
use anyhow::Result;
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
        let mut args = vec!["pdm".to_string(), get_command(command)];
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
        Command::new("pdm")
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
        "install" => "install".to_string(),
        "remove" => "remove".to_string(),
        "upgrade" => "update".to_string(),
        "analyze" => "list".to_string(),
        _ => cmd.to_string(),
    }
}
