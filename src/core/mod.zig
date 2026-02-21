/// Core module for mg CLI
///
/// This module provides fundamental utilities and types used throughout
/// the application, including error handling, logging, configuration, and
/// core type definitions.
const std = @import("std");

pub const Error = @import("error.zig").MgError;
pub const formatError = @import("error.zig").formatError;
pub const formatErrorWithContext = @import("error.zig").formatErrorWithContext;

pub const logger = @import("logger.zig");
pub const LogLevel = @import("logger.zig").LogLevel;
pub const Logger = @import("logger.zig").Logger;

pub const types = @import("types.zig");
pub const ManagerType = @import("types.zig").ManagerType;
pub const PackageOptions = @import("types.zig").PackageOptions;
pub const CommandArgs = @import("types.zig").CommandArgs;
pub const getManagerName = @import("types.zig").getManagerName;
pub const parseManagerType = @import("types.zig").parseManagerType;

pub const config = @import("config.zig");
