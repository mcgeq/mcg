use crate::{
    pkgm::{PackageOptions, detect},
    utils::args_parser::ArgsParser,
};
use anyhow::Result;
use clap::Args;

#[derive(Debug, Args)]
pub struct RemoveArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Package manager specific arguments"
    )]
    pub raw_args: Vec<String>,
}

impl RemoveArgs {
    pub fn execute(&self) -> Result<()> {
        let (packages, manager_args) = ArgsParser::parse(&self.raw_args);
        let manager = detect()?;
        let options = PackageOptions::new(manager_args);

        crate::pkgm::execute_with_prompt(&*manager, "remove", &packages, &options)
    }
}
