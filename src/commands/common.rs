use crate::{
    pkgm::{detect, execute_with_prompt, PackageOptions},
    utils::{args_parser::ArgsParser, error::Result, validator::PackageValidator},
};

/// Common trait for package management commands
/// 
/// This trait provides a shared implementation for commands that follow
/// the same pattern: parse args, detect manager, validate, and execute.
pub trait PackageCommand {
    /// Get the command name (e.g., "add", "remove", "upgrade")
    fn command_name(&self) -> &'static str;

    /// Get the raw arguments
    fn raw_args(&self) -> &[String];

    /// Whether packages are required for this command
    fn requires_packages(&self) -> bool {
        true
    }

    /// Execute the command with common logic
    fn execute(&self) -> Result<()> {
        let (packages, manager_args) = ArgsParser::parse(self.raw_args());

        // Validate packages if required
        if self.requires_packages() && !packages.is_empty() {
            PackageValidator::validate_packages(&packages)?;
        }

        // Detect package manager
        let manager = detect()?;
        let options = PackageOptions::new(manager_args);

        // Execute with prompt
        execute_with_prompt(&*manager, self.command_name(), &packages, &options)
    }
}
