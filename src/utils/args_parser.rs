/// Argument parser for separating packages from manager-specific arguments
pub struct ArgsParser;

impl ArgsParser {
    /// Parse arguments, separating packages (non-flag arguments) from manager-specific arguments
    /// 
    /// Packages are arguments that don't start with `-`, while manager arguments
    /// are everything after the first flag argument.
    /// 
    /// # Examples
    /// 
    /// ```
    /// use mg::utils::args_parser::ArgsParser;
    /// 
    /// let (packages, args) = ArgsParser::parse(&[
    ///     "lodash".to_string(),
    ///     "react".to_string(),
    ///     "-D".to_string(),
    ///     "--save-exact".to_string(),
    /// ]);
    /// assert_eq!(packages, vec!["lodash", "react"]);
    /// assert_eq!(args, vec!["-D", "--save-exact"]);
    /// ```
    pub fn parse(args: &[String]) -> (Vec<String>, Vec<String>) {
        let mut packages = Vec::new();
        let mut manager_args = Vec::new();
        let mut found_flag = false;

        for arg in args {
            if !found_flag && !arg.starts_with('-') {
                packages.push(arg.clone());
            } else {
                found_flag = true;
                manager_args.push(arg.clone());
            }
        }

        (packages, manager_args)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_only_packages() {
        let (packages, args) = ArgsParser::parse(&[
            "lodash".to_string(),
            "react".to_string(),
        ]);
        assert_eq!(packages, vec!["lodash", "react"]);
        assert!(args.is_empty());
    }

    #[test]
    fn test_parse_packages_and_flags() {
        let (packages, args) = ArgsParser::parse(&[
            "lodash".to_string(),
            "-D".to_string(),
            "--save-exact".to_string(),
        ]);
        assert_eq!(packages, vec!["lodash"]);
        assert_eq!(args, vec!["-D", "--save-exact"]);
    }

    #[test]
    fn test_parse_only_flags() {
        let (packages, args) = ArgsParser::parse(&[
            "-D".to_string(),
            "--save-exact".to_string(),
        ]);
        assert!(packages.is_empty());
        assert_eq!(args, vec!["-D", "--save-exact"]);
    }

    #[test]
    fn test_parse_empty() {
        let (packages, args) = ArgsParser::parse(&[]);
        assert!(packages.is_empty());
        assert!(args.is_empty());
    }

    #[test]
    fn test_parse_packages_after_flags() {
        let (packages, args) = ArgsParser::parse(&[
            "package1".to_string(),
            "-D".to_string(),
            "package2".to_string(), // This should go to args, not packages
        ]);
        assert_eq!(packages, vec!["package1"]);
        assert_eq!(args, vec!["-D", "package2"]);
    }
}
