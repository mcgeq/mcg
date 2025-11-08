pub struct Cargo;

fn get_command_args(cmd: &str) -> Vec<String> {
    match cmd {
        "add" => vec!["add".to_string()],
        "install" => vec!["check".to_string()],
        "remove" => vec!["remove".to_string()],
        "upgrade" => vec!["update".to_string()],
        "analyze" => vec!["tree".to_string()],
        _ => vec![cmd.to_string()],
    }
}

impl_package_manager!(Cargo, "cargo", get_command_args);
