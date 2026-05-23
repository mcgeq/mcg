#pragma once

#include <expected>
#include <filesystem>
#include <mg/core/error.hpp>
#include <mg/core/types.hpp>

#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace mg::pkgm
{
[[nodiscard]] auto build_argv(ManagerType manager,
                              std::string_view action,
                              const CommandArgs& command_args,
                              const PackageOptions& options)
    -> std::expected<std::vector<std::string>, MgError>;
[[nodiscard]] auto format_command_preview(std::span<const std::string> argv,
                                          const std::optional<std::filesystem::path>& cwd)
    -> std::string;
[[nodiscard]] auto run_process(std::span<const std::string> argv,
                               const std::optional<std::filesystem::path>& cwd)
    -> std::expected<void, MgError>;
[[nodiscard]] auto execute_argv_in_cwd(
    std::span<const std::string> argv,
    bool dry_run,
    const std::optional<std::filesystem::path>& cwd) -> std::expected<void, MgError>;
[[nodiscard]] auto execute_argv(std::span<const std::string> argv, bool dry_run)
    -> std::expected<void, MgError>;
[[nodiscard]] auto execute(ManagerType manager,
                           std::string_view action,
                           const CommandArgs& command_args,
                           const PackageOptions& options) -> std::expected<void, MgError>;

#if defined(_WIN32)
[[nodiscard]] auto resolve_windows_command_for_test(std::string_view command)
    -> std::optional<std::filesystem::path>;
#endif
}  // namespace mg::pkgm
