pub struct Yarn;

fn get_command_args(cmd: &str) -> Vec<String> {
    match cmd {
        "add" => vec!["add".to_string()],
        "install" => vec!["install".to_string()],
        "remove" => vec!["remove".to_string()],
        "upgrade" => vec!["upgrade".to_string()],
        "analyze" => vec!["tree".to_string()],
        _ => vec![cmd.to_string()],
    }
}

impl_package_manager!(Yarn, "yarn", get_command_args);
