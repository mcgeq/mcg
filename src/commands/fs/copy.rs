use crate::utils::error::{CopyFailedSnafu, CreateDirFailedSnafu, PathNotFoundSnafu, Result};
use clap::Args;
use colored::Colorize;
use snafu::ResultExt;
use std::fs;
use std::path::Path;

#[derive(Debug, Args)]
pub struct CopyArgs {
    /// Source path
    #[arg(help = "The source path to copy from")]
    src: String,
    /// Destination path
    #[arg(help = "The destination path to copy to")]
    dest: String,
    /// Whether to copy recursively
    #[arg(
        short,
        long,
        default_value_t = true,
        help = "Copy directories recursively"
    )]
    recursive: bool,
}

impl super::FsCommandExecute for CopyArgs {
    fn execute(&self) -> Result<()> {
        let src_path = Path::new(&self.src);
        let dest_path = Path::new(&self.dest);

        if !src_path.exists() {
            return PathNotFoundSnafu {
                path: src_path.to_path_buf(),
            }
            .fail();
        }

        if src_path.is_file() {
            fs::copy(src_path, dest_path).context(CopyFailedSnafu {
                from: src_path.to_path_buf(),
                to: dest_path.to_path_buf(),
            })?;
            println!(
                "{}: {} -> {}",
                "Copied file".green(),
                self.src.blue(),
                self.dest.blue()
            );
        } else if src_path.is_dir() {
            if !self.recursive {
                return PathNotFoundSnafu {
                    path: src_path.to_path_buf(),
                }
                .fail();
            }
            copy_dir_all(src_path, dest_path)?;
            println!(
                "{}: {} -> {}",
                "Copied directory".green(),
                self.src.blue(),
                self.dest.blue()
            );
        }
        Ok(())
    }
}

fn copy_dir_all(src: &Path, dest: &Path) -> Result<()> {
    fs::create_dir_all(dest).context(CreateDirFailedSnafu {
        path: dest.to_path_buf(),
    })?;
    
    for entry in fs::read_dir(src).map_err(|e| crate::utils::error::Error::CreateDirFailed {
        path: src.to_path_buf(),
        source: e,
    })? {
        let entry = entry.map_err(|e| crate::utils::error::Error::CreateDirFailed {
            path: src.to_path_buf(),
            source: e,
        })?;
        let entry_path = entry.path();
        let dest_path = dest.join(entry.file_name());

        if entry_path.is_dir() {
            copy_dir_all(&entry_path, &dest_path)?;
        } else {
            fs::copy(&entry_path, &dest_path).context(CopyFailedSnafu {
                from: entry_path,
                to: dest_path,
            })?;
        }
    }
    Ok(())
}
