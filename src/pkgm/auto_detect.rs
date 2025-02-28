use std::path::{Path, PathBuf};

use crate::pkgm::{cargo, npm, pdm, pip, pnpm, poetry, yarn};

use super::manager::{ManagerType, PackageManager};
use anyhow::{bail, Result};

pub fn detect_manager() -> Result<ManagerType> {
    // let current_dir = std::env::current_dir()?;
    //
    // let detectors = vec![
    //     (ManagerType::Cargo, vec!["Cargo.toml"]),
    //     (ManagerType::Pnpm, vec!["pnpm-lock.yaml"]),
    //     (ManagerType::Npm, vec!["package-lock.json"]),
    //     (ManagerType::Yarn, vec!["yarn-lock.yaml"]),
    //     (ManagerType::Pip, vec!["requirements.txt"]),
    //     (ManagerType::Pdm, vec!["pyproject.toml"]),
    //     (ManagerType::Poetry, vec!["pyproject.toml"]),
    // ];
    //
    // for (manager, files) in detectors {
    //     if find_up(&current_dir, &files).is_some() {
    //         return Ok(manager);
    //     }
    // }
    // 按优先级检测
    let detectors = vec![
        (ManagerType::Cargo, <cargo::Cargo as PackageManager>::detect),
        (ManagerType::Npm, <npm::Npm as PackageManager>::detect),
        (ManagerType::Pnpm, <pnpm::Pnpm as PackageManager>::detect),
        (ManagerType::Yarn, <yarn::Yarn as PackageManager>::detect),
        (ManagerType::Pip, <pip::Pip as PackageManager>::detect),
        (ManagerType::Pdm, <pdm::Pdm as PackageManager>::detect),
        (
            ManagerType::Poetry,
            <poetry::Poetry as PackageManager>::detect,
        ),
    ];
    for (manager_type, detector) in detectors {
        if detector() {
            return Ok(manager_type);
        }
    }
    bail!("No supported package manager detected")
}

fn find_up(dir: &Path, files: &[&str]) -> Option<PathBuf> {
    let mut current_dir = dir.to_path_buf();
    loop {
        for file in files {
            let path = current_dir.join(file);
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
