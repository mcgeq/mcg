// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           package_manager.rs
// Description:    About Web package install
// Create   Date:  2025-02-15 11:28:47
// Last Modified:  2025-02-15 14:27:17
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

pub mod frontend;
pub mod python;
pub mod rust;

use std::path::Path;

use crate::utils::error_message;


// 检测项目类型
pub enum ProjectType {
    Frontend,
    Python,
    Rust,
    Unknown,
}

pub fn detect_project_type() -> ProjectType {
    if Path::new("package.json").exists() {
        ProjectType::Frontend
    } else if Path::new("Cargo.toml").exists() {
        ProjectType::Rust
    } else if Path::new("requirements.txt").exists() || Path::new("pyproject.toml").exists() {
        ProjectType::Python
    } else {
        ProjectType::Unknown
    }
}

// 统一函数入口
pub fn install_dependencies(frozen: bool) -> Result<(), String> {
    match detect_project_type() {
        ProjectType::Frontend => frontend::install(frozen),
        ProjectType::Python => python::install(),
        ProjectType::Rust => rust::install(),
        ProjectType::Unknown => Err(error_message("No support project detected")),
    }
}

pub fn add_package(package: &str, dev: bool) -> Result<(), String> {
    match detect_project_type() {
        ProjectType::Frontend => frontend::add_package(package, dev),
        ProjectType::Python => python::add_package(package, dev),
        ProjectType::Rust => rust::add_package(package),
        ProjectType::Unknown => Err(error_message("No support project detected")),
    }
}

pub fn upgrade_package(package: Option<&str>) -> Result<(), String> {
    match detect_project_type() {
        ProjectType::Frontend => frontend::upgrade_package(package),
        ProjectType::Python => python::upgrade_package(package),
        ProjectType::Rust => rust::upgrade_package(package),
        ProjectType::Unknown => Err(error_message("No support project detected")),
    }
}

pub fn remove_package(package: &str) -> Result<(), String> {
    match detect_project_type() {
        ProjectType::Frontend => frontend::remove_package(package),
        ProjectType::Python => python::remove_package(package),
        ProjectType::Rust => rust::remove_package(package),
        ProjectType::Unknown => Err(error_message("No support project detected")),
    }
}

pub fn analyze_dependencies() -> Result<(), String> {
    match detect_project_type() {
        ProjectType::Frontend => frontend::analyze_dependencies(),
        ProjectType::Python => python::analyze_dependencies(),
        ProjectType::Rust => rust::analyze_dependencies(),
        ProjectType::Unknown => Err(error_message("No support project detected")),
    }
}
