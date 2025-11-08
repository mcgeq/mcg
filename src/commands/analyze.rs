use crate::{
    pkgm::{PackageOptions, detect},
    utils::args_parser::ArgsParser,
};
use anyhow::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct AnalyzeArgs {
    /// Package to analyze (optional)
    #[arg(allow_hyphen_values = true, trailing_var_arg = true)]
    pub raw_args: Vec<String>,
}

impl AnalyzeArgs {
    pub fn execute(&self) -> Result<()> {
        let (packages, manager_args) = ArgsParser::parse(&self.raw_args);
        let manager = detect()?;

        let options = PackageOptions::new(manager_args);
        crate::pkgm::execute_with_prompt(&*manager, "analyze", &packages, &options)
    }
}
