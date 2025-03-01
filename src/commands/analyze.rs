use crate::pkgm::{detect, DependencyInfo};
use anyhow::Result;
use clap::Args;
use colored::Colorize;

#[derive(Args)]
pub struct AnalyzeArgs;

impl AnalyzeArgs {
    pub fn execute(&self) -> Result<()> {
        let manager = detect()?;
        let dependencies = manager.analyze()?;

        println!("{} Dependency Analysis:", "✦".cyan());
        print_dependencies(&dependencies, 0);
        Ok(())
    }
}

fn print_dependencies(deps: &[DependencyInfo], level: usize) {
    for dep in deps {
        println!(
            "{:>width$}{} @ {}",
            "",
            dep.name.blue(),
            dep.version.yellow(),
            width = level * 2
        );
        if !dep.dependencies.is_empty() {
            let dependencies: Vec<DependencyInfo> = dep
                .dependencies
                .iter()
                .map(|s| DependencyInfo {
                    name: s.clone(),
                    version: "1".to_string(),
                    dependencies: vec![],
                })
                .collect();
            print_dependencies(&dependencies, level + 1);
        }
    }
}
