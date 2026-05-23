#include <mg/fs/core.hpp>

#include <mg/core/logger.hpp>
#include <mg/core/runtime.hpp>
#include <mg/core/types.hpp>

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

namespace mg::fs
{
namespace
{
struct WildcardSearchPlan
{
  std::filesystem::path root;
  std::string relative_pattern;
  bool recursive;
};

struct WildcardMatch
{
  std::filesystem::path path;
  std::string display_path;
};

struct WildcardMatches
{
  std::vector<WildcardMatch> entries {};
  bool root_missing {false};
};

enum class PathKind
{
  missing,
  file,
  directory,
  other,
};

enum class ParentPathStatus
{
  ready,
  missing,
  not_directory,
  other,
};

enum class MoveFailure
{
  source_missing,
  destination_parent_missing,
  destination_parent_not_directory,
  destination_existing_directory,
  destination_existing_file,
  destination_dir_not_empty,
  cross_device,
  permission_denied,
  path_component_not_directory,
  other,
};

[[nodiscard]] auto base_dir() -> std::filesystem::path
{
  return get_fs_cwd().value_or(std::filesystem::current_path());
}

[[nodiscard]] auto rooted(std::string_view path) -> std::filesystem::path
{
  const auto candidate = std::filesystem::path {path};
  if (candidate.is_absolute()) {
    return candidate;
  }
  return base_dir() / candidate;
}

[[nodiscard]] auto is_path_separator(char ch) noexcept -> bool
{
  return ch == '/' || ch == '\\';
}

[[nodiscard]] auto normalize_pattern(std::string_view pattern) -> std::string
{
  auto normalized = std::string {pattern};
  std::ranges::replace(normalized, '\\', '/');
  return normalized;
}

[[nodiscard]] auto split_path_segments(std::string_view path)
    -> std::vector<std::string_view>
{
  auto segments = std::vector<std::string_view> {};
  auto pos = std::size_t {};
  while (pos < path.size()) {
    while (pos < path.size() && is_path_separator(path[pos])) {
      ++pos;
    }
    const auto begin = pos;
    while (pos < path.size() && !is_path_separator(path[pos])) {
      ++pos;
    }
    if (pos > begin) {
      segments.push_back(path.substr(begin, pos - begin));
    }
  }
  return segments;
}

[[nodiscard]] auto wildcard_segment_matches(std::string_view path,
                                            std::string_view pattern) -> bool
{
  if (pattern.empty()) {
    return path.empty();
  }

  if (pattern.front() == '*') {
    return wildcard_segment_matches(path, pattern.substr(1))
        || (!path.empty() && wildcard_segment_matches(path.substr(1), pattern));
  }

  if (path.empty()) {
    return false;
  }

  if (pattern.front() == '?' || pattern.front() == path.front()) {
    return wildcard_segment_matches(path.substr(1), pattern.substr(1));
  }

  return false;
}

[[nodiscard]] auto matches_path_segments(std::span<const std::string_view> path,
                                         std::span<const std::string_view> pattern)
    -> bool
{
  if (pattern.empty()) {
    return path.empty();
  }

  if (path.empty()) {
    return std::ranges::all_of(pattern, [](std::string_view segment) {
      return segment == "**";
    });
  }

  if (pattern.front() == "**") {
    return matches_path_segments(path, pattern.subspan(1))
        || matches_path_segments(path.subspan(1), pattern);
  }

  return wildcard_segment_matches(path.front(), pattern.front())
      && matches_path_segments(path.subspan(1), pattern.subspan(1));
}

[[nodiscard]] auto matches_path_pattern(std::string_view path,
                                        std::string_view pattern) -> bool
{
  const auto path_segments = split_path_segments(path);
  const auto pattern_segments = split_path_segments(pattern);
  return matches_path_segments(path_segments, pattern_segments);
}

[[nodiscard]] auto build_wildcard_search_plan(std::string_view raw_pattern)
    -> std::optional<WildcardSearchPlan>
{
  auto pattern = normalize_pattern(raw_pattern);
  const auto first_wildcard = pattern.find_first_of("*?");
  if (first_wildcard == std::string_view::npos) {
    return std::nullopt;
  }

  const auto prefix = pattern.substr(0, first_wildcard);
  const auto sep = prefix.find_last_of("/\\");
  auto relative_pattern = sep == std::string_view::npos
                              ? pattern
                              : pattern.substr(sep + 1);
  if (relative_pattern.empty()) {
    return std::nullopt;
  }

  const auto recursive = relative_pattern.find('/') != std::string::npos;
  const auto root = sep == std::string_view::npos
                        ? base_dir()
                        : rooted(pattern.substr(0, sep));
  return WildcardSearchPlan {
      .root = root,
      .relative_pattern = std::move(relative_pattern),
      .recursive = recursive,
  };
}

[[nodiscard]] auto wildcard_matches(std::string_view pattern) -> WildcardMatches
{
  auto matches = WildcardMatches {};
  const auto plan = build_wildcard_search_plan(pattern);
  if (!plan) {
    return matches;
  }

  auto ec = std::error_code {};
  if (!std::filesystem::exists(plan->root, ec)
      || !std::filesystem::is_directory(plan->root, ec)) {
    matches.root_missing = true;
    return matches;
  }

  if (plan->recursive) {
    for (auto iter = std::filesystem::recursive_directory_iterator {plan->root, ec};
         !ec && iter != std::filesystem::recursive_directory_iterator {};
         iter.increment(ec)) {
      ec.clear();
      const auto rel =
          std::filesystem::relative(iter->path(), plan->root, ec).generic_string();
      if (!ec && matches_path_pattern(rel, plan->relative_pattern)) {
        matches.entries.push_back(WildcardMatch {
            .path = iter->path(),
            .display_path = rel,
        });
      }
    }
    return matches;
  }

  for (auto iter = std::filesystem::directory_iterator {plan->root, ec};
       !ec && iter != std::filesystem::directory_iterator {};
       iter.increment(ec)) {
    const auto name = iter->path().filename().generic_string();
    if (wildcard_segment_matches(name, plan->relative_pattern)) {
      matches.entries.push_back(WildcardMatch {
          .path = iter->path(),
          .display_path = name,
      });
    }
  }
  return matches;
}

[[nodiscard]] auto detect_path_kind(std::string_view path) -> PathKind
{
  std::error_code ec;
  const auto target = rooted(path);
  if (!std::filesystem::exists(target, ec)) {
    return ec ? PathKind::other : PathKind::missing;
  }
  const auto status = std::filesystem::status(target, ec);
  if (ec) {
    return PathKind::other;
  }
  if (std::filesystem::is_regular_file(status)) {
    return PathKind::file;
  }
  if (std::filesystem::is_directory(status)) {
    return PathKind::directory;
  }
  return PathKind::other;
}

[[nodiscard]] auto destination_parent_status(std::string_view path)
    -> ParentPathStatus
{
  const auto parent = std::filesystem::path {path}.parent_path();
  if (parent.empty() || parent == ".") {
    return ParentPathStatus::ready;
  }

  switch (detect_path_kind(parent.generic_string())) {
    case PathKind::directory:
      return ParentPathStatus::ready;
    case PathKind::missing:
      return ParentPathStatus::missing;
    case PathKind::file:
      return ParentPathStatus::not_directory;
    case PathKind::other:
      return ParentPathStatus::other;
  }

  return ParentPathStatus::other;
}

void report_destination_parent_status(std::string_view path,
                                      ParentPathStatus status)
{
  const auto parent = std::filesystem::path {path}.parent_path();
  if (parent.empty() || parent == ".") {
    return;
  }
  const auto parent_display = parent.generic_string();

  switch (status) {
    case ParentPathStatus::ready:
      return;
    case ParentPathStatus::missing:
      log_error("Destination parent directory not found: {}", parent_display);
      return;
    case ParentPathStatus::not_directory:
      log_error("Destination parent is not a directory: {}", parent_display);
      return;
    case ParentPathStatus::other:
      log_error("Failed to inspect destination parent: {}", parent_display);
      return;
  }
}

[[nodiscard]] auto classify_move_failure(std::string_view src,
                                         std::string_view dst,
                                         const std::error_code& ec)
    -> MoveFailure
{
  if (detect_path_kind(src) == PathKind::missing) {
    return MoveFailure::source_missing;
  }

  switch (destination_parent_status(dst)) {
    case ParentPathStatus::missing:
      return MoveFailure::destination_parent_missing;
    case ParentPathStatus::not_directory:
      return MoveFailure::destination_parent_not_directory;
    case ParentPathStatus::other:
      return MoveFailure::other;
    case ParentPathStatus::ready:
      break;
  }

  switch (detect_path_kind(dst)) {
    case PathKind::directory:
      return MoveFailure::destination_existing_directory;
    case PathKind::file:
      return MoveFailure::destination_existing_file;
    case PathKind::missing:
    case PathKind::other:
      break;
  }

  if (ec == std::errc::directory_not_empty) {
    return MoveFailure::destination_dir_not_empty;
  }
  if (ec == std::errc::cross_device_link) {
    return MoveFailure::cross_device;
  }
  if (ec == std::errc::permission_denied) {
    return MoveFailure::permission_denied;
  }
  if (ec == std::errc::not_a_directory) {
    return MoveFailure::path_component_not_directory;
  }

  return MoveFailure::other;
}

void report_move_failure(std::string_view src,
                         std::string_view dst,
                         MoveFailure failure,
                         const std::error_code& ec)
{
  switch (failure) {
    case MoveFailure::source_missing:
      log_error("Source not found: {}", src);
      return;
    case MoveFailure::destination_parent_missing:
      report_destination_parent_status(dst, ParentPathStatus::missing);
      return;
    case MoveFailure::destination_parent_not_directory:
      report_destination_parent_status(dst, ParentPathStatus::not_directory);
      return;
    case MoveFailure::destination_existing_directory:
      log_error("Destination is an existing directory: {}", dst);
      return;
    case MoveFailure::destination_existing_file:
      log_error("Destination is an existing file: {}", dst);
      return;
    case MoveFailure::destination_dir_not_empty:
      log_error("Destination directory is not empty: {}", dst);
      return;
    case MoveFailure::cross_device:
      log_error("Cannot move across file systems: {} -> {}", src, dst);
      return;
    case MoveFailure::permission_denied:
      log_error("Permission denied while moving {} -> {}: {}",
                src,
                dst,
                ec.message());
      return;
    case MoveFailure::path_component_not_directory:
      log_error("A path component is not a directory while moving {} -> {}",
                src,
                dst);
      return;
    case MoveFailure::other:
      log_error("Failed to move {} -> {}: {}", src, dst, ec.message());
      return;
  }
}
}  // namespace

auto fs_create_extended(std::string_view path,
                        bool is_dir,
                        bool recursive,
                        bool dry_run) -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] Create {}: {}", is_dir ? "directory" : "file", path);
    return {};
  }

  const auto target = rooted(path);
  std::error_code ec;
  if (is_dir) {
    std::filesystem::create_directories(target, ec);
    if (ec) {
      log_error("Failed to create directory: {}", path);
      return std::unexpected {MgError::create_dir_failed};
    }
    log_info("Created directory: {}", path);
    return {};
  }

  if (recursive) {
    std::filesystem::create_directories(target.parent_path(), ec);
    if (ec) {
      log_error("Failed to create parent directory: {}", target.parent_path().string());
      return std::unexpected {MgError::create_dir_failed};
    }
  }

  auto file = std::ofstream {target, std::ios::app};
  if (!file) {
    log_error("Failed to create file: {}", path);
    return std::unexpected {MgError::create_file_failed};
  }
  log_info("Created file: {}", path);
  return {};
}

