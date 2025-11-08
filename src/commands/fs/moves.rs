use crate::utils::error::Result;
use anyhow::Context;
use clap::Args;
use colored::Colorize;
use std::fs;

#[derive(Debug, Args)]
pub struct MoveArgs {
    /// Source path
    #[arg(help = "The source path to move")]
    src: String,
    /// Destination path
    #[arg(help = "The destination path to move to")]
    dest: String,
}

impl super::FsCommandExecute for MoveArgs {
    fn execute(&self) -> Result<()> {
        fs::rename(&self.src, &self.dest)
            .with_context(|| format!("Failed to move from {} to {}", self.src, self.dest))?;
        println!(
            "{}: {} -> {}",
            "Moved".green(),
            self.src.blue(),
            self.dest.blue()
        );
        Ok(())
    }
}
