#pragma once

#include <expected>
#include <filesystem>
#include <mg/core/error.hpp>
#include <mg/core/types.hpp>

#include <optional>
#include <string_view>
#include <vector>

namespace mg::pkgm
{
struct PlannedCommand
{
  ManagerType manager_type;
  std::vector<std::string> argv;
};

[[nodiscard]] auto plan_command(std::string_view action,
                                const CommandArgs& command_args,
                                const PackageOptions& options)
    -> std::expected<PlannedCommand, MgError>;
[[nodiscard]] auto plan_command_from_path(const std::filesystem::path& start_dir,
                                          std::string_view action,
                                          const CommandArgs& command_args,
                                          const PackageOptions& options)
    -> std::expected<PlannedCommand, MgError>;
[[nodiscard]] auto execute_command(std::string_view action,
                                   const CommandArgs& command_args,
                                   const PackageOptions& options)
    -> std::expected<void, MgError>;
}  // namespace mg::pkgm
