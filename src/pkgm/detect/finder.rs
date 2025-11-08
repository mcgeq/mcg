use super::config::{CONFIGURATIONS, DetectionConfig};
use crate::pkgm::types::{ManagerType, PackageManager};
use anyhow::{Result, bail};
use std::path::{Path, PathBuf};

pub fn detect() -> Result<Box<dyn PackageManager>> {
    let mut candidates: Vec<&DetectionConfig> = CONFIGURATIONS
        .iter()
        .filter(|config| check_files_exist(config.identifier_files))
        .collect();

    candidates.sort_by_key(|config| config.priority);

    candidates
        .first()
        .map(|config| create_manager(&config.manager_type))
        .unwrap_or_else(|| bail!("No supported package manager detected"))
}

fn create_manager(manager_type: &ManagerType) -> Result<Box<dyn PackageManager>> {
    match manager_type {
        ManagerType::Cargo => Ok(Box::new(crate::pkgm::cargo::Cargo) as Box<dyn PackageManager>),
        ManagerType::Npm => Ok(Box::new(crate::pkgm::npm::Npm) as Box<dyn PackageManager>),
        ManagerType::Pnpm => Ok(Box::new(crate::pkgm::pnpm::Pnpm) as Box<dyn PackageManager>),
        ManagerType::Bun => Ok(Box::new(crate::pkgm::bun::Bun) as Box<dyn PackageManager>),
        ManagerType::Yarn => Ok(Box::new(crate::pkgm::yarn::Yarn) as Box<dyn PackageManager>),
        ManagerType::Pip => Ok(Box::new(crate::pkgm::pip::Pip) as Box<dyn PackageManager>),
        ManagerType::Poetry => Ok(Box::new(crate::pkgm::poetry::Poetry) as Box<dyn PackageManager>),
        ManagerType::Pdm => Ok(Box::new(crate::pkgm::pdm::Pdm) as Box<dyn PackageManager>),
    }
}

fn check_files_exist(files: &[&str]) -> bool {
    std::env::current_dir()
        .ok()
        .and_then(|dir| find_up(&dir, files))
        .is_some()
}

/// Find a file or directory by walking up the directory tree
/// 
/// # Arguments
/// * `dir` - The starting directory
/// * `targets` - List of file/directory names to search for
/// 
/// # Returns
/// The path to the first matching file/directory found, or None if not found
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_find_up_existing_file() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.txt");
        fs::write(&test_file, "test").unwrap();
        let subdir = temp_dir.path().join("sub");
        fs::create_dir(&subdir).unwrap();

        std::env::set_current_dir(&subdir).unwrap();
        let result = find_up(&subdir, &["test.txt"]);
        assert!(result.is_some());
        assert_eq!(result.unwrap(), test_file);
    }

    #[test]
    fn test_find_up_nonexistent_file() {
        let temp_dir = TempDir::new().unwrap();
        let subdir = temp_dir.path().join("sub");
        fs::create_dir(&subdir).unwrap();

        std::env::set_current_dir(&subdir).unwrap();
        let result = find_up(&subdir, &["nonexistent.txt"]);
        assert!(result.is_none());
    }

    #[test]
    fn test_find_up_multiple_targets() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("Cargo.toml");
        fs::write(&test_file, "[package]").unwrap();
        let subdir = temp_dir.path().join("sub");
        fs::create_dir(&subdir).unwrap();

        std::env::set_current_dir(&subdir).unwrap();
        let result = find_up(&subdir, &["package.json", "Cargo.toml"]);
        assert!(result.is_some());
        assert_eq!(result.unwrap(), test_file);
    }
}
