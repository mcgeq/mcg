#include <cctype>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <format>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>
#include <vector>

#include <mg/core/logger.hpp>
#include <mg/pkgm/executor.hpp>
#include <mg/pkgm/registry.hpp>

#if defined(_WIN32)
#  include <process.h>
#  if !defined(_MSC_VER)
#    if !defined(NOMINMAX)
#      define NOMINMAX
#    endif
#    if !defined(WIN32_LEAN_AND_MEAN)
#      define WIN32_LEAN_AND_MEAN
#    endif
#    include <windows.h>
#  endif
#else
#  include <sys/wait.h>
#  include <unistd.h>
#endif

namespace mg::pkgm
{
namespace
{
[[nodiscard]] bool preview_token_needs_quoting(std::string_view token) noexcept
{
  if (token.empty()) {
    return true;
  }

  return token.find_first_of(" \t\n\r\"'") != std::string_view::npos;
}

void append_preview_token(std::string& out, std::string_view token)
{
  if (!preview_token_needs_quoting(token)) {
    out += token;
    return;
  }

  out += '"';
  for (const auto ch : token) {
    switch (ch) {
      case '"':
        out += "\\\"";
        break;
      case '\\':
        out += "\\\\";
        break;
      case '\n':
        out += "\\n";
        break;
      case '\r':
        out += "\\r";
        break;
      case '\t':
        out += "\\t";
        break;
      default:
        out += ch;
        break;
    }
  }
  out += '"';
}

[[nodiscard]] std::vector<char*> make_c_argv(std::span<const std::string> argv)
{
  auto c_argv = std::vector<char*> {};
  c_argv.reserve(argv.size() + 1);
  for (const auto& arg : argv) {
    c_argv.push_back(const_cast<char*>(arg.c_str()));
  }
  c_argv.push_back(nullptr);
  return c_argv;
}

#if defined(_WIN32)
[[nodiscard]] bool iequals_ascii(std::string_view left,
                                 std::string_view right) noexcept
{
  if (left.size() != right.size()) {
    return false;
  }

  for (auto index = std::size_t {}; index < left.size(); ++index) {
    const auto lhs = static_cast<unsigned char>(left[index]);
    const auto rhs = static_cast<unsigned char>(right[index]);
    if (std::tolower(lhs) != std::tolower(rhs)) {
      return false;
    }
  }

  return true;
}

[[nodiscard]] std::vector<std::string> split_windows_list(
    std::string_view value, char separator)
{
  auto parts = std::vector<std::string> {};
  auto begin = std::size_t {};
  while (begin <= value.size()) {
    const auto end = value.find(separator, begin);
    const auto part = value.substr(
        begin,
        end == std::string_view::npos ? std::string_view::npos : end - begin);
    if (!part.empty()) {
      parts.emplace_back(part);
    }
    if (end == std::string_view::npos) {
      break;
    }
    begin = end + 1;
  }
  return parts;
}

[[nodiscard]] std::optional<std::string> read_windows_env(std::string_view name)
{
#  if defined(_MSC_VER)
  char* raw_value = nullptr;
  size_t raw_size = 0;
  const auto key = std::string {name};
  if (_dupenv_s(&raw_value, &raw_size, key.c_str()) != 0
      || raw_value == nullptr)
  {
    return std::nullopt;
  }

  auto guard =
      std::unique_ptr<char, decltype(&std::free)> {raw_value, &std::free};
  auto value = std::string {guard.get()};
  if (value.empty()) {
    return std::nullopt;
  }

  return value;
#  else
  const auto key = std::string {name};
  const auto required_size = GetEnvironmentVariableA(key.c_str(), nullptr, 0);
  if (required_size == 0) {
    return std::nullopt;
  }

  auto value = std::string(required_size, '\0');
  const auto written_size =
      GetEnvironmentVariableA(key.c_str(), value.data(), required_size);
  if (written_size == 0 || written_size >= required_size) {
    return std::nullopt;
  }

  value.resize(written_size);
  return std::string {value};
#  endif
}

[[nodiscard]] std::vector<std::string> windows_path_extensions()
{
  const auto pathext = read_windows_env("PATHEXT");
  if (pathext.has_value()) {
    return split_windows_list(*pathext, ';');
  }

  return {".COM", ".EXE", ".BAT", ".CMD", ".PS1"};
}

[[nodiscard]] bool executable_exists(const std::filesystem::path& path)
{
  auto ec = std::error_code {};
  return std::filesystem::exists(path, ec) && !ec
      && !std::filesystem::is_directory(path, ec);
}

[[nodiscard]] std::optional<std::filesystem::path> resolve_in_dir(
    const std::filesystem::path& dir, const std::filesystem::path& command)
{
  const auto candidate = dir / command;
  if (candidate.has_extension()) {
    return executable_exists(candidate) ? std::optional {candidate}
                                        : std::nullopt;
  }

  for (const auto& extension : windows_path_extensions()) {
    const auto extended = candidate.string() + extension;
    if (executable_exists(extended)) {
      return std::filesystem::path {extended};
    }
  }

  return std::nullopt;
}

[[nodiscard]] std::optional<std::filesystem::path> resolve_windows_command(
    std::string_view command)
{
  const auto command_path = std::filesystem::path {command};
  if (command_path.is_absolute() || command_path.has_parent_path()) {
    if (auto resolved =
            resolve_in_dir(command_path.parent_path(), command_path.filename()))
    {
      return resolved;
    }
    return std::nullopt;
  }

  if (auto resolved =
          resolve_in_dir(std::filesystem::current_path(), command_path))
  {
    return resolved;
  }

  const auto path_value = read_windows_env("PATH");
  if (!path_value.has_value()) {
    return std::nullopt;
  }

  for (const auto& path_entry : split_windows_list(*path_value, ';')) {
    if (auto resolved = resolve_in_dir(path_entry, command_path)) {
      return resolved;
    }
  }

  return std::nullopt;
}

[[nodiscard]] bool is_powershell_script(const std::filesystem::path& path)
{
  return iequals_ascii(path.extension().string(), ".ps1");
}

[[nodiscard]] std::expected<std::vector<std::string>, MgError>
windows_spawn_argv(std::span<const std::string> argv)
{
  if (argv.empty()) {
    return std::unexpected {MgError::command_failed};
  }

  const auto resolved = resolve_windows_command(argv[0]);
  if (!resolved) {
    return std::unexpected {MgError::manager_not_installed};
  }

  auto resolved_argv = std::vector<std::string> {};
  if (is_powershell_script(*resolved)) {
    resolved_argv.emplace_back("powershell.exe");
    resolved_argv.emplace_back("-NoLogo");
    resolved_argv.emplace_back("-NoProfile");
    resolved_argv.emplace_back("-ExecutionPolicy");
    resolved_argv.emplace_back("Bypass");
    resolved_argv.emplace_back("-File");
    resolved_argv.push_back(resolved->string());
  } else {
    resolved_argv.push_back(resolved->string());
  }

  resolved_argv.insert(resolved_argv.end(), argv.begin() + 1, argv.end());
  return resolved_argv;
}
#endif
}  // namespace

std::expected<std::vector<std::string>, MgError> build_argv(
    ManagerType manager,
    std::string_view action,
    const CommandArgs& command_args,
    const PackageOptions& options)
{
  auto argv = std::vector<std::string> {};
  argv.emplace_back(get_manager_name(manager));
  if (!append_command_args(argv, manager, action, command_args, options)) {
    return std::unexpected {MgError::unknown_subcommand};
  }
  return argv;
}

std::string format_command_preview(
    std::span<const std::string> argv,
    const std::optional<std::filesystem::path>& cwd)
{
  auto out = std::string {};
  if (cwd) {
    out += "[cwd=";
    append_preview_token(out, cwd->generic_string());
    out += "] ";
  }

  for (auto index = std::size_t {0}; index < argv.size(); ++index) {
    if (index != 0) {
      out += ' ';
    }
    append_preview_token(out, argv[index]);
  }

  return out;
}

#if defined(_WIN32)
std::optional<std::filesystem::path> resolve_windows_command_for_test(
    std::string_view command)
{
  return resolve_windows_command(command);
}
#endif

std::expected<void, MgError> run_process(
    std::span<const std::string> argv,
    const std::optional<std::filesystem::path>& cwd)
{
  if (argv.empty()) {
    return std::unexpected {MgError::command_failed};
  }

  const auto previous_path = std::filesystem::current_path();
  auto restore_cwd = [&previous_path]
  {
    std::error_code ignored;
    std::filesystem::current_path(previous_path, ignored);
  };

  if (cwd) {
    std::error_code ec;
    std::filesystem::current_path(*cwd, ec);
    if (ec) {
      log_error("Failed to switch cwd to {}: {}", cwd->string(), ec.message());
      return std::unexpected {MgError::command_failed};
    }
  }

#if defined(_WIN32)
  const auto spawn_argv = windows_spawn_argv(argv);
  if (!spawn_argv) {
    if (cwd) {
      restore_cwd();
    }
    log_error("Package manager not found in PATH: {}", argv[0]);
    return std::unexpected {spawn_argv.error()};
  }

  auto c_argv = make_c_argv(*spawn_argv);
  const auto code = _spawnv(_P_WAIT, (*spawn_argv)[0].c_str(), c_argv.data());
  if (cwd) {
    restore_cwd();
  }
  if (code == -1) {
    log_error("Failed to spawn process: {}",
              std::error_code {errno, std::system_category()}.message());
    return std::unexpected {errno == ENOENT ? MgError::manager_not_installed
                                            : MgError::command_failed};
  }
  if (code != 0) {
    log_error("Command failed with exit code {}", code);
    return std::unexpected {MgError::command_failed};
  }
#else
  auto c_argv = make_c_argv(argv);
  const auto pid = fork();
  if (pid == -1) {
    if (cwd) {
      restore_cwd();
    }
    log_error("Failed to spawn process: {}",
              std::error_code {errno, std::system_category()}.message());
    return std::unexpected {MgError::command_failed};
  }
  if (pid == 0) {
    execvp(argv[0].c_str(), c_argv.data());
    _exit(errno == ENOENT ? 127 : 126);
  }

  auto status = 0;
  if (waitpid(pid, &status, 0) == -1) {
    if (cwd) {
      restore_cwd();
    }
    log_error("Failed to wait for process: {}",
              std::error_code {errno, std::system_category()}.message());
    return std::unexpected {MgError::command_failed};
  }
  if (cwd) {
    restore_cwd();
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    const auto code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    log_error("Command failed with exit code {}", code);
    return std::unexpected {code == 127 ? MgError::manager_not_installed
                                        : MgError::command_failed};
  }
#endif

  return {};
}

std::expected<void, MgError> execute_argv_in_cwd(
    std::span<const std::string> argv,
    bool dry_run,
    const std::optional<std::filesystem::path>& cwd)
{
  if (argv.empty()) {
    return std::unexpected {MgError::command_failed};
  }

  const auto preview = format_command_preview(argv, cwd);
  log_info("Executing: {}", preview);
  if (dry_run) {
    log_debug("Dry run - command not executed");
    return {};
  }

  auto result = run_process(argv, cwd);
  if (!result) {
    return std::unexpected {result.error()};
  }

  log_info("Command completed successfully");
  return {};
}

std::expected<void, MgError> execute_argv(std::span<const std::string> argv,
                                          bool dry_run)
{
  return execute_argv_in_cwd(argv, dry_run, std::nullopt);
}

std::expected<void, MgError> execute(ManagerType manager,
                                     std::string_view action,
                                     const CommandArgs& command_args,
                                     const PackageOptions& options)
{
  auto argv = build_argv(manager, action, command_args, options);
  if (!argv) {
    return std::unexpected {argv.error()};
  }

  return execute_argv_in_cwd(*argv, options.dry_run, options.cwd);
}
}  // namespace mg::pkgm
