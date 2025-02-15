use clap::Parser;
use commands::{Cli, Commands};
use file_ops::{copy_dir, copy_file, create_file, create_fir, remove_dir, remove_file};
use package_manager::install_dependencies;

mod commands;
mod file_ops;
mod utils;
mod package_manager;

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::DirCreate { path, parents } => create_fir(&path, parents),
        Commands::DirRemove { path, force } => remove_dir(&path, force),
        Commands::DirCopy { src, dest } => copy_dir(&src, &dest),
        Commands::FileCreate { filename } => create_file(&filename),
        Commands::FileRemove { path } => remove_file(&path),
        Commands::FileCopy { src, dest } => copy_file(&src, &dest),
        Commands::Install { frozen } => install_dependencies(frozen),
    };

    if let Err(e) = result {
        eprint!("{}", e);
        std::process::exit(1);
    }
}
