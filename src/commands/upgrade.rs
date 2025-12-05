use crate::commands::common::PackageCommand;
use crate::utils::error::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct UpgradeArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Packages to upgrade (empty for all)"
    )]
    pub raw_args: Vec<String>,
}

impl PackageCommand for UpgradeArgs {
    fn command_name(&self) -> &'static str {
        "upgrade"
    }

    fn raw_args(&self) -> &[String] {
        &self.raw_args
    }

    fn requires_packages(&self) -> bool {
        false // Allow empty packages for upgrade all
    }
}

impl UpgradeArgs {
    pub fn execute(&self) -> Result<()> {
        PackageCommand::execute(self)
    }
}
