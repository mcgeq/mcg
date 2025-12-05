use crate::utils::error::{InvalidPackageNameSnafu, Result};

/// Validator for package names and arguments
pub struct PackageValidator;

impl PackageValidator {
    /// Validate a single package name
    /// 
    /// # Arguments
    /// * `name` - Package name to validate
    /// 
    /// # Returns
    /// Ok(()) if valid, Error otherwise
    pub fn validate_package_name(name: &str) -> Result<()> {
        // Check for empty name
        if name.trim().is_empty() {
            return InvalidPackageNameSnafu {
                name: name.to_string(),
            }
            .fail();
        }

        // Check for invalid starting characters (common across package managers)
        if name.starts_with('.') && name.len() > 1 && name.chars().nth(1) != Some('/') {
            return InvalidPackageNameSnafu {
                name: format!("{} (cannot start with '.')", name),
            }
            .fail();
        }

        Ok(())
    }

    /// Validate multiple package names
    /// 
    /// # Arguments
    /// * `packages` - List of package names to validate
    /// 
    /// # Returns
    /// Ok(()) if all valid, Error on first invalid package
    pub fn validate_packages(packages: &[String]) -> Result<()> {
        for pkg in packages {
            Self::validate_package_name(pkg)?;
        }
        Ok(())
    }

    /// Check if a package name looks like it includes a version specifier
    /// 
    /// # Examples
    /// - "package@1.0.0" -> true
    /// - "package" -> false
    #[allow(dead_code)]
    pub fn has_version_specifier(name: &str) -> bool {
        name.contains('@') || name.contains('^') || name.contains('~')
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_valid_package() {
        assert!(PackageValidator::validate_package_name("lodash").is_ok());
        assert!(PackageValidator::validate_package_name("@types/node").is_ok());
        assert!(PackageValidator::validate_package_name("my-package").is_ok());
        assert!(PackageValidator::validate_package_name("package_name").is_ok());
    }

    #[test]
    fn test_validate_empty_package() {
        assert!(PackageValidator::validate_package_name("").is_err());
        assert!(PackageValidator::validate_package_name("   ").is_err());
    }

    #[test]
    fn test_validate_invalid_start() {
        assert!(PackageValidator::validate_package_name(".hidden").is_err());
    }

    #[test]
    fn test_validate_multiple_packages() {
        let packages = vec!["lodash".to_string(), "react".to_string()];
        assert!(PackageValidator::validate_packages(&packages).is_ok());

        let invalid_packages = vec!["lodash".to_string(), "".to_string()];
        assert!(PackageValidator::validate_packages(&invalid_packages).is_err());
    }

    #[test]
    fn test_has_version_specifier() {
        assert!(PackageValidator::has_version_specifier("package@1.0.0"));
        assert!(PackageValidator::has_version_specifier("package^1.0.0"));
        assert!(PackageValidator::has_version_specifier("package~1.0.0"));
        assert!(!PackageValidator::has_version_specifier("package"));
    }
}