auto fs_remove(std::string_view path, bool recursive, bool dry_run)
    -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] Remove: {}", path);
    return {};
  }

  const auto target = rooted(path);
  std::error_code ec;
  if (!std::filesystem::exists(target, ec)) {
    log_error("Path not found: {}", path);
    return {};
  }

  if (std::filesystem::is_directory(target, ec)) {
    if (recursive) {
      std::filesystem::remove_all(target, ec);
    } else {
      std::filesystem::remove(target, ec);
    }
  } else {
    std::filesystem::remove(target, ec);
  }

  if (ec) {
    log_error("Failed to remove {}: {}", path, ec.message());
    return std::unexpected {MgError::remove_failed};
  }
  log_info("Removed: {}", path);
  return {};
}

auto fs_remove_wildcard(std::string_view pattern, bool recursive, bool dry_run)
    -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] Remove: {}", pattern);
    return {};
  }

  const auto matches = wildcard_matches(pattern);
  if (matches.root_missing) {
    log_error("Directory not found: {}", pattern);
    return {};
  }
  if (matches.entries.empty()) {
    log_info("No files matched: {}", pattern);
    return {};
  }

  for (const auto& match : matches.entries) {
    const auto rel = std::filesystem::relative(match.path, base_dir()).generic_string();
    auto result = fs_remove(rel, recursive, false);
    if (!result) {
      return result;
    }
  }
  return {};
}

