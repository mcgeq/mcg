use clap::Parser;
use commands::{Cli, Commands};
use file_ops::{copy_dir, copy_file, create_file, create_fir, remove_dir, remove_file};
use package_manager::{
    add_package, analyze_dependencies, install_dependencies, remove_package, upgrade_package,
};

mod commands;
mod file_ops;
mod package_manager;
mod utils;

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::DirCreate { path } => create_fir(&path),
        Commands::DirRemove { path } => remove_dir(&path),
        Commands::DirCopy { src, dest } => copy_dir(&src, &dest),
        Commands::FileCreate { filename } => create_file(&filename),
        Commands::FileRemove { path } => remove_file(&path),
        Commands::FileCopy { src, dest } => copy_file(&src, &dest),
        Commands::Install { frozen } => install_dependencies(frozen),
        Commands::Add { package, dev } => add_package(&package, dev),
        Commands::Upgrade { package } => upgrade_package(package.as_deref()),
        Commands::Remove { package } => remove_package(&package),
        Commands::Analyze => analyze_dependencies(),
    };

    if let Err(e) = result {
        eprint!("{}", e);
        std::process::exit(1);
    }
}
