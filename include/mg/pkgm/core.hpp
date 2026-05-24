#pragma once

#include <expected>
#include <filesystem>
#include <optional>
#include <string_view>
#include <vector>

#include <mg/core/error.hpp>
#include <mg/core/types.hpp>

namespace mg::pkgm
{
struct PlannedCommand
{
  ManagerType manager_type;
  std::vector<std::string> argv;
};

[[nodiscard]] std::expected<PlannedCommand, MgError> plan_command(
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options);
[[nodiscard]] std::expected<PlannedCommand, MgError> plan_command_from_path(
    const std::filesystem::path& start_dir,
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options);
[[nodiscard]] std::expected<void, MgError> execute_command(
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options);
}  // namespace mg::pkgm
