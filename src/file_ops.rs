// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           file_ops.rs
// Description:    About file operations
// Create   Date:  2025-02-15 10:55:45
// Last Modified:  2025-02-15 11:54:38
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::{fs, path::Path};

use crate::utils::{error_message, success_message};

pub fn create_fir(path: &str, parents: bool) -> Result<(), String> {
    let path = Path::new(path);

    if parents {
        fs::create_dir_all(path)
    } else {
        fs::create_dir(path)
    }.map_err(|e| error_message(&format!("Failed to create directory: {}", e)))?;

    println!("{} '{}'", success_message("Director created successfully"), path.display());
    Ok(())
}

pub fn remove_dir(path: &str, force: bool) -> Result<(), String> {
    let path = Path::new(path);

    if force {
        fs::remove_dir_all(path)
    } else {
        fs::remove_dir(path)
    }.map_err(|e| error_message(&format!("Failed to remove director: {}", e)))?;

    println!("{} '{}", success_message("Director removed successfully"), path.display());
    Ok(())
}

pub fn copy_dir(src: &str, dest: &str) -> Result<(), String> {
    let src_path = Path::new(src);
    let dest_path = Path::new(dest);

    if !src_path.exists() {
        return Err(error_message(&format!("Source director '{}' does not exist", src)));
    }

    if dest_path.exists() {
        return Err(error_message(&format!("Destination director '{}' already exists", dest)));
    }

    fs::create_dir_all(dest_path)
        .map_err(|e| error_message(&format!("Failed to create destination director: {}", e)))?;

    for entry in fs::read_dir(src_path)
        .map_err(|e| error_message(&format!("Failed to read source director: {}", e)))? {
        let entry = entry.map_err(|e| error_message(&format!("Failed to read director entry: {}", e)))?;
        let entry_path = entry.path();
        let dest_entry_path = dest_path.join(entry.file_name());

        if entry_path.is_dir() {
            copy_dir(entry_path.to_str().unwrap(), dest_entry_path.to_str().unwrap())?;
        } else {
            fs::copy(&entry_path, &dest_entry_path)
                .map_err(|e| error_message(&format!("Failed to copy file: {}", e)))?;
        }
    }

    println!("{} '{}' -> '{}'", success_message("Director copied successfully"), src, dest);
    Ok(())
}

pub fn create_file(filename: &str) -> Result<(), String> {
    fs::File::create(filename)
        .map_err(|e| error_message(&format!("Failed to create file: {}", e)))?;
    println!("{} '{}'", success_message("File created successfully"), filename);
    Ok(())
}

pub fn remove_file(path: &str) -> Result<(), String> {
    fs::remove_file(path)
        .map_err(|e| error_message(&format!("Failed to remove file: {}", e)))?;
    println!("{} '{}'", success_message("File removed successfully"), path);
    Ok(())
}

pub fn copy_file(src: &str, dest: &str) -> Result<(), String> {
    fs::copy(src, dest)
        .map_err(|e| error_message(&format!("Failed to copy file: {}", e)))?;
    println!("{} '{}' -> '{}'", success_message("File copied successfully"), src, dest);
    Ok(())
}
