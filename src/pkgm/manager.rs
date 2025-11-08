use anyhow::Context;
use colored::Colorize;

use super::{PackageOptions, types::PackageManager};

pub fn execute_with_prompt(
    manager: &dyn PackageManager,
    command: &str,
    packages: &[String],
    options: &PackageOptions,
) -> anyhow::Result<()> {
    let manager_name = manager.name();
    tracing::info!(manager = %manager_name, "Using package manager");
    println!("Using {} package manager.", manager_name.cyan());

    let full_command = manager.format_command(command, packages, options);
    tracing::debug!(command = %full_command, "Formatted command");
    tracing::info!(
        manager = %manager_name,
        command = %command,
        packages = ?packages,
        "Executing command"
    );
    println!("Executing: {}", full_command.yellow());
    
    manager
        .execute_command(command, packages, options)
        .with_context(|| {
            format!(
                "Failed to execute '{}' command with {} package manager",
                command, manager_name
            )
        })?;
    
    tracing::info!(manager = %manager_name, command = %command, "Command completed successfully");
    println!("{}", "✓ Command completed successfully.".green());
    Ok(())
}
