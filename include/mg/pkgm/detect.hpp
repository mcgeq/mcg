#pragma once

#include <mg/core/types.hpp>

#include <filesystem>
#include <optional>
#include <string_view>

namespace mg::pkgm
{
[[nodiscard]] auto detect_package_manager() -> std::optional<ManagerType>;
[[nodiscard]] auto detect_package_manager_from_path(
    const std::filesystem::path& start_dir) -> std::optional<ManagerType>;
[[nodiscard]] auto detect_package_manager_for_command(
    std::string_view action,
    const CommandArgs& command_args) -> std::optional<ManagerType>;
[[nodiscard]] auto detect_package_manager_for_command_from_path(
    const std::filesystem::path& start_dir,
    std::string_view action,
    const CommandArgs& command_args) -> std::optional<ManagerType>;
}  // namespace mg::pkgm
