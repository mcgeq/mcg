// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           python.rs
// Description:    About Python Project
// Create   Date:  2025-02-15 13:39:56
// Last Modified:  2025-02-15 14:27:46
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::process::Command;

use crate::utils::{error_message, info_message, success_message};

pub fn install() -> Result<(), String> {
    println!("{}", info_message("Detected Python project"));
    let status = Command::new("pip")
        .arg("install")
        .arg("-r")
        .arg("requirements.txt")
        .status()
        .map_err(|e| error_message(&format!("Failed to install: {}", e)))?;

    if status.success() {
        println!("{}", success_message("Python dependencies installed"));
        Ok(())
    } else {
        Err(error_message("Installation failed"))
    }
}

pub fn add_package(package: &str, dev: bool) -> Result<(), String> {
    let mut cmd = Command::new("pip");
    cmd.arg("install").arg(package);
    if dev {
        // 假设使用 requirements-dev.txt
        return Err(error_message(
            "Python dev dependencies require manual handling",
        ));
    }

    cmd.status()
        .map(|_| {
            println!(
                "{}",
                success_message(&format!("Added package: {}", package))
            )
        })
        .map_err(|e| error_message(&format!("Failed to add package: {}", e)))
}

pub fn upgrade_package(package: Option<&str>) -> Result<(), String> {
    let mut cmd = Command::new("pip");
    cmd.arg("install").arg("--upgrade");
    if let Some(pkg) = package {
        cmd.arg(pkg);
    }
    cmd.status()
        .map(|_| println!("{}", success_message("Packages upgraded")))
        .map_err(|e| error_message(&format!("Upgrade failed: {}", e)))
}

pub fn remove_package(package: &str) -> Result<(), String> {
    Command::new("pip")
        .arg("uninstall")
        .arg(package)
        .status()
        .map(|_| println!("{}", success_message(&format!("Removed package: {}", package))))
        .map_err(|e| error_message(&format!("Remove failed: {}", e)))
}

pub fn analyze_dependencies() -> Result<(), String> {
    Command::new("pip")
        .arg("list")
        .status()
        .map(|_| println!("{}", success_message("Dependencies analyzed")))
        .map_err(|e| error_message(&format!("Analyze failed: {}", e)))
}
