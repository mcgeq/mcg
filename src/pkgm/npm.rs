use super::types::{PackageManager, PackageOptions};
use anyhow::Result;
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

    fn analyze(&self, packages: &[String], options: &PackageOptions) -> Result<String> {
        let mut cmd = Command::new("npm");
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
