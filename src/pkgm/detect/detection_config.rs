use super::super::types::ManagerType;

pub struct DetectionConfig {
    pub manager_type: ManagerType,
    pub priority: u8,
    pub identifier_files: &'static [&'static str],
}

impl DetectionConfig {
    pub const fn new(manager_type: ManagerType, priority: u8, files: &'static [&'static str]) -> Self {
        Self {
            manager_type,
            priority,
            identifier_files: files,
        }
    }
}

pub const CONFIGURATIONS: &[DetectionConfig] = &[
    DetectionConfig::new(ManagerType::Cargo, 0, &["Cargo.toml"]),
    DetectionConfig::new(ManagerType::Pdm, 7, &["pdm.lock", "pyproject.toml"]),
    DetectionConfig::new(ManagerType::Poetry, 6, &["pyproject.toml"]),
    DetectionConfig::new(ManagerType::Pnpm, 1, &["pnpm-lock.yaml"]),
    DetectionConfig::new(ManagerType::Bun, 2, &["bun.lock"]),
    DetectionConfig::new(ManagerType::Yarn, 4, &["yarn.lock"]),
    DetectionConfig::new(ManagerType::Npm, 3, &["package-lock.json"]),
    DetectionConfig::new(ManagerType::Pip, 5, &["requirements.txt"]),
];
