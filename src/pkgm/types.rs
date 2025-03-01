use anyhow::Result;
use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum ManagerType {
    Cargo,
    Npm,
    Pnpm,
    Yarn,
    Pip,
    Pdm,
    Poetry,
}

#[derive(Debug, Serialize)]
pub struct DependencyInfo {
    pub name: String,
    pub version: String,
    pub dependencies: Vec<String>,
}

#[derive(Debug)]
pub struct PackageOptions {
    pub args: Vec<String>,
}

impl PackageOptions {
    pub fn new(args: Vec<String>) -> Self {
        Self { args }
    }
}

pub trait PackageManager {
    fn name(&self) -> &'static str;

    fn format_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> String;

    fn execute_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> Result<()>;

    fn analyze(&self, packages: &[String], options: &PackageOptions) -> Result<String>;
}
