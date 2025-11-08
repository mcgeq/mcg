pub struct Poetry;

fn get_command_args(cmd: &str) -> Vec<String> {
    match cmd {
        "add" => vec!["add".to_string()],
        "install" => vec!["install".to_string()],
        "remove" => vec!["remove".to_string()],
        "upgrade" => vec!["update".to_string()],
        "analyze" => vec!["show".to_string()],
        _ => vec![cmd.to_string()],
    }
}

impl_package_manager!(Poetry, "poetry", get_command_args);
