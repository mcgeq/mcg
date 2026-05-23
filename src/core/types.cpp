#include <mg/core/types.hpp>

#include <algorithm>
#include <cctype>

namespace mg
{
namespace
{
[[nodiscard]] auto lower_ascii(char ch) noexcept -> char
{
  return static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
}
}  // namespace

auto PackageOptions::add_profile(std::string_view value) -> bool
{
  if (profiles_.size() >= max_profiles) {
    return false;
  }

  profiles_.emplace_back(value);
  return true;
}

auto PackageOptions::add_group(std::string_view value) -> bool
{
  return add_profile(value);
}

auto PackageOptions::profile_count() const noexcept -> std::size_t
{
  return profiles_.size();
}

auto PackageOptions::group_count() const noexcept -> std::size_t
{
  return profile_count();
}

auto PackageOptions::profile_at(std::size_t index) const noexcept
    -> std::optional<std::string_view>
{
  if (index >= profiles_.size()) {
    return std::nullopt;
  }

  return std::string_view {profiles_[index]};
}

auto PackageOptions::group_at(std::size_t index) const noexcept
    -> std::optional<std::string_view>
{
  return profile_at(index);
}

auto PackageOptions::last_explicit_profile() const noexcept
    -> std::optional<std::string_view>
{
  if (profiles_.empty()) {
    return std::nullopt;
  }

  return std::string_view {profiles_.back()};
}

auto PackageOptions::last_group() const noexcept -> std::optional<std::string_view>
{
  return last_explicit_profile();
}

auto PackageOptions::has_explicit_profile(std::string_view name) const noexcept
    -> bool
{
  return std::ranges::any_of(profiles_, [name](const std::string& profile) {
    return profile == name;
  });
}

auto PackageOptions::has_explicit_group(std::string_view name) const noexcept
    -> bool
{
  return has_explicit_profile(name);
}

auto PackageOptions::target_profile() const noexcept
    -> std::optional<std::string_view>
{
  if (auto profile = last_explicit_profile()) {
    return profile;
  }
  if (dev) {
    return std::string_view {"dev"};
  }
  return std::nullopt;
}

auto PackageOptions::effective_profile_count() const noexcept -> std::size_t
{
  return profiles_.size()
      + ((dev && !has_explicit_profile("dev")) ? std::size_t {1} : std::size_t {0});
}

auto PackageOptions::effective_profile_at(std::size_t index) const noexcept
    -> std::optional<std::string_view>
{
  const auto include_dev = dev && !has_explicit_profile("dev");
  if (include_dev) {
    if (index == 0) {
      return std::string_view {"dev"};
    }
    return profile_at(index - 1);
  }

  return profile_at(index);
}

void CommandArgs::add_package(std::string_view arg)
{
  packages.emplace_back(arg);
}

void CommandArgs::add_manager_arg(std::string_view arg)
{
  manager_args.emplace_back(arg);
}

auto manager_name(ManagerType manager) noexcept -> std::string_view
{
  switch (manager) {
    case ManagerType::cargo:
      return "cargo";
    case ManagerType::npm:
      return "npm";
    case ManagerType::pnpm:
      return "pnpm";
    case ManagerType::bun:
      return "bun";
    case ManagerType::yarn:
      return "yarn";
    case ManagerType::pip:
      return "pip";
    case ManagerType::uv:
      return "uv";
    case ManagerType::poetry:
      return "poetry";
    case ManagerType::pdm:
      return "pdm";
  }

  return "unknown";
}

auto parse_manager_type(std::string_view name) noexcept
    -> std::optional<ManagerType>
{
  if (iequals(name, "cargo")) {
    return ManagerType::cargo;
  }
  if (iequals(name, "npm")) {
    return ManagerType::npm;
  }
  if (iequals(name, "pnpm")) {
    return ManagerType::pnpm;
  }
  if (iequals(name, "bun")) {
    return ManagerType::bun;
  }
  if (iequals(name, "yarn")) {
    return ManagerType::yarn;
  }
  if (iequals(name, "pip")) {
    return ManagerType::pip;
  }
  if (iequals(name, "uv")) {
    return ManagerType::uv;
  }
  if (iequals(name, "poetry")) {
    return ManagerType::poetry;
  }
  if (iequals(name, "pdm")) {
    return ManagerType::pdm;
  }

  return std::nullopt;
}

auto iequals(std::string_view left, std::string_view right) noexcept -> bool
{
  return left.size() == right.size()
      && std::ranges::equal(left, right, [](char lhs, char rhs) {
           return lower_ascii(lhs) == lower_ascii(rhs);
         });
}

auto starts_with(std::string_view value, std::string_view prefix) noexcept -> bool
{
  return value.size() >= prefix.size() && value.substr(0, prefix.size()) == prefix;
}

auto contains_wildcard(std::string_view value) noexcept -> bool
{
  return value.find('*') != std::string_view::npos
      || value.find('?') != std::string_view::npos;
}

auto to_string_vector(std::span<const std::string_view> values)
    -> std::vector<std::string>
{
  auto out = std::vector<std::string> {};
  out.reserve(values.size());
  for (auto value : values) {
    out.emplace_back(value);
  }
  return out;
}
}  // namespace mg
