use crate::{
    pkgm::{detect, execute_with_prompt, PackageOptions},
    utils::error::Result,
};
use clap::Args;

#[derive(Debug, Args)]
pub struct InstallArgs {
    #[arg(
        allow_hyphen_values = true,
        trailing_var_arg = true,
        help = "Additional arguments for install"
    )]
    pub raw_args: Vec<String>,
}

impl InstallArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;
        let options = PackageOptions::new(self.raw_args.clone());
        execute_with_prompt(&*manager, "install", &[], &options)
    }
}
