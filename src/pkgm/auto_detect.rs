use std::path::{Path, PathBuf};

use super::{manager::ManagerType, PackageManager};
use anyhow::{bail, Result};

struct DetectionConfig {
    files: &'static [&'static str],
    priority: u8,
}

// 预定义静态数组
const CARGO_FILES: &[&str] = &["Cargo.toml"];
const PNPM_FILES: &[&str] = &["pnpm-lock.yaml"];
const YARN_FILES: &[&str] = &["yarn.lock"];
const NPM_FILES: &[&str] = &["package-lock.json"];
const POETRY_FILES: &[&str] = &["pyproject.toml"];
const PDM_FILES: &[&str] = &["pyproject.toml"];
const PIP_FILES: &[&str] = &["requirements.txt"];

const CONFIGURATIONS: &[(ManagerType, DetectionConfig)] = &[
    (
        ManagerType::Cargo,
        DetectionConfig {
            files: CARGO_FILES,
            priority: 0,
        },
    ),
    (
        ManagerType::Npm,
        DetectionConfig {
            files: NPM_FILES,
            priority: 1,
        },
    ),
    (
        ManagerType::Pnpm,
        DetectionConfig {
            files: PNPM_FILES,
            priority: 2,
        },
    ),
    (
        ManagerType::Yarn,
        DetectionConfig {
            files: YARN_FILES,
            priority: 3,
        },
    ),
    (
        ManagerType::Pip,
        DetectionConfig {
            files: PIP_FILES,
            priority: 4,
        },
    ),
    (
        ManagerType::Pdm,
        DetectionConfig {
            files: PDM_FILES,
            priority: 5,
        },
    ),
    (
        ManagerType::Poetry,
        DetectionConfig {
            files: POETRY_FILES,
            priority: 6,
        },
    ),
];

pub fn detect() -> Result<Box<dyn PackageManager>> {
    let mut candidates = Vec::new();

    for (manager_type, config) in CONFIGURATIONS {
        if check_files_exist(&config.files) {
            candidates.push((*manager_type, config.priority));
        }
    }

    candidates.sort_by_key(|(_, priority)| *priority);

    match candidates.first() {
        Some((manager_type, _)) => Ok(match manager_type {
            ManagerType::Cargo => Box::new(crate::pkgm::cargo::Cargo),
            ManagerType::Npm => Box::new(crate::pkgm::npm::Npm),
            ManagerType::Pnpm => Box::new(crate::pkgm::pnpm::Pnpm),
            ManagerType::Yarn => Box::new(crate::pkgm::yarn::Yarn),
            ManagerType::Pip => Box::new(crate::pkgm::pip::Pip),
            ManagerType::Pdm => Box::new(crate::pkgm::pdm::Pdm),
            ManagerType::Poetry => Box::new(crate::pkgm::poetry::Poetry),
        }),
        None => bail!("No support package manager detected"),
    }
}

fn check_files_exist(files: &[&str]) -> bool {
    let current_dir = std::env::current_dir().unwrap();
    find_up(&current_dir, files).is_some()
}

fn find_up(dir: &Path, targets: &[&str]) -> Option<PathBuf> {
    let mut current_dir = dir.to_path_buf();
    loop {
        for target in targets {
            let path = current_dir.join(target);
            if path.exists() {
                return Some(path);
            }
        }
        if !current_dir.pop() {
            break;
        }
    }
    None
}
