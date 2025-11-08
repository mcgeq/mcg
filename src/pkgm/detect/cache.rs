use crate::pkgm::types::ManagerType;
use once_cell::sync::Lazy;
use std::path::PathBuf;
use std::sync::Mutex;

/// Cache entry for detection results
#[derive(Debug, Clone)]
struct CacheEntry {
    directory: PathBuf,
    manager_type: ManagerType,
}

/// Global cache for package manager detection results
static DETECTION_CACHE: Lazy<Mutex<Option<CacheEntry>>> = Lazy::new(|| Mutex::new(None));

/// Get cached manager for the current directory, if available
pub fn get_cached_manager() -> Option<ManagerType> {
    let cache = DETECTION_CACHE.lock().ok()?;
    let entry = cache.as_ref()?;
    
    std::env::current_dir()
        .ok()
        .and_then(|current_dir| {
            // Check if we're in the same directory or a subdirectory
            if current_dir.starts_with(&entry.directory) {
                tracing::debug!(
                    manager = ?entry.manager_type,
                    directory = %entry.directory.display(),
                    "Cache hit: Using cached manager"
                );
                Some(entry.manager_type.clone())
            } else {
                tracing::debug!(
                    current_dir = %current_dir.display(),
                    cache_dir = %entry.directory.display(),
                    "Cache miss: Current directory doesn't match cache directory"
                );
                None
            }
        })
}

/// Set cached manager for the current directory
pub fn set_cached_manager(manager_type: ManagerType) {
    if let Ok(current_dir) = std::env::current_dir() {
        if let Ok(mut cache) = DETECTION_CACHE.lock() {
            *cache = Some(CacheEntry {
                directory: current_dir.clone(),
                manager_type: manager_type.clone(),
            });
            tracing::debug!(
                manager = ?manager_type,
                directory = %current_dir.display(),
                "Cached manager for directory"
            );
        }
    }
}

/// Clear the detection cache
/// 
/// This function is useful for testing or when you want to force
/// re-detection of the package manager.
#[allow(dead_code)] // Used in tests and may be useful as a public API
pub fn clear_cache() {
    if let Ok(mut cache) = DETECTION_CACHE.lock() {
        *cache = None;
        tracing::debug!("Detection cache cleared");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::fs;

    #[test]
    fn test_cache_set_and_get() {
        let temp_dir = TempDir::new().unwrap();
        std::env::set_current_dir(temp_dir.path()).unwrap();
        
        set_cached_manager(ManagerType::Cargo);
        let cached = get_cached_manager();
        assert_eq!(cached, Some(ManagerType::Cargo));
    }

    #[test]
    fn test_cache_subdirectory() {
        let temp_dir = TempDir::new().unwrap();
        std::env::set_current_dir(temp_dir.path()).unwrap();
        
        set_cached_manager(ManagerType::Npm);
        
        let subdir = temp_dir.path().join("sub");
        fs::create_dir(&subdir).unwrap();
        std::env::set_current_dir(&subdir).unwrap();
        
        let cached = get_cached_manager();
        assert_eq!(cached, Some(ManagerType::Npm));
    }

    #[test]
    fn test_cache_clear() {
        let temp_dir = TempDir::new().unwrap();
        std::env::set_current_dir(temp_dir.path()).unwrap();
        
        set_cached_manager(ManagerType::Cargo);
        clear_cache();
        let cached = get_cached_manager();
        assert_eq!(cached, None);
    }
}

