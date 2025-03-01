use crate::pkgm::{detect, PackageOptions};
use anyhow::Result;
use clap::Args;
use colored::Colorize;

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

        manager.remove(&self.packages, &options).map(|_| {
            println!("{} Successfully removed packages", "✓".green());
        })
    }
}
