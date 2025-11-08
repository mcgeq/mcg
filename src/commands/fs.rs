mod copy;
mod create;
mod moves;
mod remove;

use crate::utils::error::Result;
use clap::Subcommand;

pub trait FsCommandExecute {
    fn execute(&self) -> Result<()>;
}

#[derive(Debug, Subcommand)]
pub enum FsCommand {
    /// Create Directory or File
    #[command(aliases = ["c", "touch"], about = "Create a directory or file")]
    Create(create::CreateArgs),
    /// Remove Directory or File
    #[command(aliases = ["r"], about = "Remove a directory or file")]
    Remove(remove::RemoveArgs),
    /// Copy Directory or File
    #[command(aliases = ["y"], about = "Copy a directory or file")]
    Copy(copy::CopyArgs),
    /// Move or Rename Directory or File
    #[command(aliases = ["m"], about = "Move or Rename a directory or file")]
    Moves(moves::MoveArgs),
}

impl FsCommand {
    pub fn execute(&self) -> Result<()> {
        match self {
            Self::Create(cmd) => cmd.execute(),
            Self::Remove(cmd) => cmd.execute(),
            Self::Copy(cmd) => cmd.execute(),
            Self::Moves(cmd) => cmd.execute(),
        }
    }
}
