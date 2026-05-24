#include <mg/core/error.hpp>

namespace mg
{
std::string_view error_message(MgError error) noexcept
{
  switch (error) {
    case MgError::no_package_manager:
      return "No supported package manager detected in current directory";
    case MgError::unsupported_manager:
      return "Unsupported package manager";
    case MgError::command_failed:
      return "Command execution failed";
    case MgError::manager_not_installed:
      return "Package manager not found in PATH";
    case MgError::config_parse_failed:
      return "Failed to parse configuration file";
    case MgError::config_read_failed:
      return "Failed to read configuration file";
    case MgError::invalid_package_name:
      return "Invalid package name";
    case MgError::current_dir_failed:
      return "Failed to get current directory";
    case MgError::io_error:
      return "I/O error occurred";
    case MgError::create_dir_failed:
      return "Failed to create directory";
    case MgError::create_file_failed:
      return "Failed to create file";
    case MgError::remove_failed:
      return "Failed to remove path";
    case MgError::copy_failed:
      return "Failed to copy file or directory";
    case MgError::move_failed:
      return "Failed to move file or directory";
    case MgError::path_not_found:
      return "Path not found";
    case MgError::logger_init_failed:
      return "Failed to initialize logger";
    case MgError::cache_corrupted:
      return "Cache file is corrupted";
    case MgError::out_of_memory:
      return "Out of memory";
    case MgError::unknown_subcommand:
      return "Unknown subcommand";
    case MgError::missing_subcommand:
      return "Missing subcommand";
    case MgError::unknown_option:
      return "Unknown option";
    case MgError::invalid_argument:
      return "Invalid argument";
  }

  return "Unknown error";
}

std::string_view error_prefix(MgError error) noexcept
{
  switch (error) {
    case MgError::command_failed:
      return "Command failed";
    case MgError::manager_not_installed:
      return "Manager not installed";
    default:
      return "Error";
  }
}

bool is_user_facing_error(MgError error) noexcept
{
  switch (error) {
    case MgError::no_package_manager:
    case MgError::unsupported_manager:
    case MgError::command_failed:
    case MgError::manager_not_installed:
    case MgError::config_parse_failed:
    case MgError::config_read_failed:
    case MgError::invalid_package_name:
    case MgError::current_dir_failed:
    case MgError::io_error:
    case MgError::create_dir_failed:
    case MgError::create_file_failed:
    case MgError::remove_failed:
    case MgError::copy_failed:
    case MgError::move_failed:
    case MgError::path_not_found:
    case MgError::logger_init_failed:
    case MgError::cache_corrupted:
    case MgError::unknown_subcommand:
    case MgError::missing_subcommand:
    case MgError::unknown_option:
    case MgError::invalid_argument:
      return true;
    case MgError::out_of_memory:
      return false;
  }

  return false;
}
}  // namespace mg
