use crate::utils::error::{PathNotFoundSnafu, RemoveFailedSnafu, Result};
use clap::Args;
use colored::Colorize;
use snafu::ResultExt;
use std::fs;
use std::path::Path;

#[derive(Debug, Args)]
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
        
        if !path.exists() {
            return PathNotFoundSnafu {
                path: path.to_path_buf(),
            }
            .fail();
        }
        
        if path.is_dir() {
            if self.recursive {
                fs::remove_dir_all(path).context(RemoveFailedSnafu {
                    path: path.to_path_buf(),
                })?;
            } else {
                fs::remove_dir(path).context(RemoveFailedSnafu {
                    path: path.to_path_buf(),
                })?;
            }
            println!("{}: {}", "Removed directory".green(), self.path.blue());
        } else {
            fs::remove_file(path).context(RemoveFailedSnafu {
                path: path.to_path_buf(),
            })?;
            println!("{}: {}", "Removed file".green(), self.path.blue());
        }
        Ok(())
    }
}
