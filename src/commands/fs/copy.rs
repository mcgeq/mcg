use crate::utils::error::Result;
use anyhow::Context;
use clap::Args;
use colored::Colorize;
use std::fs;
use std::path::Path;

#[derive(Args)]
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

        if src_path.is_file() {
            fs::copy(src_path, dest_path).with_context(|| {
                format!("Failed to copy file from {} to {}", self.src, self.dest)
            })?;
        } else if src_path.is_dir() {
            if self.recursive {
                copy_dir_all(src_path, dest_path).with_context(|| {
                    format!(
                        "Failed to copy directory from {} to {}",
                        self.src, self.dest
                    )
                })?;
                println!(
                    "{}: {} -> {}",
                    "Copied directory".green(),
                    self.src.blue(),
                    self.dest.blue()
                );
            } else {
                anyhow::bail!(
                    "{}: Cannot copy directory without recursive flag",
                    "Error".red()
                );
            }
        } else {
            anyhow::bail!("Source path does not exist: {}", self.src.red());
        }
        Ok(())
    }
}

fn copy_dir_all(src: &Path, dest: &Path) -> Result<()> {
    fs::create_dir_all(dest)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let entry_path = entry.path();
        let dest_path = dest.join(entry.file_name());

        if entry_path.is_dir() {
            copy_dir_all(&entry_path, &dest_path)?;
        } else {
            fs::copy(&entry_path, &dest_path)?;
        }
    }
    Ok(())
}
