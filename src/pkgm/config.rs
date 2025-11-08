use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

/// Configuration file structure
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct MgConfig {
    /// Override package manager detection
    #[serde(skip_serializing_if = "Option::is_none")]
    pub manager: Option<String>,
    
    /// Custom command mappings
    #[serde(skip_serializing_if = "Option::is_none")]
    pub commands: Option<CommandMappings>,
    
    /// Default options for commands
    #[serde(skip_serializing_if = "Option::is_none")]
    pub defaults: Option<DefaultOptions>,
}

/// Custom command mappings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandMappings {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub add: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub remove: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub upgrade: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub install: Option<String>,
    
    #[serde(skip_serializing_if = "Option::is_none")]
    pub analyze: Option<String>,
}

/// Default options for commands
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DefaultOptions {
    /// Default arguments for add command
    #[serde(skip_serializing_if = "Option::is_none")]
    pub add_args: Option<Vec<String>>,
    
    /// Default arguments for other commands
    #[serde(skip_serializing_if = "Option::is_none")]
    pub default_args: Option<Vec<String>>,
}

impl MgConfig {
    /// Load configuration from a file
    pub fn load_from_file<P: AsRef<Path>>(path: P) -> Result<Option<Self>> {
        let path = path.as_ref();
        if !path.exists() {
            return Ok(None);
        }

        let content = fs::read_to_string(path)
            .with_context(|| format!("Failed to read config file: {}", path.display()))?;

        let config: MgConfig = toml::from_str(&content)
            .with_context(|| format!("Failed to parse config file: {}", path.display()))?;

        tracing::debug!(config_path = %path.display(), "Loaded configuration from file");
        Ok(Some(config))
    }

    /// Find and load configuration file from current directory or parent directories
    pub fn find_and_load() -> Result<Option<Self>> {
        let mut current_dir = std::env::current_dir()
            .context("Failed to get current directory")?;

        loop {
            let config_path = current_dir.join(".mg.toml");
            if config_path.exists() {
                return Self::load_from_file(config_path);
            }

            if !current_dir.pop() {
                break;
            }
        }

        Ok(None)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::fs;

    #[test]
    fn test_load_config() {
        let temp_dir = TempDir::new().unwrap();
        let config_file = temp_dir.path().join(".mg.toml");
        
        let config_content = r#"
manager = "npm"
[commands]
add = "install"
remove = "uninstall"
"#;
        
        fs::write(&config_file, config_content).unwrap();
        
        let config = MgConfig::load_from_file(&config_file).unwrap().unwrap();
        assert_eq!(config.manager, Some("npm".to_string()));
        assert_eq!(config.commands.as_ref().unwrap().add, Some("install".to_string()));
    }

    #[test]
    fn test_find_config() {
        let temp_dir = TempDir::new().unwrap();
        let config_file = temp_dir.path().join(".mg.toml");
        fs::write(&config_file, "manager = \"cargo\"").unwrap();
        
        std::env::set_current_dir(temp_dir.path()).unwrap();
        let config = MgConfig::find_and_load().unwrap();
        assert!(config.is_some());
        assert_eq!(config.unwrap().manager, Some("cargo".to_string()));
    }

    #[test]
    fn test_no_config() {
        let temp_dir = TempDir::new().unwrap();
        std::env::set_current_dir(temp_dir.path()).unwrap();
        let config = MgConfig::find_and_load().unwrap();
        assert!(config.is_none());
    }
}

