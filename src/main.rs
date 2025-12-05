mod commands;
mod pkgm;
mod utils;

use clap::Parser;
use commands::CliCommand;
use tracing::{debug, trace};
use tracing_subscriber::{fmt, EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};
use utils::error::Result;

#[derive(Parser)]
#[command(name = "mg")]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: CliCommand,
    
    /// Enable verbose logging
    #[arg(short, long, global = true)]
    verbose: bool,
    
    /// Set log level (trace, debug, info, warn, error)
    #[arg(long, global = true, default_value = "warn")]
    log_level: String,
    
    /// Dry run mode (show what would be executed without running)
    #[arg(long, global = true)]
    dry_run: bool,
}

fn init_tracing(verbose: bool, log_level: &str) {
    let filter_level = if verbose {
        "debug"
    } else {
        log_level
    };

    // Build filter from environment or use provided level
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| {
            EnvFilter::new(format!("mg={}", filter_level.to_lowercase()))
        });

    tracing_subscriber::registry()
        .with(filter)
        .with(
            fmt::layer()
                .with_target(false)
                .with_timer(fmt::time::SystemTime)
                .with_ansi(true),
        )
        .init();
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    
    // Initialize tracing
    init_tracing(cli.verbose, &cli.log_level);
    
    debug!("Starting mg CLI tool");
    trace!(command = ?cli.command, "Parsed command");
    
    cli.command.execute()
}