auto fs_copy_extended(std::string_view src,
                      std::string_view dst,
                      bool recursive,
                      bool dry_run) -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] {}: {} -> {}",
             recursive ? "Copy recursive" : "Copy",
             src,
             dst);
    return {};
  }

  const auto source = rooted(src);
  const auto target = rooted(dst);
  std::error_code ec;
  if (!std::filesystem::exists(source, ec)) {
    log_error("Source not found: {}", src);
    return {};
  }

  if (std::filesystem::is_directory(source, ec)) {
    if (!recursive) {
      log_error("{} is a directory, use --recursive", src);
      return {};
    }
    std::filesystem::copy(source,
                          target,
                          std::filesystem::copy_options::recursive
                              | std::filesystem::copy_options::overwrite_existing,
                          ec);
    if (!ec) {
      log_info("Copied directory: {} -> {}", src, dst);
    }
  } else {
    std::filesystem::copy_file(source,
                               target,
                               std::filesystem::copy_options::overwrite_existing,
                               ec);
    if (!ec) {
      log_info("Copied: {} -> {}", src, dst);
    }
  }

  if (ec) {
    log_error("Failed to copy {} -> {}: {}", src, dst, ec.message());
    return std::unexpected {MgError::copy_failed};
  }
  return {};
}

auto fs_move(std::string_view src, std::string_view dst, bool dry_run)
    -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] Move: {} -> {}", src, dst);
    return {};
  }

  std::error_code ec;
  std::filesystem::rename(rooted(src), rooted(dst), ec);
  if (ec) {
    report_move_failure(src, dst, classify_move_failure(src, dst, ec), ec);
    return std::unexpected {MgError::move_failed};
  }
  log_info("Moved: {} -> {}", src, dst);
  return {};
}

