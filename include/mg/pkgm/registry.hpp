#pragma once

#include <string_view>
#include <vector>

#include <mg/core/types.hpp>

namespace mg::pkgm
{
[[nodiscard]] std::string_view get_manager_name(ManagerType manager) noexcept;
[[nodiscard]] bool append_command_args(std::vector<std::string>& argv,
                                       ManagerType manager,
                                       std::string_view action,
                                       const CommandArgs& command_args,
                                       const PackageOptions& options);
[[nodiscard]] bool action_requires_packages(std::string_view action) noexcept;
[[nodiscard]] bool action_requires_run_target(std::string_view action) noexcept;

[[nodiscard]] bool is_add_action(std::string_view action) noexcept;
[[nodiscard]] bool is_remove_action(std::string_view action) noexcept;
[[nodiscard]] bool is_upgrade_action(std::string_view action) noexcept;
[[nodiscard]] bool is_install_action(std::string_view action) noexcept;
[[nodiscard]] bool is_list_action(std::string_view action) noexcept;
[[nodiscard]] bool is_exec_action(std::string_view action) noexcept;
[[nodiscard]] bool is_run_action(std::string_view action) noexcept;
}  // namespace mg::pkgm
