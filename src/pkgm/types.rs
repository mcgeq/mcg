use crate::utils::error::Result;

/// Package manager type enumeration
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum ManagerType {
    Cargo,
    Npm,
    Pnpm,
    Bun,
    Yarn,
    Pip,
    Pdm,
    Poetry,
}

/// Package manager options for passing additional arguments
#[derive(Debug)]
pub struct PackageOptions {
    pub args: Vec<String>,
}

impl PackageOptions {
    /// Create a new PackageOptions instance
    /// 
    /// # Arguments
    /// * `args` - Vector of additional arguments to pass to the package manager
    pub fn new(args: Vec<String>) -> Self {
        Self { args }
    }
}

/// Trait for package manager implementations
/// 
/// This trait defines the interface that all package managers must implement.
/// It provides methods for formatting and executing package manager commands.
pub trait PackageManager {
    /// Get the name of the package manager
    fn name(&self) -> &'static str;

    /// Format a command string for display
    /// 
    /// # Arguments
    /// * `command` - The command to execute (e.g., "add", "remove", "upgrade")
    /// * `packages` - List of package names
    /// * `options` - Additional package manager options
    /// 
    /// # Returns
    /// Formatted command string
    fn format_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> String;

    /// Execute a package manager command
    /// 
    /// # Arguments
    /// * `command` - The command to execute
    /// * `packages` - List of package names
    /// * `options` - Additional package manager options
    /// 
    /// # Returns
    /// Result indicating success or failure
    fn execute_command(
        &self,
        command: &str,
        packages: &[String],
        options: &PackageOptions,
    ) -> Result<()>;
}
