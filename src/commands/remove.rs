use crate::pkgm::{PackageOptions, detect};
use anyhow::Result;
use clap::Args;

#[derive(Args)]
pub struct RemoveArgs {
    pub packages: Vec<String>,

    #[arg(last = true, help = "Package manager specific arguments")]
    pub manager_args: Vec<String>,
}

impl RemoveArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;
        let options = PackageOptions::new(self.manager_args.clone());

        crate::pkgm::execute_with_prompt(&*manager, "remove", &self.packages, &options)
    }
}
