#pragma once

#include <array>
#include <cstddef>
#include <filesystem>
#include <optional>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace mg
{
enum class ManagerType : unsigned char
{
  cargo,
  npm,
  pnpm,
  bun,
  yarn,
  pip,
  uv,
  poetry,
  pdm,
};

struct PackageOptions
{
  static constexpr std::size_t max_profiles = 8;

  bool dev {false};
  std::optional<std::filesystem::path> cwd {};
  bool dry_run {false};

  [[nodiscard]] auto add_profile(std::string_view value) -> bool;
  [[nodiscard]] auto add_group(std::string_view value) -> bool;
  [[nodiscard]] auto profile_count() const noexcept -> std::size_t;
  [[nodiscard]] auto group_count() const noexcept -> std::size_t;
  [[nodiscard]] auto profile_at(std::size_t index) const noexcept
      -> std::optional<std::string_view>;
  [[nodiscard]] auto group_at(std::size_t index) const noexcept
      -> std::optional<std::string_view>;
  [[nodiscard]] auto last_explicit_profile() const noexcept
      -> std::optional<std::string_view>;
  [[nodiscard]] auto last_group() const noexcept -> std::optional<std::string_view>;
  [[nodiscard]] auto has_explicit_profile(std::string_view name) const noexcept
      -> bool;
  [[nodiscard]] auto has_explicit_group(std::string_view name) const noexcept
      -> bool;
  [[nodiscard]] auto target_profile() const noexcept
      -> std::optional<std::string_view>;
  [[nodiscard]] auto effective_profile_count() const noexcept -> std::size_t;
  [[nodiscard]] auto effective_profile_at(std::size_t index) const noexcept
      -> std::optional<std::string_view>;

private:
  std::vector<std::string> profiles_ {};
};

struct CommandArgs
{
  std::vector<std::string> packages {};
  std::vector<std::string> manager_args {};

  void add_package(std::string_view arg);
  void add_manager_arg(std::string_view arg);
};

[[nodiscard]] auto manager_name(ManagerType manager) noexcept -> std::string_view;
[[nodiscard]] auto parse_manager_type(std::string_view name) noexcept
    -> std::optional<ManagerType>;
[[nodiscard]] auto iequals(std::string_view left, std::string_view right) noexcept
    -> bool;
[[nodiscard]] auto starts_with(std::string_view value,
                               std::string_view prefix) noexcept -> bool;
[[nodiscard]] auto contains_wildcard(std::string_view value) noexcept -> bool;
[[nodiscard]] auto to_string_vector(std::span<const std::string_view> values)
    -> std::vector<std::string>;
}  // namespace mg
