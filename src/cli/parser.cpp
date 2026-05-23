#include <mg/cli/parser.hpp>

#include <mg/cli/help.hpp>
#include <mg/core/logger.hpp>
#include <mg/core/runtime.hpp>
#include <mg/fs/commands.hpp>
#include <mg/pkgm/registry.hpp>

#include <filesystem>
#include <optional>

namespace mg::cli
{
namespace
{
struct CwdOptionResult
{
  enum class Kind
  {
    handled,
    not_cwd,
    missing_value,
  };

  Kind kind {Kind::not_cwd};
  std::string_view value {};
};

[[nodiscard]] auto parse_cwd_option(std::span<const std::string_view> args,
                                    std::size_t& index) -> CwdOptionResult
{
  const auto arg = args[index];
  if (arg == "--cwd" || arg == "-C") {
    const auto next_index = index + 1;
    if (next_index >= args.size() || args[next_index] == "--") {
      return {.kind = CwdOptionResult::Kind::missing_value, .value = arg};
    }
    index = next_index;
    return {.kind = CwdOptionResult::Kind::handled, .value = args[next_index]};
  }

  if (starts_with(arg, "--cwd=")) {
    return {.kind = CwdOptionResult::Kind::handled, .value = arg.substr(6)};
  }

  return {};
}
}  // namespace

auto parse_options(std::span<const std::string_view> args) noexcept -> Options
{
  auto opts = Options {};
  for (const auto arg : args) {
    if (arg == "--dry-run" || arg == "-d") {
      opts.dry_run = true;
    } else if (arg == "--help" || arg == "-h") {
      opts.dry_run = false;
    }
  }
  return opts;
}

auto parse(std::span<const std::string_view> args) -> ParseResult
{
  auto index = std::size_t {1};
  auto opts = Options {};
  auto cwd = std::optional<std::filesystem::path> {};

  while (index < args.size()) {
    const auto arg = args[index];
    if (arg == "--dry-run" || arg == "-d") {
      opts.dry_run = true;
      ++index;
      continue;
    }
    if (arg == "--help" || arg == "-h") {
      return ParseResult::help;
    }
    if (arg == "--version") {
      return ParseResult::version;
    }

    const auto cwd_result = parse_cwd_option(args, index);
    if (cwd_result.kind == CwdOptionResult::Kind::handled) {
      cwd = std::filesystem::path {cwd_result.value};
      ++index;
      continue;
    }
    if (cwd_result.kind == CwdOptionResult::Kind::missing_value) {
      log_error("Missing path after {}", cwd_result.value);
      return ParseResult::none;
    }
    break;
  }

  if (index >= args.size()) {
    print_help();
    return ParseResult::none;
  }

  const auto cmd = args[index++];
  if (cmd == "version") {
    return ParseResult::version;
  }

  if (cmd == "fs" || cmd == "f") {
    while (index < args.size()) {
      const auto fs_arg = args[index];
      if (fs_arg == "--dry-run" || fs_arg == "-d") {
        opts.dry_run = true;
        ++index;
        continue;
      }
      if (fs_arg == "--help" || fs_arg == "-h") {
        print_fs_help();
        return ParseResult::none;
      }

      const auto fs_cwd_result = parse_cwd_option(args, index);
      if (fs_cwd_result.kind == CwdOptionResult::Kind::handled) {
        cwd = std::filesystem::path {fs_cwd_result.value};
        ++index;
        continue;
      }
      if (fs_cwd_result.kind == CwdOptionResult::Kind::missing_value) {
        log_error("Missing path after {}", fs_cwd_result.value);
        return ParseResult::none;
      }

      const auto previous_cwd = swap_fs_cwd(cwd);
      const auto fs_result = fs::handle_command(
          fs_arg,
          args.subspan(index + 1),
          opts.dry_run);
      (void)swap_fs_cwd(previous_cwd);
      if (!fs_result) {
        return ParseResult::none;
      }
      return ParseResult::fs;
    }

    print_fs_help();
    return ParseResult::none;
  }

  const auto packages = args.subspan(index);
  if (packages.empty() && pkgm::action_requires_packages(cmd)) {
    log_error("No packages specified");
    return ParseResult::none;
  }
  if (packages.empty() && pkgm::action_requires_run_target(cmd)) {
    log_error("No run target specified");
    return ParseResult::none;
  }

  return ParseResult::pkg;
}
}  // namespace mg::cli
