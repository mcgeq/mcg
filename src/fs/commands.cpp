#include <vector>

#include <mg/core/logger.hpp>
#include <mg/core/types.hpp>
#include <mg/fs/commands.hpp>
#include <mg/fs/core.hpp>

namespace mg::fs
{
namespace
{
[[nodiscard]] bool path_looks_like_directory(std::string_view path) noexcept
{
  return !path.empty() && (path.back() == '/' || path.back() == '\\');
}

struct ParsedCreateArgs
{
  bool force_dir {false};
  bool recursive {false};
  std::vector<std::string_view> paths {};
};

struct ParsedRemoveArgs
{
  bool recursive {false};
  std::vector<std::string_view> paths {};
};

struct ParsedCopyArgs
{
  bool recursive {false};
  std::optional<std::string_view> src {};
  std::optional<std::string_view> dst {};
  std::size_t extra_positionals {0};
};

[[nodiscard]] ParsedCreateArgs parse_create_args(
    std::span<const std::string_view> args)
{
  auto parsed = ParsedCreateArgs {};
  for (const auto arg : args) {
    if (arg == "--dir") {
      parsed.force_dir = true;
    } else if (arg == "--recursive" || arg == "-r") {
      parsed.recursive = true;
    } else if (starts_with(arg, "-")) {
      continue;
    } else {
      parsed.paths.push_back(arg);
    }
  }
  return parsed;
}

[[nodiscard]] ParsedRemoveArgs parse_remove_args(
    std::span<const std::string_view> args)
{
  auto parsed = ParsedRemoveArgs {};
  for (const auto arg : args) {
    if (arg == "--recursive" || arg == "-r" || arg == "-p") {
      parsed.recursive = true;
    } else if (starts_with(arg, "-")) {
      continue;
    } else {
      parsed.paths.push_back(arg);
    }
  }
  return parsed;
}

[[nodiscard]] ParsedCopyArgs parse_copy_args(
    std::span<const std::string_view> args)
{
  auto parsed = ParsedCopyArgs {};
  for (const auto arg : args) {
    if (arg == "--recursive" || arg == "-r") {
      parsed.recursive = true;
    } else if (starts_with(arg, "-")) {
      continue;
    } else if (!parsed.src) {
      parsed.src = arg;
    } else if (!parsed.dst) {
      parsed.dst = arg;
    } else {
      ++parsed.extra_positionals;
    }
  }
  return parsed;
}

[[nodiscard]] std::expected<void, MgError> handle_create(
    std::span<const std::string_view> args, bool dry_run)
{
  const auto parsed = parse_create_args(args);
  if (parsed.paths.empty()) {
    log_info("Usage: mg fs create <path> [--dir] [--recursive|-r]");
    return {};
  }

  for (const auto path : parsed.paths) {
    const auto is_dir = parsed.force_dir || path_looks_like_directory(path);
    if (auto result =
            fs_create_extended(path, is_dir, parsed.recursive, dry_run);
        !result)
    {
      return result;
    }
  }
  return {};
}

[[nodiscard]] std::expected<void, MgError> handle_remove(
    std::span<const std::string_view> args, bool dry_run)
{
  const auto parsed = parse_remove_args(args);
  if (parsed.paths.empty()) {
    log_info("Usage: mg fs remove <path> [--recursive|-r|-p]");
    return {};
  }

  for (const auto path : parsed.paths) {
    auto result = contains_wildcard(path)
        ? fs_remove_wildcard(path, parsed.recursive, dry_run)
        : fs_remove(path, parsed.recursive, dry_run);
    if (!result) {
      return result;
    }
  }
  return {};
}

[[nodiscard]] std::expected<void, MgError> handle_copy(
    std::span<const std::string_view> args, bool dry_run)
{
  const auto parsed = parse_copy_args(args);
  if (!parsed.src || !parsed.dst || parsed.extra_positionals != 0) {
    log_info("Usage: mg fs copy <src> <dst> [--recursive|-r]");
    return {};
  }
  return fs_copy_extended(*parsed.src, *parsed.dst, parsed.recursive, dry_run);
}

[[nodiscard]] std::expected<void, MgError> handle_move(
    std::span<const std::string_view> args, bool dry_run)
{
  if (args.size() != 2) {
    log_info("Usage: mg fs move <src> <dst>");
    return {};
  }
  return fs_move(args[0], args[1], dry_run);
}

[[nodiscard]] std::expected<void, MgError> handle_list(
    std::span<const std::string_view> args, bool dry_run)
{
  if (args.size() > 1) {
    log_info("Usage: mg fs list [path]");
    return {};
  }
  const auto path = args.empty() ? std::string_view {"."} : args[0];
  return contains_wildcard(path) ? fs_list_wildcard(path, dry_run)
                                 : fs_list(path, dry_run);
}

[[nodiscard]] std::expected<void, MgError> handle_read(
    std::span<const std::string_view> args, bool dry_run)
{
  if (args.size() != 1) {
    log_info("Usage: mg fs read <path>");
    return {};
  }
  return fs_read(args[0], dry_run);
}

[[nodiscard]] std::expected<void, MgError> handle_write(
    std::span<const std::string_view> args, bool dry_run)
{
  if (args.size() != 2) {
    log_info("Usage: mg fs write <path> <content>");
    return {};
  }
  return fs_write(args[0], args[1], dry_run);
}
}  // namespace

std::expected<void, MgError> handle_command(
    std::string_view cmd, std::span<const std::string_view> args, bool dry_run)
{
  if (cmd == "create" || cmd == "c" || cmd == "touch") {
    return handle_create(args, dry_run);
  }
  if (cmd == "remove" || cmd == "rm" || cmd == "r") {
    return handle_remove(args, dry_run);
  }
  if (cmd == "copy" || cmd == "cp" || cmd == "y") {
    return handle_copy(args, dry_run);
  }
  if (cmd == "move" || cmd == "mv" || cmd == "m") {
    return handle_move(args, dry_run);
  }
  if (cmd == "list" || cmd == "ls") {
    return handle_list(args, dry_run);
  }
  if (cmd == "exists" || cmd == "test") {
    if (args.size() != 1) {
      log_info("Usage: mg fs exists <path>");
      return {};
    }
    fs_exists(args[0], dry_run);
    return {};
  }
  if (cmd == "read" || cmd == "cat") {
    return handle_read(args, dry_run);
  }
  if (cmd == "write" || cmd == "echo") {
    return handle_write(args, dry_run);
  }

  log_error("Unknown fs subcommand: {}", cmd);
  return {};
}
}  // namespace mg::fs
