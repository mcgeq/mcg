use crate::pkgm::{detect, PackageManager, PackageOptions};
use anyhow::Result;
use clap::Args;
use colored::Colorize;

#[derive(Args)]
pub struct AddArgs {
    pub packages: Vec<String>,

    #[arg(last = true, help = "Package manager specific arguments")]
    pub manager_args: Vec<String>,
}

impl AddArgs {
    pub fn execute(&self) -> Result<()> {
        let manager: Box<dyn PackageManager> = detect()?;
        let options = PackageOptions::new(self.manager_args.clone());

        manager.add(&self.packages, &options).map(|_| {
            println!("{} Successfully added packages", "✓".green());
        })
    }
}
