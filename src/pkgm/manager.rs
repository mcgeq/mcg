use colored::Colorize;
use std::time::Instant;

use super::{PackageOptions, types::PackageManager};
use crate::utils::error::Result;

pub fn execute_with_prompt(
    manager: &dyn PackageManager,
    command: &str,
    packages: &[String],
    options: &PackageOptions,
) -> Result<()> {
    let start = Instant::now();
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
    
    manager.execute_command(command, packages, options)?;
    
    let duration = start.elapsed();
    tracing::info!(
        manager = %manager_name,
        command = %command,
        duration_ms = duration.as_millis(),
        "Command completed successfully"
    );
    
    println!("{}", "✓ Command completed successfully.".green());
    
    // Show execution time for longer commands
    if duration.as_secs() > 3 {
        println!("⏱️  Completed in {:.2}s", duration.as_secs_f64());
    }
    
    Ok(())
}
