use crate::utils::error::Result;
use anyhow::Context;
use clap::Args;
use colored::Colorize;
use std::fs;
use std::path::Path;

#[derive(Debug, Args)]
pub struct CreateArgs {
    /// Path to create
    #[arg(help = "The path to create (file or directory)")]
    path: String,

    /// Whether to create directories recursively
    #[arg(
        short,
        long,
        default_value_t = true,
        help = "Create directories recursively"
    )]
    recursive: bool,
}

impl super::FsCommandExecute for CreateArgs {
    fn execute(&self) -> Result<()> {
        let path = Path::new(&self.path);

        // 如果路径以分隔符结尾，或者路径已经是一个目录，则创建目录
        if self.path.ends_with(std::path::MAIN_SEPARATOR) || path.is_dir() {
            fs::create_dir_all(path)
                .with_context(|| format!("Failed to create directory: {}", self.path))?;
            println!("{}: {}", "Created directory".green(), self.path.blue());
        } else {
            // 否则创建文件
            if let Some(parent) = path.parent() {
                // 如果父目录不存在，则递归创建父目录
                if !parent.exists() && self.recursive {
                    fs::create_dir_all(parent).with_context(|| {
                        format!("Failed to create parent directory: {}", parent.display())
                    })?;
                }
            }
            fs::File::create(path)
                .with_context(|| format!("Failed to create file: {}", self.path))?;
            println!("{}: {}", "Created file".green(), self.path.blue());
        }

        Ok(())
    }
}
