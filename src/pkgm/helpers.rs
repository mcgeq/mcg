use super::types::PackageOptions;
use crate::utils::error::{CommandFailedSnafu, ManagerNotInstalledSnafu, Result};
use snafu::ResultExt;
use std::process::Command;

/// Execute a package manager command with improved error handling
/// 
/// # Arguments
/// * `manager_name` - Name of the package manager (e.g., "npm", "cargo")
/// * `command_args` - Command arguments as a vector of strings
/// * `packages` - List of package names to operate on
/// * `options` - Additional package manager options
/// 
/// # Returns
/// Result indicating success or failure with detailed error messages
/// 
/// # Errors
/// This function will return an error if:
/// - The package manager executable is not found in PATH
/// - The command execution fails with a non-zero exit code
pub fn execute_command(
    manager_name: &str,
    command_args: Vec<String>,
    packages: &[String],
    options: &PackageOptions,
    dry_run: bool,
) -> Result<()> {
    let mut cmd = Command::new(manager_name);
    cmd.args(&command_args);
    cmd.args(packages);
    cmd.args(&options.args);

    let full_command = format_command_string(manager_name, command_args.clone(), packages, options);

    tracing::debug!(
        manager = %manager_name,
        command = %full_command,
        dry_run = dry_run,
        "Executing command"
    );

    // Dry run mode - just show what would be executed
    if dry_run {
        tracing::info!("Dry run mode: would execute: {}", full_command);
        return Ok(());
    }

    let status = cmd.status().context(ManagerNotInstalledSnafu {
        manager: manager_name.to_string(),
    })?;

    if !status.success() {
        let exit_code = status.code().unwrap_or(-1);
        tracing::error!(
            manager = %manager_name,
            exit_code = exit_code,
            command = %full_command,
            "Command failed with non-zero exit code"
        );
        return CommandFailedSnafu {
            command: full_command,
            code: exit_code,
        }
        .fail();
    }
    
    tracing::debug!(
        manager = %manager_name,
        command = %full_command,
        "Command executed successfully"
    );

    Ok(())
}

/// Format a command string for display purposes
/// 
/// # Arguments
/// * `manager_name` - Name of the package manager
/// * `command_args` - Command arguments
/// * `packages` - Package names
/// * `options` - Additional options
/// 
/// # Returns
/// Formatted command string
pub fn format_command_string(
    manager_name: &str,
    command_args: Vec<String>,
    packages: &[String],
    options: &PackageOptions,
) -> String {
    let mut args = vec![manager_name.to_string()];
    args.extend(command_args);
    args.extend(packages.iter().cloned());
    args.extend(options.args.clone());
    args.join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_format_command_string() {
        let options = PackageOptions::new(vec!["-D".to_string(), "--save-exact".to_string()]);
        let packages = vec!["lodash".to_string(), "react".to_string()];
        let command_args = vec!["install".to_string()];

        let result = format_command_string("npm", command_args, &packages, &options);
        assert_eq!(result, "npm install lodash react -D --save-exact");
    }

    #[test]
    fn test_format_command_string_no_packages() {
        let options = PackageOptions::new(vec![]);
        let command_args = vec!["install".to_string()];

        let result = format_command_string("npm", command_args, &[], &options);
        assert_eq!(result, "npm install");
    }

    #[test]
    fn test_format_command_string_no_options() {
        let options = PackageOptions::new(vec![]);
        let packages = vec!["serde".to_string()];
        let command_args = vec!["add".to_string()];

        let result = format_command_string("cargo", command_args, &packages, &options);
        assert_eq!(result, "cargo add serde");
    }
}
