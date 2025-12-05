use crate::utils::error::{MoveFailedSnafu, Result};
use clap::Args;
use colored::Colorize;
use snafu::ResultExt;
use std::fs;
use std::path::Path;

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
        let src_path = Path::new(&self.src);
        let dest_path = Path::new(&self.dest);
        
        fs::rename(src_path, dest_path).context(MoveFailedSnafu {
            from: src_path.to_path_buf(),
            to: dest_path.to_path_buf(),
        })?;
        
        println!(
            "{}: {} -> {}",
            "Moved".green(),
            self.src.blue(),
            self.dest.blue()
        );
        Ok(())
    }
}
