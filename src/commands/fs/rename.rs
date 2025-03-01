use crate::utils::error::Result;
use anyhow::Context;
use clap::Args;
use colored::Colorize;
use std::fs;

#[derive(Args)]
pub struct RenameArgs {
    /// Source path
    #[arg(help = "The source path to rename")]
    src: String,
    /// Destination path
    #[arg(help = "The destination path to rename to")]
    dest: String,
}

impl super::FsCommandExecute for RenameArgs {
    fn execute(&self) -> Result<()> {
        fs::rename(&self.src, &self.dest)
            .with_context(|| format!("Failed to rename from {} to {}", self.src, self.dest))?;
        println!(
            "{}: {} -> {}",
            "Renamed".green(),
            self.src.blue(),
            self.dest.blue()
        );
        Ok(())
    }
}
