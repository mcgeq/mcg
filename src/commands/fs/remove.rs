use crate::utils::error::Result;
use anyhow::Context;
use clap::Args;
use colored::Colorize;
use std::fs;
use std::path::Path;

#[derive(Args)]
pub struct RemoveArgs {
    /// Path to remove
    #[arg(help = "The path to remove (file or directory)")]
    path: String,
    /// Whether to remove recursively
    #[arg(
        short,
        long,
        default_value_t = true,
        help = "Remove directories recursively"
    )]
    recursive: bool,
}

impl super::FsCommandExecute for RemoveArgs {
    fn execute(&self) -> Result<()> {
        let path = Path::new(&self.path);
        if path.is_dir() {
            if self.recursive {
                fs::remove_dir_all(path)
                    .with_context(|| format!("Failed to remove directory: {}", self.path))?;
            } else {
                fs::remove_dir(path)
                    .with_context(|| format!("Failed to remove directory: {}", self.path))?;
            }
            println!("{}: {}", "Removed directory".green(), self.path.blue());
        } else if path.is_file() {
            fs::remove_file(path)
                .with_context(|| format!("Failed to remove file: {}", self.path))?;
        } else {
            anyhow::bail!("{}: {}", "Path does not exist".red(), self.path.blue());
        }
        Ok(())
    }
}
