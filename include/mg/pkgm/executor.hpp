#pragma once

#include <expected>
#include <filesystem>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include <mg/core/error.hpp>
#include <mg/core/types.hpp>

namespace mg::pkgm
{
[[nodiscard]] std::expected<std::vector<std::string>, MgError> build_argv(
    ManagerType manager,
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options);
[[nodiscard]] std::string format_command_preview(
    std::span<const std::string> argv,
    const std::optional<std::filesystem::path>& cwd);
[[nodiscard]] std::expected<void, MgError> run_process(
    std::span<const std::string> argv,
    const std::optional<std::filesystem::path>& cwd);
[[nodiscard]] std::expected<void, MgError> execute_argv_in_cwd(
    std::span<const std::string> argv,
    bool dry_run,
    const std::optional<std::filesystem::path>& cwd);
[[nodiscard]] std::expected<void, MgError> execute_argv(
    std::span<const std::string> argv, bool dry_run);
[[nodiscard]] std::expected<void, MgError> execute(
    ManagerType manager,
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options);

#if defined(_WIN32)
[[nodiscard]] std::optional<std::filesystem::path>
resolve_windows_command_for_test(std::string_view command);
#endif
}  // namespace mg::pkgm
