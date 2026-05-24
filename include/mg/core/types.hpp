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

  [[nodiscard]] bool add_profile(std::string_view value);
  [[nodiscard]] bool add_group(std::string_view value);
  [[nodiscard]] std::size_t profile_count() const noexcept;
  [[nodiscard]] std::size_t group_count() const noexcept;
  [[nodiscard]] std::optional<std::string_view> profile_at(
      std::size_t index) const noexcept;
  [[nodiscard]] std::optional<std::string_view> group_at(
      std::size_t index) const noexcept;
  [[nodiscard]] std::optional<std::string_view> last_explicit_profile()
      const noexcept;
  [[nodiscard]] std::optional<std::string_view> last_group() const noexcept;
  [[nodiscard]] bool has_explicit_profile(std::string_view name) const noexcept;
  [[nodiscard]] bool has_explicit_group(std::string_view name) const noexcept;
  [[nodiscard]] std::optional<std::string_view> target_profile() const noexcept;
  [[nodiscard]] std::size_t effective_profile_count() const noexcept;
  [[nodiscard]] std::optional<std::string_view> effective_profile_at(
      std::size_t index) const noexcept;

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

[[nodiscard]] std::string_view manager_name(ManagerType manager) noexcept;
[[nodiscard]] std::optional<ManagerType> parse_manager_type(
    std::string_view name) noexcept;
[[nodiscard]] bool iequals(std::string_view left,
                           std::string_view right) noexcept;
[[nodiscard]] bool starts_with(std::string_view value,
                               std::string_view prefix) noexcept;
[[nodiscard]] bool contains_wildcard(std::string_view value) noexcept;
[[nodiscard]] std::vector<std::string> to_string_vector(
    std::span<const std::string_view> values);
}  // namespace mg
