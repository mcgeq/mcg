mod add;
mod analyze;
mod remove;
mod upgrade;
use clap::Subcommand;

#[derive(Subcommand)]
pub enum CliCommand {
    #[command(alias = "a")]
    Add(add::AddArgs),
    #[command(alias = "r")]
    Remove(remove::RemoveArgs),
    #[command(alias = "u")]
    Upgrade(upgrade::UpgradeArgs),
    #[command(alias = "an")]
    Analyze(analyze::AnalyzeArgs),
}

impl CliCommand {
    pub fn execute(&self) -> anyhow::Result<()> {
        match self {
            Self::Add(cmd) => cmd.execute(),
            Self::Remove(cmd) => cmd.execute(),
            Self::Upgrade(cmd) => cmd.execute(),
            Self::Analyze(cmd) => cmd.execute(),
        }
    }
}
