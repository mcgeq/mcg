#pragma once

#include <filesystem>
#include <optional>
#include <string_view>

#include <mg/core/types.hpp>

namespace mg::pkgm
{
[[nodiscard]] std::optional<ManagerType> detect_package_manager();
[[nodiscard]] std::optional<ManagerType> detect_package_manager_from_path(
    const std::filesystem::path& start_dir);
[[nodiscard]] std::optional<ManagerType> detect_package_manager_for_command(
    std::string_view action, const CommandArgs& command_args);
[[nodiscard]] std::optional<ManagerType>
detect_package_manager_for_command_from_path(
    const std::filesystem::path& start_dir,
    std::string_view action,
    const CommandArgs& command_args);
}  // namespace mg::pkgm
