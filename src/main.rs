mod commands;
mod pkgm;
mod utils;

use anyhow::Result;
use clap::Parser;
use commands::CliCommand;

#[derive(Parser)]
#[command(name = "mg")]
#[command(version, about = "Multi-package manager CLI")]
struct Cli {
    #[command(subcommand)]
    command: CliCommand,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    cli.command.execute()
}
