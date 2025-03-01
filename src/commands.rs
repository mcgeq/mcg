mod add;
mod analyze;
mod remove;
mod upgrade;
use clap::Subcommand;

#[derive(Subcommand)]
pub enum CliCommand {
    /// Add Packages
    #[command(aliases = ["a"])]
    Add(add::AddArgs),
    /// Remove Packages
    #[command(aliases = ["r"])]
    Remove(remove::RemoveArgs),
    /// Upgraade Packages
    #[command(aliases = ["u"])]
    Upgrade(upgrade::UpgradeArgs),
    /// Analyze Depend
    #[command(aliases = ["an"])]
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
