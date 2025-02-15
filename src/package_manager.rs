// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           package_manager.rs
// Description:    About Web package install
// Create   Date:  2025-02-15 11:28:47
// Last Modified:  2025-02-15 12:45:03
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::path::Path;

use std::process::Command;
use colored::Colorize;

use crate::utils::{error_message, info_message, success_message, warning_message};

// 检测锁文件优先级
const LOCK_FILES: [(&str, &str); 4] = [
    ("bun.lockb", "bun"),
    ("pnpm-lock.yaml", "pnpm"),
    ("yarn.lock", "yarn"),
    ("package-lock.json", "npm"),
];

pub fn detect_manager() -> Option<&'static str> {
    for (file, manager) in LOCK_FILES {
        if Path::new(file).exists() {
            return Some(manager);
        }
    }
    None
}

pub fn install_dependencies(frozen: bool) -> Result<(), String> {
    // 检查package.json
    if !Path::new("package.json").exists() {
        return Err(error_message("No package.json file found"));
    }

    let manager = match detect_manager() {
        Some(m) => m,
        None => {
            println!("{}", warning_message("No lockfile detected, using npm by default"));
            "npm"
        }
    };
    println!("{} {}", info_message("Detected package manager:"), manager.cyan());

    let mut command = Command::new(manager);

    match manager {
        "npm" | "bun" => {
            command.arg("install");
            if frozen {
                command.arg("--frozen-lockfile");
            }
        },
        "pnpm" => {
            command.arg("install");
            if frozen {
                command.arg("--frozen-lockfile");
            }
        },
        "yarn" => {
            if frozen {
                command.arg("install --immutable");
            } else {
                command.arg("install");
            }
        },
        _ => return Err(error_message("Unsupported package manager")),
    }

    let status = command.status()
        .map_err(|e| error_message(&format!("Failed to execute command: {}", e)))?;

    if status.success() {
        println!("{}", success_message("Dependencies installed successfully"));
        Ok(())
    } else {
        Err(error_message("Failed to install dependencies"))
    }
}

/// Add package
pub fn add_package(package: &str, dev: bool) -> Result<(), String> {
    let manager = detect_manager().unwrap_or("npm");

    let mut command = Command::new(manager);
    match manager {
        "npm" | "bun" => {
            command.arg("install").arg(package);
            if dev {
                command.arg("--save-dev");
            }
        },
        "pnpm" => {
            command.arg("add").arg(package);
            if dev {
                command.arg("--save-dev");
            }
        },
        "yarn" => {
            command.arg("add").arg(package);
            if dev {
                command.arg("--dev");
            }
        },
        _ => return Err(error_message("Unsupported package manager")),
    }

    let status = command.status()
        .map_err(|e| error_message(&format!("Failed to execute command: {}", e)))?;

    if status.success() {
        println!("{}", success_message("Package added successfully"));
        Ok(())
    } else {
        Err(error_message("Failed to add package"))
    }
}

/// Upgrade package
pub fn upgrade_package(package: Option<&str>) -> Result<(), String> {
    let manager = detect_manager().unwrap_or("npm");

    let mut command = Command::new(manager);
    match manager {
        "npm" | "bun" => {
            command.arg("install");
            if let Some(pkg) = package {
                command.arg(pkg);
            }
        },
        "pnpm" => {
            command.arg("upgrade");
            if let Some(pkg) = package {
                command.arg(pkg);
            }
        },
        "yarn" => {
            command.arg("upgrade");
            if let Some(pkg) = package {
                command.arg(pkg);
            }
        },
        _ => return Err(error_message("Unsupported package manager")),
    }

    let status = command.status()
        .map_err(|e| error_message(&format!("Failed to execute command: {}", e)))?;

    if status.success() {
        println!("{}", success_message("Package upgraded successfully"));
        Ok(())
    } else {
        Err(error_message("Failed to upgrade package"))
    }
}

/// Remove package
pub fn remove_package(package: &str) -> Result<(), String> {
    let manager = detect_manager().unwrap_or("npm");

    let mut command = Command::new(manager);
    match manager {
        "npm" | "bun" => {
            command.arg("uninstall").arg(package);
        },
        "pnpm" => {
            command.arg("remove").arg(package);
        },
        "yarn" => {
            command.arg("remove").arg(package);
        },
        _ => return Err(error_message("Unsupported package manager")),
    }

    let status = command.status()
        .map_err(|e| error_message(&format!("Failed to execute command: {}", e)))?;

    if status.success() {
        println!("{}", success_message("Package removed successfully"));
        Ok(())
    } else {
        Err(error_message("Failed to remove package"))
    }
}

/// Analyze package dependencies
pub fn analyze_dependencies() -> Result<(), String> {
    let manager = detect_manager().unwrap_or("npm");

    let mut command = Command::new(manager);
    match manager {
        "npm" | "bun" => {
            command.arg("list");
        },
        "pnpm" => {
            command.arg("list");
        },
        "yarn" => {
            command.arg("list");
        },
        _ => return Err(error_message("Unsupported package manager")),
    }

    let status = command.status()
        .map_err(|e| error_message(&format!("Failed to execute command: {}", e)))?;

    if status.success() {
        println!("{}", success_message("Dependencies analyzed successfully"));
        Ok(())
    } else {
        Err(error_message("Failed to analyze dependencies"))
    }
}
