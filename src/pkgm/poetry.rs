use super::types::{PackageManager, PackageOptions};
use anyhow::Result;
use std::process::Command;

pub struct Poetry;

impl PackageManager for Poetry {
    fn name(&self) -> &'static str {
        "poetry"
    }

    fn format_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> String {
        let mut cmd = vec!["poetry".to_string(), get_command(command)];
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
        Command::new("poetry")
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
        "analyze" => "show".to_string(),
        _ => cmd.to_string(),
    }
}
