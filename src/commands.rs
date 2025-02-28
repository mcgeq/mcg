mod add;
mod remove;
mod upgrade;

use clap::Subcommand;

#[derive(Subcommand)]
pub enum CliCommand {}
