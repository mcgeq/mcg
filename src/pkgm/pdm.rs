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

    fn analyze(&self, packages: &[String], options: &PackageOptions) -> Result<String> {
        let mut cmd = Command::new("pdm");
        cmd.arg("list");

        // 添加包名（如果指定）
        if !packages.is_empty() {
            cmd.arg(&packages[0]);
        }

        // 添加其他参数
        cmd.args(&options.args);

        let output = cmd.output()?;
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    }
}
