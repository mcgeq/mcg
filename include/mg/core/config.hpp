#pragma once

#include <expected>
#include <filesystem>
#include <optional>
#include <string_view>

#include <mg/core/error.hpp>

namespace mg::config
{
struct Environment
{
  std::optional<std::filesystem::path> xdg_config_home {};
  std::optional<std::filesystem::path> xdg_cache_home {};
  std::optional<std::filesystem::path> home {};
  std::optional<std::filesystem::path> appdata {};
  std::optional<std::filesystem::path> localappdata {};
};

[[nodiscard]] Environment current_environment();
[[nodiscard]] std::optional<std::filesystem::path> find_config_file(
    std::string_view filename);
[[nodiscard]] std::optional<std::filesystem::path> find_config_file_from(
    const std::filesystem::path& start_dir, std::string_view filename);
[[nodiscard]] std::expected<std::filesystem::path, MgError> get_config_dir();
[[nodiscard]] std::expected<std::filesystem::path, MgError> get_config_dir(
    const Environment& environment);
[[nodiscard]] std::expected<std::filesystem::path, MgError> get_cache_dir();
[[nodiscard]] std::expected<std::filesystem::path, MgError> get_cache_dir(
    const Environment& environment);
}  // namespace mg::config
