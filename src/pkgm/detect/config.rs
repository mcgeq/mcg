use super::super::types::ManagerType;

pub const CONFIGURATIONS: &[(ManagerType, &[&str])] = &[
    (ManagerType::Cargo, &["Cargo.toml"]),
    (ManagerType::Pdm, &["pdm.lock", "pyproject.toml"]),
    (ManagerType::Poetry, &["pyproject.toml"]),
    (ManagerType::Pnpm, &["pnpm-lock.yaml"]),
    (ManagerType::Yarn, &["yarn.lock"]),
    (ManagerType::Npm, &["package-lock.json", "package.json"]),
    (ManagerType::Pip, &["requirements.txt"]),
];

pub struct DetectionConfig {
    pub priority: u8,
    pub identifier_files: &'static [&'static str],
}

impl DetectionConfig {
    pub const fn new(priority: u8, files: &'static [&'static str]) -> Self {
        Self {
            priority,
            identifier_files: files,
        }
    }
}
