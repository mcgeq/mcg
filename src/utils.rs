// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           utils.rs
// Description:    About utils.
// Create   Date:  2025-02-15 11:00:02
// Last Modified:  2025-02-15 11:01:47
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use colored::Colorize;

// 统一颜色输出风格
pub fn success_message(msg: &str) -> String {
    format!("✅ {}", msg.green())
}

pub fn error_message(msg: &str) -> String {
    format!("❌ {} ", msg.red())
}

pub fn warning_message(msg: &str) -> String {
    format!("⚠️  {} ", msg.yellow())
}

pub fn info_message(msg: &str) -> String {
    format!("ℹ️  {} ", msg.blue())
}
