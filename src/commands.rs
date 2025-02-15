// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcgeq. All rights reserved.
// Author:         mcgeq
// Email:          <mcgeq@outlook.com>
// File:           commands.rs
// Description:    About Command
// Create   Date:  2025-02-15 10:38:41
// Last Modified:  2025-02-15 11:44:41
// Modified   By:  mcgeq <mcgeq@outlook.com>
// ----------------------------------------------------------------------------

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "mg")]
#[command(about = "A powerful CLI tool for file/directory operations and project management",
    version)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// 创建目录
    #[command(name = "-dc")]
    DirCreate {
        path: String,
        #[arg(short, long)]
        parents: bool,
    },

    /// 删除目录
    #[command(name = "-dr")]
    DirRemove {
        path: String,
        #[arg(short, long)]
        force: bool,
    },

    /// 复制目录
    #[command(name = "-dp")]
    DirCopy {
        src: String,
        dest: String,
    },

    /// 创建文件
    #[command(name = "-fc")]
    FileCreate {
        filename: String,
    },

    /// 删除文件
    #[command(name = "-fr")]
    FileRemove {
        path: String,
    },

    /// 复制文件
    #[command(name = "-fp")]
    FileCopy {
        src: String,
        dest: String,
    },

    /// 安装项目依赖
    Install {
        #[arg(short, long)]
        frozen: bool,
    },
}
