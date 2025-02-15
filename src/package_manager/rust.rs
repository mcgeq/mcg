// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           rust.rs
// Description:    About Rust Project.
// Create   Date:  2025-02-15 13:40:24
// Last Modified:  2025-02-15 14:27:35
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::process::Command;
use crate::utils::{error_message, info_message, success_message};

pub fn install() -> Result<(), String> {
    println!("{}", info_message("Detected Rust project"));
    Command::new("cargo")
        .arg("build")
        .status()
        .map(|_| println!("{}", success_message("Rust dependencies installed")))
        .map_err(|e| error_message(&format!("Build failed: {}", e)))
}

pub fn add_package(package: &str) -> Result<(), String> {
    Command::new("cargo")
        .arg("add")
        .arg(package)
        .status()
        .map(|_| println!("{}", success_message(&format!("Added crate: {}", package))))
        .map_err(|e| error_message(&format!("Failed to add crate: {}", e)))
}

pub fn upgrade_package(package: Option<&str>) -> Result<(), String> {
    let mut cmd = Command::new("cargo");
    cmd.arg("upgrade");

    if let Some(pkg) = package {
        cmd.arg(pkg);
    }
    cmd.status()
        .map(|_| println!("{}", success_message("Crates upgraded")))
        .map_err(|e| error_message(&format!("Upgrade failed: {}", e)))
}

pub fn remove_package(package: &str) -> Result<(), String> {
    Command::new("cargo")
        .arg("remove")
        .arg(package)
        .status()
        .map(|_| println!("{}", success_message(&format!("Removed crate: {}", package))))
        .map_err(|e| error_message(&format!("Remove failed: {}", e)))
}

pub fn analyze_dependencies() -> Result<(), String> {
    Command::new("cargo")
        .arg("tree")
        .status()
        .map(|_| println!("{}", success_message("Dependencies analyzed")))
        .map_err(|e| error_message(&format!("Analyze failed: {}", e)))
}