auto fs_list(std::string_view path, bool dry_run) -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] List: {}", path);
    return {};
  }

  const auto target = rooted(path);
  std::error_code ec;
  if (!std::filesystem::exists(target, ec)) {
    log_error("Path not found: {}", path);
    return {};
  }

  auto lines = std::vector<std::string> {};
  for (const auto& entry : std::filesystem::directory_iterator {target, ec}) {
    auto name = entry.path().filename().generic_string();
    if (entry.is_directory(ec)) {
      name += '/';
    }
    lines.push_back(std::move(name));
  }
  std::ranges::sort(lines);

  for (const auto& line : lines) {
    write_stdout("  " + line + "\n");
  }
  return {};
}

auto fs_list_wildcard(std::string_view pattern, bool dry_run)
    -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] List: {}", pattern);
    return {};
  }

  auto lines = std::vector<std::string> {};
  const auto matches = wildcard_matches(pattern);
  if (matches.root_missing) {
    log_error("Path not found: {}", pattern);
    return {};
  }

  for (const auto& match : matches.entries) {
    auto name = match.display_path;
    std::error_code ec;
    if (std::filesystem::is_directory(match.path, ec)) {
      name += '/';
    }
    lines.push_back(std::move(name));
  }
  std::ranges::sort(lines);
  if (lines.empty()) {
    log_info("No files matched: {}", pattern);
    return {};
  }
  for (const auto& line : lines) {
    write_stdout("  " + line + "\n");
  }
  return {};
}

void fs_exists(std::string_view path, bool dry_run)
{
  if (dry_run) {
    log_info("[dry-run] Exists: {}", path);
    return;
  }

  std::error_code ec;
  if (std::filesystem::exists(rooted(path), ec)) {
    log_info("Exists: {}", path);
  } else {
    log_info("Not found: {}", path);
  }
}

auto fs_read(std::string_view path, bool dry_run) -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] Read: {}", path);
    return {};
  }

  auto input = std::ifstream {rooted(path), std::ios::binary};
  if (!input) {
    log_error("Failed to read file: {}", path);
    return std::unexpected {MgError::path_not_found};
  }

  auto buffer = std::ostringstream {};
  buffer << input.rdbuf();
  write_stdout(buffer.str());
  return {};
}

auto fs_write(std::string_view path, std::string_view content, bool dry_run)
    -> std::expected<void, MgError>
{
  if (dry_run) {
    log_info("[dry-run] Write {} bytes to: {}", content.size(), path);
    return {};
  }

  auto output = std::ofstream {rooted(path), std::ios::binary};
  if (!output) {
    log_error("Failed to create file: {}", path);
    return std::unexpected {MgError::create_file_failed};
  }
  output << content;
  log_info("Wrote {} bytes to: {}", content.size(), path);
  return {};
}
}  // namespace mg::fs
