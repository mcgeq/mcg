use crate::commands::common::PackageCommand;
use crate::utils::error::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct AnalyzeArgs {
    /// Package to analyze (optional)
    #[arg(allow_hyphen_values = true, trailing_var_arg = true)]
    pub raw_args: Vec<String>,
}

impl PackageCommand for AnalyzeArgs {
    fn command_name(&self) -> &'static str {
        "analyze"
    }

    fn raw_args(&self) -> &[String] {
        &self.raw_args
    }

    fn requires_packages(&self) -> bool {
        false // Package name is optional for analyze
    }
}

impl AnalyzeArgs {
    pub fn execute(&self) -> Result<()> {
        PackageCommand::execute(self)
    }
}
