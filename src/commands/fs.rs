mod copy;
mod create;
mod moves;
mod remove;
mod rename;

use crate::utils::error::Result;
use clap::Subcommand;

pub trait FsCommandExecute {
    fn execute(&self) -> Result<()>;
}

#[derive(Subcommand)]
pub enum FsCommand {
    /// Create Directory or File
    #[command(aliases = ["mkdir", "touch"], about = "Create a directory or file")]
    Create(create::CreateArgs),
    /// Remove Directory or File
    #[command(aliases = ["rm"], about = "Remove a directory or file")]
    Remove(remove::RemoveArgs),
    /// Copy Directory or File
    #[command(aliases = ["cp"], about = "Copy a directory or file")]
    Copy(copy::CopyArgs),
    /// Rename Directory or File
    #[command(aliases = ["mv"], about = "Rename a directory or file")]
    Rename(rename::RenameArgs),
    /// Move Directory or File
    #[command(aliases = ["move"], about = "Move a directory or file")]
    Moves(moves::MoveArgs),
}

impl FsCommand {
    pub fn execute(&self) -> Result<()> {
        match self {
            Self::Create(cmd) => cmd.execute(),
            Self::Remove(cmd) => cmd.execute(),
            Self::Copy(cmd) => cmd.execute(),
            Self::Rename(cmd) => cmd.execute(),
            Self::Moves(cmd) => cmd.execute(),
        }
    }
}
