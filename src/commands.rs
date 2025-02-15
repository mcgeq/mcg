// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcgeq. All rights reserved.
// Author:         mcgeq
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Command
// Create   Date:  2025-02-15 10:38:41
// Last Modified:  2025-02-15 13:04:04
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
    Install dependencies    : mg install\n\
    Add a package           : mg add loadsh\n\
    Upgrade a package       : mg upgrade loadash\n\
    Remove a package        : mg remove loadash\n\
    Analyze dependencies    : mg analyze\n"
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

    /// Management project dependencies
    #[command(subcommand)]
    Package(PackageCommands),
}

#[derive(Subcommand)]
pub enum PackageCommands {
    /// install dependencies
    #[command(name = "install", alias = "i")]
    Install {
        #[arg(short, long)]
        frozen: bool,
    },

    /// Add package
    #[command(name = "add", alias = "a")]
    Add {
        package: String,
        #[arg(short, long)]
        dev: bool,
    },

    /// Upgrade package
    #[command(name = "upgrade", alias = "u")]
    Upgrade {
        package: Option<String>,
    },

    /// Delete package
    #[command(name = "remove", alias = "r")]
    Remove {
        package: String,
    },

    /// Analyze package dependencies
    #[command(name = "analyze", alias = "an")]
    Analyze,
}
