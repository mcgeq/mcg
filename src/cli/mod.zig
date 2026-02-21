/// CLI module for mg.
///
/// This module provides command-line interface functionality including
/// argument parsing and help text display.
pub const parser = @import("parser.zig");
pub const help = @import("help.zig");

// Re-export commonly used types
pub const ParseResult = parser.ParseResult;
pub const Options = parser.Options;
pub const parseOptions = parser.parseOptions;
pub const parse = parser.parse;
