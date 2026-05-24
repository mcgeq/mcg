#include <algorithm>
#include <cctype>

#include <mg/core/types.hpp>

namespace mg
{
namespace
{
[[nodiscard]] char lower_ascii(char ch) noexcept
{
  return static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
}
}  // namespace

bool PackageOptions::add_profile(std::string_view value)
{
  if (profiles_.size() >= max_profiles) {
    return false;
  }

  profiles_.emplace_back(value);
  return true;
}

bool PackageOptions::add_group(std::string_view value)
{
  return add_profile(value);
}

std::size_t PackageOptions::profile_count() const noexcept
{
  return profiles_.size();
}

std::size_t PackageOptions::group_count() const noexcept
{
  return profile_count();
}

std::optional<std::string_view> PackageOptions::profile_at(
    std::size_t index) const noexcept
{
  if (index >= profiles_.size()) {
    return std::nullopt;
  }

  return std::string_view {profiles_[index]};
}

std::optional<std::string_view> PackageOptions::group_at(
    std::size_t index) const noexcept
{
  return profile_at(index);
}

std::optional<std::string_view> PackageOptions::last_explicit_profile()
    const noexcept
{
  if (profiles_.empty()) {
    return std::nullopt;
  }

  return std::string_view {profiles_.back()};
}

std::optional<std::string_view> PackageOptions::last_group() const noexcept
{
  return last_explicit_profile();
}

bool PackageOptions::has_explicit_profile(std::string_view name) const noexcept
{
  return std::ranges::any_of(profiles_,
                             [name](const std::string& profile)
                             { return profile == name; });
}

bool PackageOptions::has_explicit_group(std::string_view name) const noexcept
{
  return has_explicit_profile(name);
}

std::optional<std::string_view> PackageOptions::target_profile() const noexcept
{
  if (auto profile = last_explicit_profile()) {
    return profile;
  }
  if (dev) {
    return std::string_view {"dev"};
  }
  return std::nullopt;
}

std::size_t PackageOptions::effective_profile_count() const noexcept
{
  return profiles_.size()
      + ((dev && !has_explicit_profile("dev")) ? std::size_t {1}
                                               : std::size_t {0});
}

std::optional<std::string_view> PackageOptions::effective_profile_at(
    std::size_t index) const noexcept
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

std::string_view manager_name(ManagerType manager) noexcept
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

std::optional<ManagerType> parse_manager_type(std::string_view name) noexcept
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

bool iequals(std::string_view left, std::string_view right) noexcept
{
  return left.size() == right.size()
      && std::ranges::equal(left,
                            right,
                            [](char lhs, char rhs)
                            { return lower_ascii(lhs) == lower_ascii(rhs); });
}

bool starts_with(std::string_view value, std::string_view prefix) noexcept
{
  return value.size() >= prefix.size()
      && value.substr(0, prefix.size()) == prefix;
}

bool contains_wildcard(std::string_view value) noexcept
{
  return value.find('*') != std::string_view::npos
      || value.find('?') != std::string_view::npos;
}

std::vector<std::string> to_string_vector(
    std::span<const std::string_view> values)
{
  auto out = std::vector<std::string> {};
  out.reserve(values.size());
  for (auto value : values) {
    out.emplace_back(value);
  }
  return out;
}
}  // namespace mg
