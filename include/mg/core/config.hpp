#pragma once

#include <expected>
#include <filesystem>
#include <mg/core/error.hpp>
#include <optional>
#include <string_view>

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

[[nodiscard]] auto current_environment() -> Environment;
[[nodiscard]] auto find_config_file(std::string_view filename)
    -> std::optional<std::filesystem::path>;
[[nodiscard]] auto find_config_file_from(const std::filesystem::path& start_dir,
                                         std::string_view filename)
    -> std::optional<std::filesystem::path>;
[[nodiscard]] auto get_config_dir() -> std::expected<std::filesystem::path, MgError>;
[[nodiscard]] auto get_config_dir(const Environment& environment)
    -> std::expected<std::filesystem::path, MgError>;
[[nodiscard]] auto get_cache_dir() -> std::expected<std::filesystem::path, MgError>;
[[nodiscard]] auto get_cache_dir(const Environment& environment)
    -> std::expected<std::filesystem::path, MgError>;
}  // namespace mg::config
