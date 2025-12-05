use crate::commands::common::PackageCommand;
use crate::utils::error::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct AddArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Packages to add"
    )]
    pub raw_args: Vec<String>,
}

impl PackageCommand for AddArgs {
    fn command_name(&self) -> &'static str {
        "add"
    }

    fn raw_args(&self) -> &[String] {
        &self.raw_args
    }
}

impl AddArgs {
    pub fn execute(&self) -> Result<()> {
        PackageCommand::execute(self)
    }
}
