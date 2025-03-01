use super::types::{DependencyInfo, PackageManager, PackageOptions};
use anyhow::{Result, bail};
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

    fn analyze(&self) -> Result<Vec<DependencyInfo>> {
        let output = Command::new("cargo").args(["tree", "--depth=1"]).output()?;

        parse_cargo_output(&String::from_utf8_lossy(&output.stdout))
    }
}

fn parse_cargo_output(output: &str) -> Result<Vec<DependencyInfo>> {
    let deps: Vec<DependencyInfo> = output
        .lines() // 将 &str 按行分割
        .filter_map(parse_single_cargo_line)
        .collect();
    if deps.is_empty() {
        bail!("No valid dependencies found in Cargo output");
    }
    Ok(deps)
}

// 辅助函数：解析单行
fn parse_single_cargo_line(line: &str) -> Option<DependencyInfo> {
    let trimmed = line.trim_start_matches(['├', '└', '│', '─', ' ']).trim();
    if trimmed.contains("[build-dependencies]") || trimmed.is_empty() {
        return None;
    }
    let parts: Vec<&str> = trimmed.split_whitespace().collect();
    if parts.len() >= 2 {
        let version = if parts[1].starts_with('v') {
            &parts[1][1..]
        } else {
            parts[1]
        };
        Some(DependencyInfo {
            name: parts[0].to_string(),
            version: version.to_string(),
            dependencies: Vec::new(), // depth=1 不包含嵌套依赖
        })
    } else {
        None
    }
}
