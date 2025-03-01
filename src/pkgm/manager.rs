use colored::Colorize;

use super::{PackageOptions, types::PackageManager};

pub fn execute_with_prompt(
    manager: &dyn PackageManager,
    command: &str,
    packages: &[String],
    options: &PackageOptions,
) -> anyhow::Result<()> {
    println!("Using {} package manager.", manager.name().cyan());

    let full_command = manager.format_command(command, packages, options);
    println!("Executing: {}", full_command.yellow());
    manager
        .execute_command(command, packages, options)
        .map(|_| {
            println!("{} Command completed successfully", "✓".green());
        })
}
