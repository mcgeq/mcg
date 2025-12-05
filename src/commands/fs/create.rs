use crate::utils::error::{CreateDirFailedSnafu, CreateFileFailedSnafu, Result};
use clap::Args;
use colored::Colorize;
use snafu::ResultExt;
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
            fs::create_dir_all(path).context(CreateDirFailedSnafu {
                path: path.to_path_buf(),
            })?;
            println!("{}: {}", "Created directory".green(), self.path.blue());
        } else {
            // 否则创建文件
            if let Some(parent) = path.parent() {
                // 如果父目录不存在，则递归创建父目录
                if !parent.exists() && self.recursive {
                    fs::create_dir_all(parent).context(CreateDirFailedSnafu {
                        path: parent.to_path_buf(),
                    })?;
                }
            }
            fs::File::create(path).context(CreateFileFailedSnafu {
                path: path.to_path_buf(),
            })?;
            println!("{}: {}", "Created file".green(), self.path.blue());
        }

        Ok(())
    }
}
