use crate::commands::common::PackageCommand;
use crate::utils::error::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct RemoveArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Packages to remove"
    )]
    pub raw_args: Vec<String>,
}

impl PackageCommand for RemoveArgs {
    fn command_name(&self) -> &'static str {
        "remove"
    }

    fn raw_args(&self) -> &[String] {
        &self.raw_args
    }
}

impl RemoveArgs {
    pub fn execute(&self) -> Result<()> {
        PackageCommand::execute(self)
    }
}
