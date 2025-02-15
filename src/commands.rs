// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcgeq. All rights reserved.
// Author:         mcgeq
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Command
// Create   Date:  2025-02-15 10:38:41
// Last Modified:  2025-02-15 12:16:32
// Modified   By:  mcgeq <mcgeq@outlook.com>
// ----------------------------------------------------------------------------

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "mg")]
#[command(about = "A powerful CLI tool for file/directory operations and project management",
    version)]
#[command(
    after_help = "Examples:\n\
    Create a directory      : mg -dc ./dir\n\
    Remove a directory      : mg -dr ./dir\n\
    Copy a directory        : mg -dy ./src ./dest\n\
    Create a file           : mg -fc file.txt\n\
    Remove a file           : mg -fr file.txt\n\
    Copy a file             : mg -fy src.txt dest.txt\n\
    Install dependencies    : mg install\n"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Create a directory (recursive by default)
    #[command(name = "-dc")]
    DirCreate {
        path: String,
    },

    /// Remove a directory (recursive by default)
    #[command(name = "-dr")]
    DirRemove {
        path: String,
    },

    /// Copy a directory
    #[command(name = "-dy")]
    DirCopy {
        src: String,
        dest: String,
    },

    /// Create a file
    #[command(name = "-fc")]
    FileCreate {
        filename: String,
    },

    /// Remove a file
    #[command(name = "-fr")]
    FileRemove {
        path: String,
    },

    /// Copy a file
    #[command(name = "-fy")]
    FileCopy {
        src: String,
        dest: String,
    },

    /// Install project dependencies
    Install {
        #[arg(short, long)]
        frozen: bool,
    },
}
