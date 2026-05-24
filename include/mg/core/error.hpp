#pragma once

#include <string_view>

namespace mg
{
enum class MgError
{
  no_package_manager,
  unsupported_manager,
  command_failed,
  manager_not_installed,
  config_parse_failed,
  config_read_failed,
  invalid_package_name,
  current_dir_failed,
  io_error,
  create_dir_failed,
  create_file_failed,
  remove_failed,
  copy_failed,
  move_failed,
  path_not_found,
  logger_init_failed,
  cache_corrupted,
  out_of_memory,
  unknown_subcommand,
  missing_subcommand,
  unknown_option,
  invalid_argument,
};

[[nodiscard]] std::string_view error_message(MgError error) noexcept;
[[nodiscard]] std::string_view error_prefix(MgError error) noexcept;
[[nodiscard]] bool is_user_facing_error(MgError error) noexcept;
}  // namespace mg
