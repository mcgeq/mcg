// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcgeq. All rights reserved.
// Author:         mcgeq
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Command
// Create   Date:  2025-02-15 10:38:41
// Last Modified:  2025-02-15 13:29:42
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
    Install dependencies    : mg install (or mg i)\n\
    Add a package           : mg add lodash (or mg a lodash)\n\
    Upgrade a package       : mg upgrade lodash (or mg u lodash)\n\
    Remove a package        : mg remove lodash (or mg r lodash)\n\
    Analyze dependencies    : mg analyze (or mg an)\n"
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

    /// install dependencies
    #[command(name = "install", alias = "i", about = "Install dependencies (alias: i)")]
    Install {
        #[arg(short, long)]
        frozen: bool,
    },

    /// Add package
    #[command(name = "add", alias = "a", about = "Add a package (alias: a)")]
    Add {
        package: String,
        #[arg(short, long)]
        dev: bool,
    },

    /// Upgrade package
    #[command(name = "upgrade", alias = "u", about = "Upgrade a package (alias: u)")]
    Upgrade {
        package: Option<String>,
    },

    /// Delete package
    #[command(name = "remove", alias = "r", about = "Remove a package (alias: r)")]
    Remove {
        package: String,
    },

    /// Analyze package dependencies
    #[command(name = "analyze", alias = "an", about = "Analyze dependencies (alias: an)")]
    Analyze,

}
