use crate::{
    pkgm::{PackageOptions, detect},
    utils::args_parser::ArgsParser,
};
use anyhow::Result;
use clap::Args;

#[derive(Args)]
pub struct UpgradeArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Packages to upgrade (empty for all)"
    )]
    pub raw_args: Vec<String>,
}

impl UpgradeArgs {
    pub fn execute(&self) -> Result<()> {
        let (packages, manager_args) = ArgsParser::parse(&self.raw_args);
        let manager = detect()?;
        let options = PackageOptions::new(manager_args);

        crate::pkgm::execute_with_prompt(&*manager, "upgrade", &packages, &options)
    }
}
