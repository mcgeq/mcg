use crate::pkgm::types::{ManagerType, PackageManager};
use crate::utils::error::{Result, UnsupportedManagerSnafu};
use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::sync::Mutex;

type ManagerFactory = Box<dyn Fn() -> Box<dyn PackageManager> + Send + Sync>;

/// Package manager registry for managing available package managers
pub struct ManagerRegistry {
    factories: HashMap<ManagerType, ManagerFactory>,
}

impl ManagerRegistry {
    /// Create a new empty registry
    fn new() -> Self {
        Self {
            factories: HashMap::new(),
        }
    }

    /// Register a package manager with its factory function
    /// 
    /// # Arguments
    /// * `manager_type` - The type of package manager to register
    /// * `factory` - Factory function that creates an instance of the package manager
    pub fn register<F>(&mut self, manager_type: ManagerType, factory: F)
    where
        F: Fn() -> Box<dyn PackageManager> + Send + Sync + 'static,
    {
        tracing::debug!(manager = ?manager_type, "Registered package manager");
        self.factories.insert(manager_type, Box::new(factory));
    }

    /// Create a package manager instance from the registry
    /// 
    /// # Arguments
    /// * `manager_type` - The type of package manager to create
    /// 
    /// # Returns
    /// A boxed instance of the package manager, or an error if not found
    pub fn create(&self, manager_type: &ManagerType) -> Result<Box<dyn PackageManager>> {
        self.factories
            .get(manager_type)
            .map(|factory| factory())
            .ok_or_else(|| {
                UnsupportedManagerSnafu {
                    name: format!("{:?}", manager_type),
                }
                .build()
            })
    }

    /// Check if a package manager is registered
    #[allow(dead_code)]
    pub fn is_registered(&self, manager_type: &ManagerType) -> bool {
        self.factories.contains_key(manager_type)
    }

    /// Get list of all registered package manager types
    #[allow(dead_code)]
    pub fn registered_managers(&self) -> Vec<ManagerType> {
        self.factories.keys().cloned().collect()
    }
}

/// Global registry instance
static REGISTRY: Lazy<Mutex<ManagerRegistry>> = Lazy::new(|| {
    let mut registry = ManagerRegistry::new();

    // Register all built-in package managers
    registry.register(ManagerType::Cargo, || {
        Box::new(crate::pkgm::cargo::Cargo)
    });
    registry.register(ManagerType::Npm, || Box::new(crate::pkgm::npm::Npm));
    registry.register(ManagerType::Pnpm, || {
        Box::new(crate::pkgm::pnpm::Pnpm)
    });
    registry.register(ManagerType::Bun, || Box::new(crate::pkgm::bun::Bun));
    registry.register(ManagerType::Yarn, || {
        Box::new(crate::pkgm::yarn::Yarn)
    });
    registry.register(ManagerType::Pip, || Box::new(crate::pkgm::pip::Pip));
    registry.register(ManagerType::Pdm, || Box::new(crate::pkgm::pdm::Pdm));
    registry.register(ManagerType::Poetry, || {
        Box::new(crate::pkgm::poetry::Poetry)
    });

    tracing::debug!("Initialized package manager registry");
    Mutex::new(registry)
});

/// Create a package manager instance from the global registry
/// 
/// # Arguments
/// * `manager_type` - The type of package manager to create
/// 
/// # Returns
/// A boxed instance of the package manager
pub fn create_manager(manager_type: &ManagerType) -> Result<Box<dyn PackageManager>> {
    REGISTRY
        .lock()
        .map_err(|_| {
            UnsupportedManagerSnafu {
                name: "Registry lock poisoned".to_string(),
            }
            .build()
        })?
        .create(manager_type)
}

/// Register a custom package manager in the global registry
/// 
/// This allows external code to register additional package managers
#[allow(dead_code)]
pub fn register_manager<F>(manager_type: ManagerType, factory: F) -> Result<()>
where
    F: Fn() -> Box<dyn PackageManager> + Send + Sync + 'static,
{
    REGISTRY
        .lock()
        .map_err(|_| {
            UnsupportedManagerSnafu {
                name: "Registry lock poisoned".to_string(),
            }
            .build()
        })?
        .register(manager_type, factory);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_registry_create_cargo() {
        let manager = create_manager(&ManagerType::Cargo);
        assert!(manager.is_ok());
        assert_eq!(manager.unwrap().name(), "cargo");
    }

    #[test]
    fn test_registry_create_npm() {
        let manager = create_manager(&ManagerType::Npm);
        assert!(manager.is_ok());
        assert_eq!(manager.unwrap().name(), "npm");
    }

    #[test]
    fn test_registry_all_managers() {
        let registry = REGISTRY.lock().unwrap();
        let managers = registry.registered_managers();
        
        assert!(managers.contains(&ManagerType::Cargo));
        assert!(managers.contains(&ManagerType::Npm));
        assert!(managers.contains(&ManagerType::Pnpm));
        assert!(managers.contains(&ManagerType::Bun));
        assert!(managers.contains(&ManagerType::Yarn));
        assert!(managers.contains(&ManagerType::Pip));
        assert!(managers.contains(&ManagerType::Pdm));
        assert!(managers.contains(&ManagerType::Poetry));
    }
}
