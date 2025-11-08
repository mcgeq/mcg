// Integration tests for the mg CLI tool
// Note: These tests require the package managers to be installed

#[cfg(test)]
mod tests {
    use std::process::Command;

    #[test]
    #[ignore] // Ignore by default as it requires actual package managers
    fn test_command_help() {
        let output = Command::new("cargo")
            .args(&["run", "--", "--help"])
            .output()
            .expect("Failed to execute command");

        assert!(output.status.success());
        let stdout = String::from_utf8(output.stdout).unwrap();
        assert!(stdout.contains("mg"));
        assert!(stdout.contains("Multi-package manager CLI"));
    }
}

