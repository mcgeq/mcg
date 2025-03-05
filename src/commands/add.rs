use crate::{
    pkgm::{PackageOptions, detect},
    utils::args_parser::ArgsParser,
};
use anyhow::Result;
use clap::Args;

#[derive(Args)]
pub struct AddArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Packages add"
    )]
    pub raw_args: Vec<String>,
}

impl AddArgs {
    pub fn execute(&self) -> Result<()> {
        let (packages, manager_args) = ArgsParser::parse(&self.raw_args);

        let manager = detect()?;
        let options = PackageOptions::new(manager_args);
        crate::pkgm::execute_with_prompt(&*manager, "add", &packages, &options)
    }
}
