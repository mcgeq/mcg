pub struct Pip;

fn get_command_args(cmd: &str) -> Vec<String> {
    match cmd {
        "add" => vec!["install".to_string()],
        "install" => vec!["install".to_string()],
        "remove" => vec!["uninstall".to_string()],
        "upgrade" => vec!["install".to_string(), "--upgrade".to_string()],
        "analyze" => vec!["list".to_string()],
        _ => vec![cmd.to_string()],
    }
}

impl_package_manager!(Pip, "pip", get_command_args);
