#include <filesystem>
#include <optional>

#include <mg/app.hpp>
#include <mg/cli/help.hpp>
#include <mg/cli/parser.hpp>
#include <mg/core/logger.hpp>
#include <mg/pkgm/core.hpp>
#include <mg/pkgm/registry.hpp>

namespace mg
{
namespace
{
struct PackageInvocation
{
  std::string_view action {};
  CommandArgs command_args {};
  PackageOptions options {};
};

enum class PackageParseKind
{
  invocation,
  help_requested,
  none,
  reported_error,
};

struct PackageParseResult
{
  PackageParseKind kind {PackageParseKind::none};
  PackageInvocation invocation {};
};

enum class PackageOptionResult
{
  handled,
  not_option,
  stop_help,
  stop_error,
};

[[nodiscard]] PackageOptionResult parse_package_option(
    PackageInvocation& parsed,
    std::span<const std::string_view> args,
    std::size_t& index)
{
  const auto arg = args[index];

  if (arg == "--dry-run" || arg == "-d") {
    parsed.options.dry_run = true;
    return PackageOptionResult::handled;
  }

  if (arg == "--cwd" || arg == "-C") {
    const auto next_index = index + 1;
    if (next_index >= args.size() || args[next_index] == "--") {
      log_error("Missing path after {}", arg);
      return PackageOptionResult::stop_error;
    }
    parsed.options.cwd = std::filesystem::path {args[next_index]};
    index = next_index;
    return PackageOptionResult::handled;
  }

  if (starts_with(arg, "--cwd=")) {
    parsed.options.cwd = std::filesystem::path {arg.substr(6)};
    return PackageOptionResult::handled;
  }

  if (arg == "--dev" || arg == "-D") {
    parsed.options.dev = true;
    return PackageOptionResult::handled;
  }

  if (arg == "--group" || arg == "-G" || arg == "--profile" || arg == "-P") {
    const auto next_index = index + 1;
    if (next_index >= args.size() || args[next_index] == "--") {
      log_error("Missing profile name after {}", arg);
      return PackageOptionResult::stop_error;
    }
    if (!parsed.options.add_profile(args[next_index])) {
      log_error("Too many profile names specified (max {})",
                PackageOptions::max_profiles);
      return PackageOptionResult::stop_error;
    }
    index = next_index;
    return PackageOptionResult::handled;
  }

  if (starts_with(arg, "--group=") || starts_with(arg, "--profile=")) {
    const auto value =
        starts_with(arg, "--group=") ? arg.substr(8) : arg.substr(10);
    if (!parsed.options.add_profile(value)) {
      log_error("Too many profile names specified (max {})",
                PackageOptions::max_profiles);
      return PackageOptionResult::stop_error;
    }
    return PackageOptionResult::handled;
  }

  if (arg == "--help" || arg == "-h") {
    return PackageOptionResult::stop_help;
  }

  if (starts_with(arg, "-")) {
    log_error("Unknown package option: {} (use -- to pass manager-native args)",
              arg);
    return PackageOptionResult::stop_error;
  }

  return PackageOptionResult::not_option;
}

[[nodiscard]] PackageParseResult parse_package_invocation(
    std::span<const std::string_view> args)
{
  auto index = std::size_t {1};
  auto parsed = PackageInvocation {};

  while (index < args.size()) {
    switch (parse_package_option(parsed, args, index)) {
      case PackageOptionResult::handled:
        break;
      case PackageOptionResult::not_option:
        parsed.action = args[index++];
        goto action_found;
      case PackageOptionResult::stop_help:
        return {.kind = PackageParseKind::help_requested};
      case PackageOptionResult::stop_error:
        return {.kind = PackageParseKind::reported_error};
    }
    ++index;
  }

action_found:
  if (parsed.action.empty()) {
    return {.kind = PackageParseKind::none};
  }

  while (index < args.size()) {
    const auto arg = args[index];
    if (arg == "--") {
      ++index;
      while (index < args.size()) {
        parsed.command_args.add_manager_arg(args[index++]);
      }
      return {.kind = PackageParseKind::invocation,
              .invocation = std::move(parsed)};
    }

    switch (parse_package_option(parsed, args, index)) {
      case PackageOptionResult::handled:
        break;
      case PackageOptionResult::not_option:
        parsed.command_args.add_package(arg);
        break;
      case PackageOptionResult::stop_help:
        return {.kind = PackageParseKind::help_requested};
      case PackageOptionResult::stop_error:
        return {.kind = PackageParseKind::reported_error};
    }
    ++index;
  }

  return {.kind = PackageParseKind::invocation,
          .invocation = std::move(parsed)};
}
}  // namespace

std::expected<void, MgError> run(std::span<const std::string_view> args)
{
  if (args.size() < 2) {
    cli::print_help();
    return {};
  }

  const auto parse_result = cli::parse(args);
  switch (parse_result) {
    case cli::ParseResult::help:
      cli::print_help();
      return {};
    case cli::ParseResult::version:
      cli::print_version();
      return {};
    case cli::ParseResult::fs:
    case cli::ParseResult::none:
      return {};
    case cli::ParseResult::pkg:
      break;
  }

  auto package_parse = parse_package_invocation(args);
  switch (package_parse.kind) {
    case PackageParseKind::help_requested:
      cli::print_help();
      return {};
    case PackageParseKind::none:
      log_error("No package command specified");
      return {};
    case PackageParseKind::reported_error:
      return {};
    case PackageParseKind::invocation:
      break;
  }

  auto& invocation = package_parse.invocation;
  if (invocation.command_args.packages.empty()
      && invocation.command_args.manager_args.empty()
      && pkgm::action_requires_packages(invocation.action))
  {
    log_error("No packages specified");
    return {};
  }

  if (invocation.command_args.packages.empty()
      && pkgm::action_requires_run_target(invocation.action))
  {
    log_error("No run target specified");
    return {};
  }

  return pkgm::execute_command(
      invocation.action, invocation.command_args, invocation.options);
}
}  // namespace mg
