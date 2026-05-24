#include <array>
#include <cstddef>
#include <filesystem>
#include <fstream>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include <mg/pkgm/detect.hpp>
#include <mg/pkgm/registry.hpp>

namespace mg::pkgm
{
namespace
{
struct LockfileDetector
{
  std::string_view file;
  ManagerType manager;
};

constexpr auto lockfile_detectors = std::array {
    LockfileDetector {"Cargo.toml", ManagerType::cargo},
    LockfileDetector {"pnpm-lock.yaml", ManagerType::pnpm},
    LockfileDetector {"bun.lock", ManagerType::bun},
    LockfileDetector {"package-lock.json", ManagerType::npm},
    LockfileDetector {"yarn.lock", ManagerType::yarn},
    LockfileDetector {"uv.lock", ManagerType::uv},
    LockfileDetector {"poetry.lock", ManagerType::poetry},
    LockfileDetector {"pdm.lock", ManagerType::pdm},
    LockfileDetector {"requirements.txt", ManagerType::pip},
};

constexpr auto node_lockfile_detectors = std::array {
    LockfileDetector {"pnpm-lock.yaml", ManagerType::pnpm},
    LockfileDetector {"bun.lock", ManagerType::bun},
    LockfileDetector {"package-lock.json", ManagerType::npm},
    LockfileDetector {"yarn.lock", ManagerType::yarn},
};

enum class DetectionStrength
{
  strong,
  weak_node_fallback,
};

struct DetectionResult
{
  ManagerType manager;
  DetectionStrength strength;
};

struct JsonMember
{
  std::string_view key;
  std::string_view value;
};

void skip_json_ws(std::string_view json, std::size_t& pos) noexcept
{
  while (pos < json.size()
         && (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r'
             || json[pos] == '\n'))
  {
    ++pos;
  }
}

[[nodiscard]] std::optional<std::string_view> parse_json_string(
    std::string_view json, std::size_t& pos)
{
  if (pos >= json.size() || json[pos] != '"') {
    return std::nullopt;
  }

  const auto begin = ++pos;
  while (pos < json.size()) {
    if (json[pos] == '\\') {
      pos += 2;
      continue;
    }
    if (json[pos] == '"') {
      const auto value = json.substr(begin, pos - begin);
      ++pos;
      return value;
    }
    ++pos;
  }

  return std::nullopt;
}

[[nodiscard]] bool skip_json_value(std::string_view json, std::size_t& pos);

[[nodiscard]] bool skip_json_object(std::string_view json, std::size_t& pos)
{
  if (pos >= json.size() || json[pos] != '{') {
    return false;
  }
  ++pos;
  skip_json_ws(json, pos);
  if (pos < json.size() && json[pos] == '}') {
    ++pos;
    return true;
  }

  while (pos < json.size()) {
    if (!parse_json_string(json, pos)) {
      return false;
    }
    skip_json_ws(json, pos);
    if (pos >= json.size() || json[pos] != ':') {
      return false;
    }
    ++pos;
    skip_json_ws(json, pos);
    if (!skip_json_value(json, pos)) {
      return false;
    }
    skip_json_ws(json, pos);
    if (pos >= json.size()) {
      return false;
    }
    if (json[pos] == '}') {
      ++pos;
      return true;
    }
    if (json[pos] != ',') {
      return false;
    }
    ++pos;
    skip_json_ws(json, pos);
  }

  return false;
}

[[nodiscard]] bool skip_json_array(std::string_view json, std::size_t& pos)
{
  if (pos >= json.size() || json[pos] != '[') {
    return false;
  }
  ++pos;
  skip_json_ws(json, pos);
  if (pos < json.size() && json[pos] == ']') {
    ++pos;
    return true;
  }

  while (pos < json.size()) {
    if (!skip_json_value(json, pos)) {
      return false;
    }
    skip_json_ws(json, pos);
    if (pos >= json.size()) {
      return false;
    }
    if (json[pos] == ']') {
      ++pos;
      return true;
    }
    if (json[pos] != ',') {
      return false;
    }
    ++pos;
    skip_json_ws(json, pos);
  }

  return false;
}

[[nodiscard]] bool skip_json_scalar(std::string_view json, std::size_t& pos)
{
  const auto begin = pos;
  while (pos < json.size() && json[pos] != ',' && json[pos] != '}'
         && json[pos] != ']' && json[pos] != ' ' && json[pos] != '\t'
         && json[pos] != '\r' && json[pos] != '\n')
  {
    ++pos;
  }
  return pos > begin;
}

[[nodiscard]] bool skip_json_value(std::string_view json, std::size_t& pos)
{
  skip_json_ws(json, pos);
  if (pos >= json.size()) {
    return false;
  }

  if (json[pos] == '"') {
    return parse_json_string(json, pos).has_value();
  }
  if (json[pos] == '{') {
    return skip_json_object(json, pos);
  }
  if (json[pos] == '[') {
    return skip_json_array(json, pos);
  }
  return skip_json_scalar(json, pos);
}

[[nodiscard]] std::optional<std::vector<JsonMember>> json_object_members(
    std::string_view json)
{
  auto pos = std::size_t {};
  auto members = std::vector<JsonMember> {};

  skip_json_ws(json, pos);
  if (pos >= json.size() || json[pos] != '{') {
    return std::nullopt;
  }
  ++pos;
  skip_json_ws(json, pos);
  if (pos < json.size() && json[pos] == '}') {
    ++pos;
    skip_json_ws(json, pos);
    return pos == json.size() ? std::optional {members} : std::nullopt;
  }

  while (pos < json.size()) {
    const auto key = parse_json_string(json, pos);
    if (!key) {
      return std::nullopt;
    }
    skip_json_ws(json, pos);
    if (pos >= json.size() || json[pos] != ':') {
      return std::nullopt;
    }
    ++pos;
    skip_json_ws(json, pos);

    const auto value_begin = pos;
    if (!skip_json_value(json, pos)) {
      return std::nullopt;
    }
    members.push_back(
        JsonMember {*key, json.substr(value_begin, pos - value_begin)});

    skip_json_ws(json, pos);
    if (pos >= json.size()) {
      return std::nullopt;
    }
    if (json[pos] == '}') {
      ++pos;
      skip_json_ws(json, pos);
      return pos == json.size() ? std::optional {members} : std::nullopt;
    }
    if (json[pos] != ',') {
      return std::nullopt;
    }
    ++pos;
    skip_json_ws(json, pos);
  }

  return std::nullopt;
}

[[nodiscard]] std::optional<std::string_view> json_object_member_value(
    std::string_view json, std::string_view key)
{
  const auto members = json_object_members(json);
  if (!members) {
    return std::nullopt;
  }

  for (const auto member : *members) {
    if (member.key == key) {
      return member.value;
    }
  }
  return std::nullopt;
}

[[nodiscard]] std::optional<bool> json_object_has_member(std::string_view json,
                                                         std::string_view key)
{
  const auto members = json_object_members(json);
  if (!members) {
    return std::nullopt;
  }

  for (const auto member : *members) {
    if (member.key == key) {
      return true;
    }
  }
  return false;
}

[[nodiscard]] bool path_exists(const std::filesystem::path& dir,
                               std::string_view file)
{
  std::error_code ec;
  return std::filesystem::exists(dir / std::filesystem::path {file}, ec);
}

[[nodiscard]] std::optional<std::string> read_file(
    const std::filesystem::path& path)
{
  auto input = std::ifstream {path, std::ios::binary};
  if (!input) {
    return std::nullopt;
  }

  auto buffer = std::ostringstream {};
  buffer << input.rdbuf();
  return buffer.str();
}

[[nodiscard]] constexpr bool is_toml_whitespace(char ch) noexcept
{
  return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
}

[[nodiscard]] std::string_view trim_toml_whitespace(
    std::string_view value) noexcept
{
  while (!value.empty() && is_toml_whitespace(value.front())) {
    value.remove_prefix(1);
  }
  while (!value.empty() && is_toml_whitespace(value.back())) {
    value.remove_suffix(1);
  }
  return value;
}

[[nodiscard]] std::string_view strip_toml_comment(
    std::string_view line) noexcept
{
  auto in_basic_string = false;
  auto in_literal_string = false;
  auto escaped = false;

  for (auto index = std::size_t {}; index < line.size(); ++index) {
    const auto ch = line[index];

    if (in_basic_string) {
      if (escaped) {
        escaped = false;
      } else if (ch == '\\') {
        escaped = true;
      } else if (ch == '"') {
        in_basic_string = false;
      }
      continue;
    }

    if (in_literal_string) {
      if (ch == '\'') {
        in_literal_string = false;
      }
      continue;
    }

    if (ch == '#') {
      return line.substr(0, index);
    }
    if (ch == '"') {
      in_basic_string = true;
    } else if (ch == '\'') {
      in_literal_string = true;
    }
  }

  return line;
}

[[nodiscard]] std::string normalized_toml_bare_section(std::string_view section)
{
  auto normalized = std::string {};
  normalized.reserve(section.size());
  for (const auto ch : section) {
    if (ch != ' ' && ch != '\t') {
      normalized += ch;
    }
  }
  return normalized;
}

[[nodiscard]] bool toml_section_matches(std::string_view candidate,
                                        std::string_view section)
{
  const auto normalized = normalized_toml_bare_section(candidate);
  if (normalized == section) {
    return true;
  }
  return normalized.size() > section.size() && normalized[section.size()] == '.'
      && std::string_view {normalized}.substr(0, section.size()) == section;
}

[[nodiscard]] bool has_toml_section(std::string_view content,
                                    std::string_view section)
{
  auto rest = content;
  while (!rest.empty()) {
    auto line = std::string_view {};
    const auto newline = rest.find('\n');
    if (newline == std::string_view::npos) {
      line = rest;
      rest = {};
    } else {
      line = rest.substr(0, newline);
      rest.remove_prefix(newline + 1);
    }

    line = trim_toml_whitespace(strip_toml_comment(line));
    if (line.size() < 3 || line.front() != '[' || line.back() != ']') {
      continue;
    }

    auto header = std::string_view {};
    if (line.size() >= 4 && line[1] == '[' && line[line.size() - 2] == ']') {
      header = line.substr(2, line.size() - 4);
    } else if (line[1] != '[') {
      header = line.substr(1, line.size() - 2);
    } else {
      continue;
    }

    if (toml_section_matches(trim_toml_whitespace(header), section)) {
      return true;
    }
  }

  return false;
}

[[nodiscard]] bool is_node_manager(ManagerType manager) noexcept
{
  return manager == ManagerType::npm || manager == ManagerType::pnpm
      || manager == ManagerType::bun || manager == ManagerType::yarn;
}

[[nodiscard]] bool package_manager_name_matches(std::string_view value,
                                                std::string_view expected)
{
  if (iequals(value, expected)) {
    return true;
  }
  if (value.size() <= expected.size() || value[expected.size()] != '@') {
    return false;
  }
  return iequals(value.substr(0, expected.size()), expected);
}

[[nodiscard]] std::optional<std::string_view> extract_json_string_value(
    std::string_view json, std::string_view key)
{
  const auto value = json_object_member_value(json, key);
  if (!value) {
    return std::nullopt;
  }

  auto pos = std::size_t {};
  const auto parsed = parse_json_string(*value, pos);
  if (!parsed) {
    return std::nullopt;
  }
  skip_json_ws(*value, pos);
  if (pos != value->size()) {
    return std::nullopt;
  }

  return parsed;
}

[[nodiscard]] bool json_object_has_key(std::string_view json,
                                       std::string_view object_key,
                                       std::string_view key)
{
  const auto object = json_object_member_value(json, object_key);
  if (!object) {
    return false;
  }
  return json_object_has_member(*object, key).value_or(false);
}

[[nodiscard]] std::optional<ManagerType> node_manager_from_package_json(
    std::string_view json)
{
  const auto package_manager =
      extract_json_string_value(json, "packageManager");
  if (!package_manager) {
    return std::nullopt;
  }

  if (package_manager_name_matches(*package_manager, "pnpm")) {
    return ManagerType::pnpm;
  }
  if (package_manager_name_matches(*package_manager, "bun")) {
    return ManagerType::bun;
  }
  if (package_manager_name_matches(*package_manager, "npm")) {
    return ManagerType::npm;
  }
  if (package_manager_name_matches(*package_manager, "yarn")) {
    return ManagerType::yarn;
  }
  return std::nullopt;
}

[[nodiscard]] std::optional<ManagerType> detect_node_lockfile_manager(
    const std::filesystem::path& dir)
{
  for (const auto detector : node_lockfile_detectors) {
    if (path_exists(dir, detector.file)) {
      return detector.manager;
    }
  }
  return std::nullopt;
}

[[nodiscard]] std::optional<DetectionResult> detect_node_run_manager_details(
    const std::filesystem::path& dir, std::string_view run_target)
{
  const auto package_json = read_file(dir / "package.json");
  if (!package_json
      || !json_object_has_key(*package_json, "scripts", run_target))
  {
    return std::nullopt;
  }

  if (auto manager = detect_node_lockfile_manager(dir)) {
    return DetectionResult {*manager, DetectionStrength::strong};
  }
  if (auto manager = node_manager_from_package_json(*package_json)) {
    return DetectionResult {*manager, DetectionStrength::strong};
  }
  return DetectionResult {ManagerType::npm,
                          DetectionStrength::weak_node_fallback};
}

[[nodiscard]] std::optional<DetectionResult> detect_node_fallback_details(
    const std::filesystem::path& dir)
{
  const auto package_json = read_file(dir / "package.json");
  if (!package_json) {
    return std::nullopt;
  }

  const auto has_package_manager =
      json_object_has_member(*package_json, "packageManager");
  if (!has_package_manager) {
    return std::nullopt;
  }

  if (*has_package_manager) {
    const auto manager = node_manager_from_package_json(*package_json);
    if (!manager) {
      return std::nullopt;
    }
    return DetectionResult {*manager, DetectionStrength::strong};
  }

  return DetectionResult {ManagerType::npm,
                          DetectionStrength::weak_node_fallback};
}

[[nodiscard]] std::optional<DetectionResult> detect_in_dir_details(
    const std::filesystem::path& dir)
{
  for (const auto detector : lockfile_detectors) {
    if (path_exists(dir, detector.file)) {
      return DetectionResult {detector.manager, DetectionStrength::strong};
    }
  }

  if (path_exists(dir, "pyproject.toml")) {
    const auto pyproject = read_file(dir / "pyproject.toml");
    if (pyproject) {
      if (has_toml_section(*pyproject, "tool.poetry")) {
        return DetectionResult {ManagerType::poetry, DetectionStrength::strong};
      }
      if (has_toml_section(*pyproject, "tool.pdm")) {
        return DetectionResult {ManagerType::pdm, DetectionStrength::strong};
      }
      if (has_toml_section(*pyproject, "tool.uv")) {
        return DetectionResult {ManagerType::uv, DetectionStrength::strong};
      }
    }
  }

  return detect_node_fallback_details(dir);
}

[[nodiscard]] std::optional<std::string_view> first_non_empty(
    const std::vector<std::string>& values)
{
  for (const auto& value : values) {
    if (!value.empty()) {
      return std::string_view {value};
    }
  }
  return std::nullopt;
}

[[nodiscard]] std::optional<std::string_view> preferred_run_target(
    std::string_view action, const CommandArgs& command_args)
{
  if (is_run_action(action)) {
    return first_non_empty(command_args.packages);
  }
  if (is_exec_action(action) && command_args.manager_args.size() >= 2
      && iequals(command_args.manager_args[0], "run"))
  {
    return std::string_view {command_args.manager_args[1]};
  }
  return std::nullopt;
}

[[nodiscard]] std::optional<ManagerType> detect_from_path_with_preference(
    std::filesystem::path start_dir, std::optional<std::string_view> run_target)
{
  auto current = std::filesystem::absolute(std::move(start_dir));
  auto weak_run_node_fallback = std::optional<ManagerType> {};
  auto weak_node_fallback = std::optional<ManagerType> {};

  while (true) {
    if (run_target) {
      if (auto detected = detect_node_run_manager_details(current, *run_target))
      {
        if (detected->strength == DetectionStrength::strong) {
          return detected->manager;
        }
        if (!weak_run_node_fallback) {
          weak_run_node_fallback = detected->manager;
        }
      }
    }

    if (auto detected = detect_in_dir_details(current)) {
      if (detected->strength == DetectionStrength::strong) {
        if (weak_run_node_fallback) {
          if (is_node_manager(detected->manager)) {
            return detected->manager;
          }
          // Keep climbing so a child plain package.json can still inherit a
          // stronger parent Node workspace manager above an intermediate
          // Cargo/Python root.
        } else if (weak_node_fallback) {
          if (is_node_manager(detected->manager)) {
            return detected->manager;
          }
          // Same rule for generic package detection: a weak Node child should
          // not be locked to npm until we've exhausted parent directories.
        } else {
          return detected->manager;
        }
      } else if (!weak_node_fallback) {
        weak_node_fallback = detected->manager;
      }
    }

    const auto parent = current.parent_path();
    if (parent == current || parent.empty()) {
      return weak_run_node_fallback ? weak_run_node_fallback
                                    : weak_node_fallback;
    }
    current = parent;
  }
}
}  // namespace

std::optional<ManagerType> detect_package_manager()
{
  return detect_package_manager_from_path(std::filesystem::current_path());
}

std::optional<ManagerType> detect_package_manager_from_path(
    const std::filesystem::path& start_dir)
{
  return detect_from_path_with_preference(start_dir, std::nullopt);
}

std::optional<ManagerType> detect_package_manager_for_command(
    std::string_view action, const CommandArgs& command_args)
{
  return detect_package_manager_for_command_from_path(
      std::filesystem::current_path(), action, command_args);
}

std::optional<ManagerType> detect_package_manager_for_command_from_path(
    const std::filesystem::path& start_dir,
    std::string_view action,
    const CommandArgs& command_args)
{
  return detect_from_path_with_preference(
      start_dir, preferred_run_target(action, command_args));
}
}  // namespace mg::pkgm
