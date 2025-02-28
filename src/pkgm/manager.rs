use anyhow::Result;
use serde::Serialize;

#[derive(Debug)]
pub struct PackageOptions {
    pub manager_args: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct DependencyInfo {
    pub name: String,
    pub version: String,
    pub dependencies: Vec<String>,
}

pub trait PackageManager {
    fn detect() -> bool
    where
        Self: Sized;

    fn add(&self, packages: &[String], options: &PackageOptions) -> Result<()>;
    fn remove(&self, packages: &[String], options: &PackageOptions) -> Result<()>;
    fn upgrade(&self, packages: &[String], options: &PackageOptions) -> Result<()>;
    fn analyze(&self) -> Result<Vec<DependencyInfo>>;
}

#[derive(Debug, Clone)]
pub enum ManagerType {
    Cargo,
    Npm,
    Pnpm,
    Yarn,
    Pip,
    Poetry,
    Pdm,
}

impl ManagerType {
    pub fn get_manager(&self) -> Box<dyn PackageManager> {
        match self {
            Self::Cargo => Box::new(crate::pkgm::cargo::Cargo),
            Self::Npm => Box::new(crate::pkgm::npm::Npm),
            Self::Pnpm => Box::new(crate::pkgm::pnpm::Pnpm),
            Self::Yarn => Box::new(crate::pkgm::yarn::Yarn),
            Self::Pip => Box::new(crate::pkgm::pip::Pip),
            Self::Pdm => Box::new(crate::pkgm::pdm::Pdm),
            Self::Poetry => Box::new(crate::pkgm::poetry::Poetry),
        }
    }
}

impl ManagerType {
    pub fn from_str(s: &str) -> anyhow::Result<Self> {
        match s.to_lowercase().as_str() {
            "cargo" => Ok(Self::Cargo),
            "npm" => Ok(Self::Npm),
            "pnpm" => Ok(Self::Pnpm),
            "yarn" => Ok(Self::Yarn),
            "pip" => Ok(Self::Pip),
            "pdm" => Ok(Self::Pdm),
            "poetry" => Ok(Self::Poetry),
            _ => anyhow::bail!("Unsupported package manager: {}", s),
        }
    }
}

impl std::fmt::Display for ManagerType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            match self {
                Self::Cargo => "cargo",
                Self::Npm => "npm",
                Self::Pnpm => "pnpm",
                Self::Yarn => "yarn",
                Self::Pip => "pip",
                Self::Pdm => "pdm",
                Self::Poetry => "poetry",
            }
        )
    }
}
