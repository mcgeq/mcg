pub struct Pdm;

fn get_command_args(cmd: &str) -> Vec<String> {
    match cmd {
        "add" => vec!["add".to_string()],
        "install" => vec!["install".to_string()],
        "remove" => vec!["remove".to_string()],
        "upgrade" => vec!["update".to_string()],
        "analyze" => vec!["list".to_string()],
        _ => vec![cmd.to_string()],
    }
}

impl_package_manager!(Pdm, "pdm", get_command_args);
