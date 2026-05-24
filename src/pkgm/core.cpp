#include <filesystem>

#include <mg/core/logger.hpp>
#include <mg/pkgm/core.hpp>
#include <mg/pkgm/detect.hpp>
#include <mg/pkgm/executor.hpp>
#include <mg/pkgm/registry.hpp>

namespace mg::pkgm
{
std::expected<PlannedCommand, MgError> plan_command(
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options)
{
  return plan_command_from_path(
      std::filesystem::current_path(), action, command_args, options);
}

std::expected<PlannedCommand, MgError> plan_command_from_path(
    const std::filesystem::path& start_dir,
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options)
{
  const auto manager = detect_package_manager_for_command_from_path(
      start_dir, action, command_args);
  if (!manager) {
    return std::unexpected {MgError::no_package_manager};
  }

  auto argv = build_argv(*manager, action, command_args, options);
  if (!argv) {
    return std::unexpected {argv.error()};
  }

  return PlannedCommand {
      .manager_type = *manager,
      .argv = std::move(*argv),
  };
}

std::expected<void, MgError> execute_command(std::string_view action,
                                             const CommandArgs& command_args,
                                             const PackageOptions& options)
{
  const auto start_dir = options.cwd.value_or(std::filesystem::current_path());
  auto planned =
      plan_command_from_path(start_dir, action, command_args, options);
  if (!planned) {
    if (planned.error() == MgError::no_package_manager) {
      log_error("No supported package manager detected");
    } else if (planned.error() == MgError::unknown_subcommand) {
      log_error("Unknown package command: {}", action);
    }
    return std::unexpected {planned.error()};
  }

  log_info("Using {} package manager", get_manager_name(planned->manager_type));
  return execute_argv_in_cwd(planned->argv, options.dry_run, options.cwd);
}
}  // namespace mg::pkgm
