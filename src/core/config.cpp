#include <cstdlib>
#include <memory>
#include <string>

#include <mg/core/config.hpp>

namespace mg::config
{
namespace
{
[[nodiscard]] std::optional<std::filesystem::path> environment_path(
    const char* name)
{
#if defined(_MSC_VER)
  auto* buffer = static_cast<char*>(nullptr);
  auto size = std::size_t {};
  if (_dupenv_s(&buffer, &size, name) != 0 || buffer == nullptr) {
    return std::nullopt;
  }

  auto cleanup =
      std::unique_ptr<char, decltype(&std::free)> {buffer, std::free};
  if (size <= 1U || buffer[0] == '\0') {
    return std::nullopt;
  }

  return std::filesystem::path {buffer};
#else
  const auto* value = std::getenv(name);
  if (value == nullptr || value[0] == '\0') {
    return std::nullopt;
  }

  return std::filesystem::path {value};
#endif
}
}  // namespace

Environment current_environment()
{
  return Environment {
      .xdg_config_home = environment_path("XDG_CONFIG_HOME"),
      .xdg_cache_home = environment_path("XDG_CACHE_HOME"),
      .home = environment_path("HOME"),
      .appdata = environment_path("APPDATA"),
      .localappdata = environment_path("LOCALAPPDATA"),
  };
}

std::optional<std::filesystem::path> find_config_file(std::string_view filename)
{
  auto ec = std::error_code {};
  const auto current = std::filesystem::current_path(ec);
  if (ec) {
    return std::nullopt;
  }

  return find_config_file_from(current, filename);
}

std::optional<std::filesystem::path> find_config_file_from(
    const std::filesystem::path& start_dir, std::string_view filename)
{
  const auto name = std::filesystem::path {filename};
  if (name.empty()) {
    return std::nullopt;
  }

  auto ec = std::error_code {};
  if (name.is_absolute()) {
    return std::filesystem::exists(name, ec) && !ec
        ? std::optional<std::filesystem::path> {name}
        : std::nullopt;
  }

  auto current =
      start_dir.empty() ? std::filesystem::current_path(ec) : start_dir;
  if (ec) {
    return std::nullopt;
  }

  if (!current.is_absolute()) {
    current = std::filesystem::absolute(current, ec);
    if (ec) {
      return std::nullopt;
    }
  }

  while (true) {
    const auto candidate = current / name;
    ec.clear();
    if (std::filesystem::exists(candidate, ec) && !ec) {
      return candidate;
    }

    const auto parent = current.parent_path();
    if (parent.empty() || parent == current) {
      return std::nullopt;
    }
    current = parent;
  }
}

std::expected<std::filesystem::path, MgError> get_config_dir()
{
  return get_config_dir(current_environment());
}

std::expected<std::filesystem::path, MgError> get_config_dir(
    const Environment& environment)
{
  if (environment.xdg_config_home) {
    return *environment.xdg_config_home / "mg";
  }

  if (environment.home) {
    return *environment.home / ".config" / "mg";
  }

  if (environment.appdata) {
    return *environment.appdata / "mg";
  }

  return std::unexpected {MgError::io_error};
}

std::expected<std::filesystem::path, MgError> get_cache_dir()
{
  return get_cache_dir(current_environment());
}

std::expected<std::filesystem::path, MgError> get_cache_dir(
    const Environment& environment)
{
  if (environment.xdg_cache_home) {
    return *environment.xdg_cache_home / "mg";
  }

  if (environment.home) {
    return *environment.home / ".cache" / "mg";
  }

  if (environment.localappdata) {
    return *environment.localappdata / "mg" / "cache";
  }

  return std::unexpected {MgError::io_error};
}
}  // namespace mg::config
