#pragma once

#include <mg/core/types.hpp>

#include <string_view>
#include <vector>

namespace mg::pkgm
{
[[nodiscard]] auto get_manager_name(ManagerType manager) noexcept -> std::string_view;
[[nodiscard]] auto append_command_args(std::vector<std::string>& argv,
                                       ManagerType manager,
                                       std::string_view action,
                                       const CommandArgs& command_args,
                                       const PackageOptions& options) -> bool;
[[nodiscard]] auto action_requires_packages(std::string_view action) noexcept -> bool;
[[nodiscard]] auto action_requires_run_target(std::string_view action) noexcept
    -> bool;

[[nodiscard]] auto is_add_action(std::string_view action) noexcept -> bool;
[[nodiscard]] auto is_remove_action(std::string_view action) noexcept -> bool;
[[nodiscard]] auto is_upgrade_action(std::string_view action) noexcept -> bool;
[[nodiscard]] auto is_install_action(std::string_view action) noexcept -> bool;
[[nodiscard]] auto is_list_action(std::string_view action) noexcept -> bool;
[[nodiscard]] auto is_exec_action(std::string_view action) noexcept -> bool;
[[nodiscard]] auto is_run_action(std::string_view action) noexcept -> bool;
}  // namespace mg::pkgm
