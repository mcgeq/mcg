use super::config::CONFIGURATIONS;
use crate::pkgm::types::{ManagerType, PackageManager};
use anyhow::{Result, bail};
use std::path::{Path, PathBuf};

pub fn detect() -> Result<Box<dyn PackageManager>> {
    let mut candidates = Vec::new();

    for (manager_type, files) in CONFIGURATIONS {
        if check_files_exist(files) {
            candidates.push((manager_type.clone(), get_priority(manager_type.clone())));
        }
    }

    candidates.sort_by(|a, b| a.1.cmp(&b.1));

    candidates
        .first()
        .map(|(m, _)| match m {
            ManagerType::Cargo => {
                Ok(Box::new(crate::pkgm::cargo::Cargo) as Box<dyn PackageManager>)
            }
            ManagerType::Npm => Ok(Box::new(crate::pkgm::npm::Npm) as Box<dyn PackageManager>),
            ManagerType::Pnpm => Ok(Box::new(crate::pkgm::pnpm::Pnpm) as Box<dyn PackageManager>),
            ManagerType::Bun => Ok(Box::new(crate::pkgm::bun::Bun) as Box<dyn PackageManager>),
            ManagerType::Yarn => Ok(Box::new(crate::pkgm::yarn::Yarn) as Box<dyn PackageManager>),
            ManagerType::Pip => Ok(Box::new(crate::pkgm::pip::Pip) as Box<dyn PackageManager>),
            ManagerType::Poetry => {
                Ok(Box::new(crate::pkgm::poetry::Poetry) as Box<dyn PackageManager>)
            }
            ManagerType::Pdm => Ok(Box::new(crate::pkgm::pdm::Pdm) as Box<dyn PackageManager>),
        })
        .unwrap_or_else(|| bail!("No supported package manager detected"))
}

fn get_priority(manager: ManagerType) -> u8 {
    match manager {
        ManagerType::Cargo => 0,
        ManagerType::Pnpm => 1,
        ManagerType::Bun => 2,
        ManagerType::Npm => 3,
        ManagerType::Yarn => 4,
        ManagerType::Pip => 5,
        ManagerType::Poetry => 6,
        ManagerType::Pdm => 7,
    }
}

fn check_files_exist(files: &[&str]) -> bool {
    let current_dir = std::env::current_dir().unwrap();
    find_up(&current_dir, files).is_some()
}

pub fn find_up(dir: &Path, targets: &[&str]) -> Option<PathBuf> {
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
