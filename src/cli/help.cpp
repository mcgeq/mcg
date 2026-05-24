#include <array>
#include <string>

#include <mg/cli/help.hpp>
#include <mg/core/logger.hpp>
#include <mg/core/project_info.hpp>

namespace mg::cli
{
namespace
{
constexpr auto k_main_help_lines = std::array {
    std::string_view {"mg - Multi-package manager CLI"},
    std::string_view {"Usage: mg [options] <command> [args]"},
    std::string_view {"Commands: add, remove, upgrade, install, list, analyze, "
                      "run, exec, version"},
    std::string_view {"FS Commands: fs create, fs remove, fs copy, fs move, fs "
                      "list, fs exists, fs read, fs write"},
    std::string_view {"Shared Options: --cwd/-C <path>, --dry-run/-d"},
    std::string_view {
        "Package Options: --dev/-D, --profile/-P <name> (repeatable), "
        "--group/-G <name> (alias), -- <manager args>"},
    std::string_view {"General Options: --help, -h, --version"},
};

constexpr auto k_fs_help_lines = std::array {
    std::string_view {"Usage: mg fs <subcommand> [args]"},
    std::string_view {
        "Options before subcommand: --cwd/-C <path>, --dry-run/-d"},
    std::string_view {
        "Subcommands: create(c,touch), remove(r), copy(y), move(m), list(ls), "
        "exists(test), read(cat), write(echo)"},
};
}  // namespace

std::span<const std::string_view> main_help_lines() noexcept
{
  return k_main_help_lines;
}

std::span<const std::string_view> fs_help_lines() noexcept
{
  return k_fs_help_lines;
}

std::string_view version_line()
{
  static const auto line =
      std::string {"mg "} + std::string {project_version()};
  return line;
}

void print_help()
{
  logger().info_multi(main_help_lines());
}

void print_fs_help()
{
  logger().info_multi(fs_help_lines());
}

void print_version()
{
  log_info("{}", version_line());
}
}  // namespace mg::cli
