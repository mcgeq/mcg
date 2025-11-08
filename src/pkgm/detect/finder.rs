use super::cache::{get_cached_manager, set_cached_manager};
use super::detection_config::{CONFIGURATIONS, DetectionConfig};
use crate::pkgm::config::MgConfig;
use crate::pkgm::types::{ManagerType, PackageManager};
use anyhow::{Result, bail};
use std::path::{Path, PathBuf};

pub fn detect() -> Result<Box<dyn PackageManager>> {
    // Check for configuration file first
    if let Ok(Some(config)) = MgConfig::find_and_load() {
        if let Some(manager_name) = &config.manager {
            tracing::info!(manager = %manager_name, "Using manager from config");
            if let Ok(manager_type) = parse_manager_type(manager_name) {
                set_cached_manager(manager_type.clone());
                return create_manager(&manager_type);
            } else {
                tracing::warn!(manager = %manager_name, "Invalid manager name in config");
            }
        }
    }

    // Try to get cached result
    if let Some(cached_type) = get_cached_manager() {
        tracing::debug!(manager = ?cached_type, "Using cached package manager");
        return create_manager(&cached_type);
    }

    tracing::debug!("Detecting package manager from file system");
    let mut candidates: Vec<&DetectionConfig> = CONFIGURATIONS
        .iter()
        .filter(|config| {
            let exists = check_files_exist(config.identifier_files);
            if exists {
                tracing::debug!(
                    manager = ?config.manager_type,
                    files = ?config.identifier_files,
                    "Found candidate package manager"
                );
            }
            exists
        })
        .collect();

    candidates.sort_by_key(|config| config.priority);

    let result = candidates
        .first()
        .map(|config| {
            let manager_type = &config.manager_type;
            // Cache the result
            set_cached_manager(manager_type.clone());
            tracing::info!(manager = ?manager_type, "Detected package manager");
            create_manager(manager_type)
        })
        .unwrap_or_else(|| {
            tracing::warn!("No supported package manager detected");
            bail!("No supported package manager detected")
        });

    result
}

fn parse_manager_type(name: &str) -> Result<ManagerType> {
    match name.to_lowercase().as_str() {
        "cargo" => Ok(ManagerType::Cargo),
        "npm" => Ok(ManagerType::Npm),
        "pnpm" => Ok(ManagerType::Pnpm),
        "bun" => Ok(ManagerType::Bun),
        "yarn" => Ok(ManagerType::Yarn),
        "pip" => Ok(ManagerType::Pip),
        "poetry" => Ok(ManagerType::Poetry),
        "pdm" => Ok(ManagerType::Pdm),
        _ => bail!("Unknown package manager: {}", name),
    }
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
