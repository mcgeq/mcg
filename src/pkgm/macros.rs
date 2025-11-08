/// Macro to simplify package manager implementation
/// 
/// This macro reduces boilerplate code by generating the standard PackageManager
/// implementation. It requires:
/// - A struct (e.g., `Npm`)
/// - The manager name (e.g., `"npm"`)
/// - A command mapping function that returns Vec<String> (to support multi-arg commands)
#[macro_export]
macro_rules! impl_package_manager {
    (
        $struct_name:ident,
        $manager_name:literal,
        $get_command_fn:ident
    ) => {
        impl $crate::pkgm::types::PackageManager for $struct_name {
            fn name(&self) -> &'static str {
                $manager_name
            }

            fn format_command(
                &self,
                command: &str,
                packages: &[String],
                options: &$crate::pkgm::types::PackageOptions,
            ) -> String {
                $crate::pkgm::helpers::format_command_string(
                    $manager_name,
                    $get_command_fn(command),
                    packages,
                    options,
                )
            }

            fn execute_command(
                &self,
                command: &str,
                packages: &[String],
                options: &$crate::pkgm::types::PackageOptions,
            ) -> anyhow::Result<()> {
                $crate::pkgm::helpers::execute_command(
                    $manager_name,
                    $get_command_fn(command),
                    packages,
                    options,
                )
            }
        }
    };
}

