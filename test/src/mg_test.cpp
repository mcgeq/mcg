#include <mg/mg.hpp>
#include <catch2/catch_test_macros.hpp>

#include <chrono>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <initializer_list>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

#if defined(_WIN32) && !defined(_MSC_VER)
#  if !defined(NOMINMAX)
#    define NOMINMAX
#  endif
#  if !defined(WIN32_LEAN_AND_MEAN)
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#endif

namespace
{
struct TemporaryDirectory
{
  explicit TemporaryDirectory(std::string_view name)
  {
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    path = std::filesystem::temp_directory_path()
           / ("mg-" + std::string {name} + "-" + std::to_string(stamp));
    std::filesystem::create_directories(path);
  }

  TemporaryDirectory(const TemporaryDirectory&) = delete;
  auto operator=(const TemporaryDirectory&) -> TemporaryDirectory& = delete;

  ~TemporaryDirectory()
  {
    auto ec = std::error_code {};
    std::filesystem::remove_all(path, ec);
  }

  std::filesystem::path path {};
};

struct RuntimeReset
{
  ~RuntimeReset()
  {
    mg::set_runtime({});
  }
};

struct CapturedRuntime
{
  CapturedRuntime()
      : previous_level {mg::logger().level},
        previous_ansi {mg::logger().enable_ansi}
  {
    mg::set_runtime({
        .out = &out,
        .err = &err,
    });
    mg::logger().level = mg::LogLevel::info;
    mg::logger().enable_ansi = false;
  }

  CapturedRuntime(const CapturedRuntime&) = delete;
  auto operator=(const CapturedRuntime&) -> CapturedRuntime& = delete;

  ~CapturedRuntime()
  {
    mg::logger().level = previous_level;
    mg::logger().enable_ansi = previous_ansi;
    mg::set_runtime({});
  }

  std::ostringstream out {};
  std::ostringstream err {};
  mg::LogLevel previous_level;
  bool previous_ansi;
};

void write_test_file(const std::filesystem::path& path, std::string_view content)
{
  std::filesystem::create_directories(path.parent_path());
  auto file = std::ofstream {path, std::ios::binary};
  file << content;
}

[[nodiscard]] auto make_command_args(
    std::initializer_list<std::string_view> packages = {},
    std::initializer_list<std::string_view> manager_args = {}) -> mg::CommandArgs
{
  auto args = mg::CommandArgs {};
  for (const auto package : packages) {
    args.add_package(package);
  }
  for (const auto arg : manager_args) {
    args.add_manager_arg(arg);
  }
  return args;
}

[[nodiscard]] auto run_args(std::initializer_list<std::string_view> args)
{
  const auto argv = std::vector<std::string_view> {args};
  return mg::run(argv);
}

[[nodiscard]] auto make_package_options(
    std::initializer_list<std::string_view> profiles = {},
    bool dev = false) -> mg::PackageOptions
{
  auto options = mg::PackageOptions {};
  options.dev = dev;
  for (const auto profile : profiles) {
    REQUIRE(options.add_profile(profile));
  }
  return options;
}

void expect_command(mg::ManagerType manager,
                    std::string_view action,
                    const mg::CommandArgs& args,
                    const mg::PackageOptions& options,
                    const std::vector<std::string>& expected)
{
  auto argv = std::vector<std::string> {std::string {mg::manager_name(manager)}};

  REQUIRE(mg::pkgm::append_command_args(argv, manager, action, args, options));
  REQUIRE(argv == expected);
}

void expect_no_command(mg::ManagerType manager,
                       std::string_view action,
                       const mg::CommandArgs& args)
{
  auto argv = std::vector<std::string> {std::string {mg::manager_name(manager)}};

  REQUIRE_FALSE(mg::pkgm::append_command_args(
      argv,
      manager,
      action,
      args,
      mg::PackageOptions {}));
}

void require_planned_command(
    const std::expected<mg::pkgm::PlannedCommand, mg::MgError>& planned,
    mg::ManagerType manager,
    const std::vector<std::string>& expected)
{
  REQUIRE(planned.has_value());
  REQUIRE(planned->manager_type == manager);
  REQUIRE(planned->argv == expected);
}

#if defined(_WIN32)
[[nodiscard]] auto get_env_string(const char* name) -> std::optional<std::string>
{
#  if defined(_MSC_VER)
  char* raw_value = nullptr;
  size_t raw_size = 0;
  if (_dupenv_s(&raw_value, &raw_size, name) != 0 || raw_value == nullptr) {
    return std::nullopt;
  }

  auto guard = std::unique_ptr<char, decltype(&std::free)> {raw_value, &std::free};
  return std::string {guard.get()};
#  else
  const auto required_size = GetEnvironmentVariableA(name, nullptr, 0);
  if (required_size == 0) {
    return std::nullopt;
  }

  auto value = std::string(required_size, '\0');
  const auto written_size =
      GetEnvironmentVariableA(name, value.data(), required_size);
  if (written_size == 0 || written_size >= required_size) {
    return std::nullopt;
  }

  value.resize(written_size);
  return value;
#  endif
}

[[nodiscard]] auto set_env_string(const char* name, const char* value) -> bool
{
#  if defined(_MSC_VER)
  return _putenv_s(name, value) == 0;
#  else
  return SetEnvironmentVariableA(name, value[0] == '\0' ? nullptr : value) != 0;
#  endif
}

struct EnvironmentVariableRestore
{
  explicit EnvironmentVariableRestore(const char* variable_name)
      : name {variable_name},
        value {get_env_string(variable_name)}
  {}

  EnvironmentVariableRestore(const EnvironmentVariableRestore&) = delete;
  auto operator=(const EnvironmentVariableRestore&) -> EnvironmentVariableRestore& = delete;

  ~EnvironmentVariableRestore()
  {
    if (value.has_value()) {
      static_cast<void>(set_env_string(name.c_str(), value->c_str()));
    } else {
      static_cast<void>(set_env_string(name.c_str(), ""));
    }
  }

  std::string name;
  std::optional<std::string> value;
};
#endif
}  // namespace

TEST_CASE("project_name reports the package name", "[mg]")
{
  REQUIRE(mg::project_name() == mg::k_project_name);
  REQUIRE(mg::project_version() == mg::k_project_version);
}

TEST_CASE("package options include implicit dev profile once", "[mg]")
{
  auto options = mg::PackageOptions {};
  options.dev = true;
  REQUIRE(options.add_profile("dev"));
  REQUIRE(options.add_profile("docs"));

  REQUIRE(options.effective_profile_count() == 2);
  REQUIRE(options.effective_profile_at(0) == std::string_view {"dev"});
  REQUIRE(options.effective_profile_at(1) == std::string_view {"docs"});
}

TEST_CASE("package options target the last explicit profile for add remove flows",
          "[mg]")
{
  auto options = mg::PackageOptions {};
  options.dev = true;
  REQUIRE(options.add_profile("docs"));
  REQUIRE(options.add_profile("lint"));

  REQUIRE(options.target_profile() == std::string_view {"lint"});

  expect_command(mg::ManagerType::uv,
                 "add",
                 make_command_args({"ruff"}),
                 options,
                 {"uv", "add", "--dev", "--group", "lint", "ruff"});
  expect_command(mg::ManagerType::uv,
                 "remove",
                 make_command_args({"ruff"}),
                 options,
                 {"uv", "remove", "--dev", "--group", "lint", "ruff"});
  expect_command(mg::ManagerType::pdm,
                 "add",
                 make_command_args({"ruff"}),
                 options,
                 {"pdm", "add", "--dev", "--group", "lint", "ruff"});
  expect_command(mg::ManagerType::pdm,
                 "remove",
                 make_command_args({"ruff"}),
                 options,
                 {"pdm", "remove", "--dev", "--group", "lint", "ruff"});
}

TEST_CASE("registry maps uv grouped install", "[mg]")
{
  auto args = mg::CommandArgs {};
  args.add_manager_arg("--frozen");

  auto options = mg::PackageOptions {};
  REQUIRE(options.add_profile("docs"));

  auto argv = std::vector<std::string> {"uv"};
  REQUIRE(mg::pkgm::append_command_args(
      argv,
      mg::ManagerType::uv,
      "install",
      args,
      options));

  REQUIRE(argv == std::vector<std::string> {
                      "uv",
                      "sync",
                      "--group",
                      "docs",
                      "--frozen",
                  });
}

TEST_CASE("registry maps core add remove and upgrade commands", "[mg]")
{
  expect_command(mg::ManagerType::cargo,
                 "add",
                 make_command_args({"serde"}),
                 {},
                 {"cargo", "add", "serde"});
  expect_command(mg::ManagerType::npm,
                 "remove",
                 make_command_args({"lodash"}),
                 {},
                 {"npm", "uninstall", "lodash"});
  expect_command(mg::ManagerType::pnpm,
                 "add",
                 make_command_args({"lodash"}),
                 {},
                 {"pnpm", "add", "lodash"});
  expect_command(mg::ManagerType::bun,
                 "remove",
                 make_command_args({"lodash"}),
                 {},
                 {"bun", "remove", "lodash"});
  expect_command(mg::ManagerType::yarn,
                 "upgrade",
                 make_command_args({"react"}),
                 {},
                 {"yarn", "up", "react"});
  expect_command(mg::ManagerType::pip,
                 "upgrade",
                 make_command_args({"requests", "httpx"}),
                 {},
                 {"pip", "install", "--upgrade", "requests", "httpx"});
  expect_no_command(mg::ManagerType::pip, "upgrade", make_command_args());
}

TEST_CASE("registry maps python manager install list and profile options", "[mg]")
{
  expect_command(mg::ManagerType::uv,
                 "upgrade",
                 make_command_args({"requests"}),
                 {},
                 {"uv", "sync", "--upgrade-package", "requests"});
  expect_command(mg::ManagerType::uv,
                 "analyze",
                 make_command_args(),
                 {},
                 {"uv", "tree"});
  expect_command(mg::ManagerType::poetry,
                 "list",
                 make_command_args(),
                 {},
                 {"poetry", "show"});
  expect_command(mg::ManagerType::poetry,
                 "install",
                 make_command_args(),
                 make_package_options({"docs", "lint"}, true),
                 {"poetry", "install", "--with", "dev", "--with", "docs", "--with", "lint"});
  expect_command(mg::ManagerType::pdm,
                 "list",
                 make_command_args(),
                 make_package_options({"dev", "docs"}, true),
                 {"pdm", "list", "--dev", "--group", "docs"});
  expect_command(mg::ManagerType::pdm,
                 "remove",
                 make_command_args({"pytest"}),
                 make_package_options({"test"}, true),
                 {"pdm", "remove", "--dev", "--group", "test", "pytest"});
}

TEST_CASE("registry forwards exec and run command arguments", "[mg]")
{
  expect_command(mg::ManagerType::cargo,
                 "exec",
                 make_command_args({}, {"metadata", "--no-deps"}),
                 {},
                 {"cargo", "metadata", "--no-deps"});
  expect_command(mg::ManagerType::npm,
                 "exec",
                 make_command_args({}, {"exec", "--", "node", "smoke.js"}),
                 {},
                 {"npm", "exec", "--", "node", "smoke.js"});
  expect_command(mg::ManagerType::uv,
                 "exec",
                 make_command_args({}, {"run", "python", "app.py"}),
                 make_package_options({"docs"}, true),
                 {"uv", "run", "python", "app.py"});
  expect_command(mg::ManagerType::pdm,
                 "exec",
                 make_command_args({}, {"smoke"}),
                 {},
                 {"pdm", "smoke"});
  expect_no_command(mg::ManagerType::pnpm, "exec", make_command_args());

  expect_command(mg::ManagerType::npm,
                 "run",
                 make_command_args({"build"}, {"--watch"}),
                 {},
                 {"npm", "run", "build", "--", "--watch"});
  expect_command(mg::ManagerType::pnpm,
                 "run",
                 make_command_args({"build:apk"}, {"--mode", "release"}),
                 {},
                 {"pnpm", "run", "build:apk", "--", "--mode", "release"});
  expect_command(mg::ManagerType::poetry,
                 "run",
                 make_command_args({"pytest"}, {"-q"}),
                 {},
                 {"poetry", "run", "pytest", "-q"});
  expect_no_command(mg::ManagerType::pip,
                    "run",
                    make_command_args({"python"}));
}

TEST_CASE("executor formats previews with quoted cwd", "[mg]")
{
  const auto argv = std::vector<std::string> {
      "uv",
      "sync",
      "--project",
      "apps/api tools",
  };

  REQUIRE(mg::pkgm::format_command_preview(argv, "workspace tools")
          == "[cwd=\"workspace tools\"] uv sync --project \"apps/api tools\"");
}

#if defined(_WIN32)
TEST_CASE("executor resolves command shims through PATH and PATHEXT", "[mg]")
{
  const auto temp = TemporaryDirectory {"windows-command-resolve"};
  const auto path_restore = EnvironmentVariableRestore {"PATH"};
  const auto pathext_restore = EnvironmentVariableRestore {"PATHEXT"};
  write_test_file(temp.path / "fake-manager.cmd", "@echo off\r\n");

  auto path_value = temp.path.string();
  if (const auto existing_path = get_env_string("PATH"); existing_path.has_value()) {
    path_value += ';';
    path_value += *existing_path;
  }
  REQUIRE(set_env_string("PATH", path_value.c_str()));
  REQUIRE(set_env_string("PATHEXT", ".COM;.EXE;.BAT;.CMD;.PS1"));

  const auto resolved = mg::pkgm::resolve_windows_command_for_test("fake-manager");

  REQUIRE(resolved.has_value());
  auto ec = std::error_code {};
  REQUIRE(std::filesystem::equivalent(*resolved, temp.path / "fake-manager.cmd", ec));
  REQUIRE_FALSE(ec);
}
#endif

TEST_CASE("run prints help when no command is provided", "[mg]")
{
  auto capture = CapturedRuntime {};

  const auto args = std::vector<std::string_view> {"mg"};
  const auto result = mg::run(args);

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str().find("mg - Multi-package manager CLI")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("run prints help and version from public flags", "[mg]")
{
  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({"mg", "--help"});

    REQUIRE(result.has_value());
    REQUIRE(capture.out.str().find("Usage: mg [options] <command> [args]")
            != std::string::npos);
    REQUIRE(capture.err.str().empty());
  }

  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({"mg", "fs", "--help"});

    REQUIRE(result.has_value());
    REQUIRE(capture.out.str().find("Usage: mg fs <subcommand> [args]")
            != std::string::npos);
    REQUIRE(capture.err.str().empty());
  }

  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({"mg", "add", "-h"});

    REQUIRE(result.has_value());
    REQUIRE(capture.out.str().find("mg - Multi-package manager CLI")
            != std::string::npos);
    REQUIRE(capture.err.str().empty());
  }

  {
    auto capture = CapturedRuntime {};
    REQUIRE(run_args({"mg", "--version"}).has_value());
    REQUIRE(capture.out.str().find("mg ") != std::string::npos);

    capture.out.str({});
    capture.out.clear();
    REQUIRE(run_args({"mg", "version"}).has_value());
    REQUIRE(capture.out.str().find("mg ") != std::string::npos);
    REQUIRE(capture.err.str().empty());
  }
}

TEST_CASE("run rejects missing package and run targets before execution", "[mg]")
{
  {
    auto capture = CapturedRuntime {};
    const auto args = std::vector<std::string_view> {"mg", "add"};

    const auto result = mg::run(args);

    REQUIRE(result.has_value());
    REQUIRE(capture.err.str().find("No packages specified") != std::string::npos);
  }

  {
    auto capture = CapturedRuntime {};
    const auto args = std::vector<std::string_view> {"mg", "run"};

    const auto result = mg::run(args);

    REQUIRE(result.has_value());
    REQUIRE(capture.err.str().find("No run target specified") != std::string::npos);
  }
}

TEST_CASE("run reports unknown package commands after manager detection", "[mg]")
{
  const auto temp = TemporaryDirectory {"run-unknown-package-command"};
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "packageManager": "npm@10.0.0"
})json");
  auto capture = CapturedRuntime {};

  const auto result =
      run_args({"mg", "--dry-run", "--cwd", temp.path.string(), "frobnicate"});

  REQUIRE_FALSE(result.has_value());
  REQUIRE(result.error() == mg::MgError::unknown_subcommand);
  REQUIRE(capture.err.str().find("Unknown package command: frobnicate")
          != std::string::npos);
}

TEST_CASE("run reports missing cwd and profile option values", "[mg]")
{
  {
    auto capture = CapturedRuntime {};
    const auto args = std::vector<std::string_view> {"mg", "--cwd"};

    const auto result = mg::run(args);

    REQUIRE(result.has_value());
    REQUIRE(capture.err.str().find("Missing path after --cwd")
            != std::string::npos);
  }

  {
    auto capture = CapturedRuntime {};
    const auto args = std::vector<std::string_view> {"mg", "install", "--profile"};

    const auto result = mg::run(args);

    REQUIRE(result.has_value());
    REQUIRE(capture.err.str().find("Missing profile name after --profile")
            != std::string::npos);
  }
}

TEST_CASE("run forwards package options around the action", "[mg]")
{
  const auto temp = TemporaryDirectory {"run-package-options"};
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "packageManager": "pnpm@9.12.0"
})json");
  auto capture = CapturedRuntime {};

  const auto result = run_args({
      "mg",
      "-d",
      "--cwd",
      temp.path.string(),
      "--dev",
      "add",
      "--group",
      "docs",
      "mkdocs",
      "--",
      "--frozen",
  });

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str().find("Using pnpm package manager")
          != std::string::npos);
  REQUIRE(capture.out.str().find(
              "pnpm add --save-dev mkdocs --frozen")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("run forwards profile aliases and repeated groups in order", "[mg]")
{
  const auto temp = TemporaryDirectory {"run-package-profiles"};
  write_test_file(temp.path / "pyproject.toml",
                  R"toml([tool.uv]
package = false
)toml");
  auto capture = CapturedRuntime {};

  const auto result = run_args({
      "mg",
      "--dry-run",
      "--cwd",
      temp.path.string(),
      "--profile",
      "dev",
      "install",
      "-P",
      "docs",
      "--group=lint",
  });

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str().find("Using uv package manager") != std::string::npos);
  REQUIRE(capture.out.str().find(
              "uv sync --group dev --group docs --group lint")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("run forwards dev profile group combinations to target profile removals",
          "[mg]")
{
  const auto temp = TemporaryDirectory {"run-package-target-profile-removal"};
  write_test_file(temp.path / "pyproject.toml",
                  "[project]\nname = \"demo\"\nversion = \"0.1.0\"\n\n[tool.pdm]\ndistribution = true\n");
  auto capture = CapturedRuntime {};

  const auto result = run_args({
      "mg",
      "--dry-run",
      "--cwd",
      temp.path.string(),
      "--dev",
      "remove",
      "--profile",
      "docs",
      "--group",
      "lint",
      "pytest",
  });

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str().find("Using pdm package manager")
          != std::string::npos);
  REQUIRE(capture.out.str().find("pdm remove --dev --group lint pytest")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("run forwards exec and run passthrough arguments", "[mg]")
{
  const auto temp = TemporaryDirectory {"run-package-passthrough"};
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "packageManager": "npm@10.0.0",
  "scripts": {
    "build": "node build.js"
  }
})json");

  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({
        "mg",
        "--dry-run",
        "--cwd",
        temp.path.string(),
        "exec",
        "--",
        "exec",
        "--",
        "node",
        "--version",
    });

    REQUIRE(result.has_value());
    REQUIRE(capture.out.str().find("npm exec -- node --version")
            != std::string::npos);
    REQUIRE(capture.err.str().empty());
  }

  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({
        "mg",
        "--dry-run",
        "--cwd",
        temp.path.string(),
        "run",
        "build",
        "--",
        "--watch",
    });

    REQUIRE(result.has_value());
    REQUIRE(capture.out.str().find("npm run build -- --watch")
            != std::string::npos);
    REQUIRE(capture.err.str().empty());
  }
}

TEST_CASE("run rejects package options before manager execution", "[mg]")
{
  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({"mg", "--frozen", "add", "ruff"});

    REQUIRE(result.has_value());
    REQUIRE(capture.err.str().find(
                "Unknown package option: --frozen (use -- to pass manager-native args)")
            != std::string::npos);
  }

  {
    auto capture = CapturedRuntime {};
    const auto result = run_args({"mg", "add", "--cwd"});

    REQUIRE(result.has_value());
    REQUIRE(capture.err.str().find("Missing path after --cwd")
            != std::string::npos);
  }
}

TEST_CASE("config finds files by walking parent directories", "[mg]")
{
  const auto temp = TemporaryDirectory {"config-walk"};
  const auto nested = temp.path / "apps" / "web";
  std::filesystem::create_directories(nested);
  auto config_file = std::ofstream {temp.path / "mg.toml"};
  config_file << "name = \"demo\"\n";
  config_file.close();

  const auto found = mg::config::find_config_file_from(nested, "mg.toml");

  REQUIRE(found.has_value());
  REQUIRE(found->lexically_normal() == (temp.path / "mg.toml").lexically_normal());
}

TEST_CASE("config file lookup handles absolute and missing paths", "[mg]")
{
  const auto temp = TemporaryDirectory {"config-absolute"};
  const auto config = temp.path / "mg.toml";
  write_test_file(config, "name = \"demo\"\n");

  const auto absolute = mg::config::find_config_file_from(temp.path, config.string());
  const auto missing =
      mg::config::find_config_file_from(temp.path, (temp.path / "missing.toml").string());
  const auto empty = mg::config::find_config_file_from(temp.path, "");

  REQUIRE(absolute.has_value());
  REQUIRE(absolute->lexically_normal() == config.lexically_normal());
  REQUIRE_FALSE(missing.has_value());
  REQUIRE_FALSE(empty.has_value());
}

TEST_CASE("config directories follow xdg home and windows fallback order", "[mg]")
{
  auto environment = mg::config::Environment {
      .xdg_config_home = std::filesystem::path {"xdg-config"},
      .xdg_cache_home = std::filesystem::path {"xdg-cache"},
      .home = std::filesystem::path {"home"},
      .appdata = std::filesystem::path {"appdata"},
      .localappdata = std::filesystem::path {"localappdata"},
  };

  auto config_dir = mg::config::get_config_dir(environment);
  auto cache_dir = mg::config::get_cache_dir(environment);
  REQUIRE(config_dir.has_value());
  REQUIRE(cache_dir.has_value());
  REQUIRE(*config_dir == std::filesystem::path {"xdg-config"} / "mg");
  REQUIRE(*cache_dir == std::filesystem::path {"xdg-cache"} / "mg");

  environment.xdg_config_home.reset();
  environment.xdg_cache_home.reset();
  config_dir = mg::config::get_config_dir(environment);
  cache_dir = mg::config::get_cache_dir(environment);
  REQUIRE(config_dir.has_value());
  REQUIRE(cache_dir.has_value());
  REQUIRE(*config_dir == std::filesystem::path {"home"} / ".config" / "mg");
  REQUIRE(*cache_dir == std::filesystem::path {"home"} / ".cache" / "mg");

  environment.home.reset();
  config_dir = mg::config::get_config_dir(environment);
  cache_dir = mg::config::get_cache_dir(environment);
  REQUIRE(config_dir.has_value());
  REQUIRE(cache_dir.has_value());
  REQUIRE(*config_dir == std::filesystem::path {"appdata"} / "mg");
  REQUIRE(*cache_dir == std::filesystem::path {"localappdata"} / "mg" / "cache");

  environment.appdata.reset();
  environment.localappdata.reset();
  REQUIRE_FALSE(mg::config::get_config_dir(environment).has_value());
  REQUIRE_FALSE(mg::config::get_cache_dir(environment).has_value());
}

TEST_CASE("package detection reads packageManager without lockfile", "[mg]")
{
  const auto temp = TemporaryDirectory {"package-manager-field"};
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "packageManager": "pnpm@9.12.0"
})json");

  REQUIRE(mg::pkgm::detect_package_manager_from_path(temp.path)
          == mg::ManagerType::pnpm);
}

TEST_CASE("package detection reads lockfiles with python lock precedence",
          "[mg]")
{
  {
    const auto temp = TemporaryDirectory {"detect-cargo-lockfile"};
    write_test_file(temp.path / "Cargo.toml",
                    "[package]\nname = \"demo\"\nversion = \"0.1.0\"\n");
    REQUIRE(mg::pkgm::detect_package_manager_from_path(temp.path)
            == mg::ManagerType::cargo);
  }

  {
    const auto temp = TemporaryDirectory {"detect-yarn-lockfile"};
    write_test_file(temp.path / "yarn.lock", "__metadata:\n  version: 8\n");
    REQUIRE(mg::pkgm::detect_package_manager_from_path(temp.path)
            == mg::ManagerType::yarn);
  }

  {
    const auto temp = TemporaryDirectory {"detect-python-lock-precedence"};
    write_test_file(temp.path / "requirements.txt", "requests\n");
    write_test_file(temp.path / "poetry.lock", "[[package]]\nname = \"demo\"\n");
    REQUIRE(mg::pkgm::detect_package_manager_from_path(temp.path)
            == mg::ManagerType::poetry);
  }
}

TEST_CASE("package detection ignores invalid package json fallback", "[mg]")
{
  const auto temp = TemporaryDirectory {"invalid-package-json"};
  write_test_file(temp.path / "package.json", R"json({ "name": "demo", )json");

  REQUIRE_FALSE(mg::pkgm::detect_package_manager_from_path(temp.path).has_value());
}

TEST_CASE("plain package json falls back to npm", "[mg]")
{
  const auto temp = TemporaryDirectory {"plain-package-json"};
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "version": "1.0.0"
})json");

  REQUIRE(mg::pkgm::detect_package_manager_from_path(temp.path)
          == mg::ManagerType::npm);
}

TEST_CASE("package detection reads pyproject tool sections", "[mg]")
{
  const auto uv = TemporaryDirectory {"pyproject-uv"};
  write_test_file(uv.path / "pyproject.toml",
                  "[project]\nname = \"demo\"\nversion = \"0.1.0\"\n\n[tool.uv]\npackage = true\n");
  REQUIRE(mg::pkgm::detect_package_manager_from_path(uv.path)
          == mg::ManagerType::uv);

  const auto poetry = TemporaryDirectory {"pyproject-poetry"};
  write_test_file(poetry.path / "pyproject.toml",
                  "[tool.poetry]\nname = \"demo\"\nversion = \"0.1.0\"\n");
  REQUIRE(mg::pkgm::detect_package_manager_from_path(poetry.path)
          == mg::ManagerType::poetry);

  const auto pdm = TemporaryDirectory {"pyproject-pdm"};
  write_test_file(pdm.path / "pyproject.toml",
                  "[project]\nname = \"demo\"\nversion = \"0.1.0\"\n\n[tool.pdm]\ndistribution = true\n");
  REQUIRE(mg::pkgm::detect_package_manager_from_path(pdm.path)
          == mg::ManagerType::pdm);
}

TEST_CASE("package detection ignores commented and quoted pyproject tool sections",
          "[mg]")
{
  const auto temp = TemporaryDirectory {"pyproject-false-sections"};
  write_test_file(temp.path / "pyproject.toml",
                  "[project]\nname = \"demo\"\ndescription = \"mentions [tool.uv] only\"\n# [tool.poetry]\n");

  REQUIRE_FALSE(mg::pkgm::detect_package_manager_from_path(temp.path).has_value());
}

TEST_CASE("pyproject tool section wins over package json fallback", "[mg]")
{
  const auto temp = TemporaryDirectory {"pyproject-over-package-json"};
  write_test_file(temp.path / "pyproject.toml",
                  "[project]\nname = \"demo\"\nversion = \"0.1.0\"\n\n[tool.uv.sources]\n");
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "packageManager": "pnpm@9.12.0"
})json");

  REQUIRE(mg::pkgm::detect_package_manager_from_path(temp.path)
          == mg::ManagerType::uv);
}

TEST_CASE("run borrows parent pnpm manager for child package script", "[mg]")
{
  const auto temp = TemporaryDirectory {"pnpm-workspace-run"};
  const auto child = temp.path / "packages" / "app";
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "workspace-root",
  "packageManager": "pnpm@9.12.0"
})json");
  write_test_file(child / "package.json",
                  R"json({
  "name": "app",
  "scripts": {
    "build": "node build.js"
  }
})json");

  auto args = mg::CommandArgs {};
  args.add_package("build");

  REQUIRE(mg::pkgm::detect_package_manager_for_command_from_path(
              child,
              "run",
              args)
          == mg::ManagerType::pnpm);
}

TEST_CASE("exec run borrows parent pnpm manager for child package script", "[mg]")
{
  const auto temp = TemporaryDirectory {"pnpm-workspace-exec-run"};
  const auto child = temp.path / "packages" / "app";
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "workspace-root",
  "packageManager": "pnpm@9.12.0"
})json");
  write_test_file(child / "package.json",
                  R"json({
  "name": "app",
  "scripts": {
    "build": "node build.js"
  }
})json");

  auto args = mg::CommandArgs {};
  args.add_manager_arg("run");
  args.add_manager_arg("build");

  REQUIRE(mg::pkgm::detect_package_manager_for_command_from_path(
              child,
              "exec",
              args)
          == mg::ManagerType::pnpm);

  const auto planned =
      mg::pkgm::plan_command_from_path(child, "exec", args, {});
  require_planned_command(planned,
                          mg::ManagerType::pnpm,
                          {"pnpm", "run", "build"});
}

TEST_CASE("run falls back to cargo when package script target is absent", "[mg]")
{
  const auto temp = TemporaryDirectory {"mixed-run-fallback"};
  write_test_file(temp.path / "Cargo.toml",
                  "[package]\nname = \"demo\"\nversion = \"0.1.0\"\n");
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "scripts": {
    "test": "node test.js"
  },
  "dependencies": {
    "build": "1.0.0"
  }
})json");

  auto args = mg::CommandArgs {};
  args.add_package("build");

  REQUIRE(mg::pkgm::detect_package_manager_for_command_from_path(
              temp.path,
              "run",
              args)
          == mg::ManagerType::cargo);
}

TEST_CASE("package detection walks parents and balances child node fallback",
          "[mg]")
{
  {
    const auto temp = TemporaryDirectory {"detect-parent-poetry"};
    const auto child = temp.path / "workspace" / "packages" / "app";
    std::filesystem::create_directories(child);
    write_test_file(temp.path / "workspace" / "poetry.lock",
                    "[[package]]\nname = \"demo\"\n");

    REQUIRE(mg::pkgm::detect_package_manager_from_path(child)
            == mg::ManagerType::poetry);
  }

  {
    const auto temp = TemporaryDirectory {"detect-parent-pnpm"};
    const auto child = temp.path / "workspace" / "packages" / "app";
    write_test_file(temp.path / "workspace" / "package.json",
                    R"json({
  "name": "workspace-root",
  "packageManager": "pnpm@9.12.0"
})json");
    write_test_file(child / "package.json",
                    R"json({
  "name": "app",
  "version": "1.0.0"
})json");

    REQUIRE(mg::pkgm::detect_package_manager_from_path(child)
            == mg::ManagerType::pnpm);
  }

  {
    const auto temp = TemporaryDirectory {"detect-child-node-over-cargo"};
    const auto child = temp.path / "workspace" / "apps" / "web";
    write_test_file(temp.path / "workspace" / "Cargo.toml",
                    "[package]\nname = \"workspace-root\"\nversion = \"0.1.0\"\n");
    write_test_file(child / "package.json",
                    R"json({
  "name": "web",
  "version": "1.0.0"
})json");

    REQUIRE(mg::pkgm::detect_package_manager_from_path(child)
            == mg::ManagerType::npm);
  }
}

TEST_CASE("workspace child routing keeps climbing for stronger parent node managers",
          "[mg]")
{
  const auto temp = TemporaryDirectory {"detect-parent-pnpm-above-cargo"};
  const auto child = temp.path / "workspace" / "native" / "packages" / "app";
  write_test_file(temp.path / "workspace" / "package.json",
                  R"json({
  "name": "workspace-root",
  "packageManager": "pnpm@9.12.0"
})json");
  write_test_file(temp.path / "workspace" / "native" / "Cargo.toml",
                  "[package]\nname = \"native-root\"\nversion = \"0.1.0\"\n");
  write_test_file(child / "package.json",
                  R"json({
  "name": "app",
  "version": "1.0.0",
  "scripts": {
    "build": "node build.js"
  }
})json");

  REQUIRE(mg::pkgm::detect_package_manager_from_path(child)
          == mg::ManagerType::pnpm);

  const auto planned_install =
      mg::pkgm::plan_command_from_path(child, "install", make_command_args(), {});
  require_planned_command(planned_install,
                          mg::ManagerType::pnpm,
                          {"pnpm", "install"});

  auto run_args = mg::CommandArgs {};
  run_args.add_package("build");
  REQUIRE(mg::pkgm::detect_package_manager_for_command_from_path(
              child,
              "run",
              run_args)
          == mg::ManagerType::pnpm);

  const auto planned_run =
      mg::pkgm::plan_command_from_path(child, "run", run_args, {});
  require_planned_command(planned_run,
                          mg::ManagerType::pnpm,
                          {"pnpm", "run", "build"});

  auto exec_args = mg::CommandArgs {};
  exec_args.add_manager_arg("run");
  exec_args.add_manager_arg("build");
  REQUIRE(mg::pkgm::detect_package_manager_for_command_from_path(
              child,
              "exec",
              exec_args)
          == mg::ManagerType::pnpm);

  const auto planned_exec =
      mg::pkgm::plan_command_from_path(child, "exec", exec_args, {});
  require_planned_command(planned_exec,
                          mg::ManagerType::pnpm,
                          {"pnpm", "run", "build"});
}

TEST_CASE("exec run prefers package manager declared by package json", "[mg]")
{
  const auto temp = TemporaryDirectory {"exec-run-preference"};
  write_test_file(temp.path / "Cargo.toml",
                  "[package]\nname = \"demo\"\nversion = \"0.1.0\"\n");
  write_test_file(temp.path / "package.json",
                  R"json({
  "name": "demo",
  "packageManager": "pnpm@9.12.0",
  "scripts": {
    "build": "echo build"
  }
})json");

  auto args = mg::CommandArgs {};
  args.add_manager_arg("run");
  args.add_manager_arg("build");

  REQUIRE(mg::pkgm::detect_package_manager_for_command_from_path(
              temp.path,
              "exec",
              args)
          == mg::ManagerType::pnpm);
}

TEST_CASE("package core plans nested uv and poetry commands", "[mg]")
{
  {
    const auto temp = TemporaryDirectory {"plan-nested-uv"};
    const auto nested = temp.path / "workspace" / "apps" / "demo";
    std::filesystem::create_directories(nested);
    write_test_file(temp.path / "workspace" / "pyproject.toml",
                    "[project]\nname = \"demo\"\nversion = \"0.1.0\"\n\n[tool.uv]\npackage = true\n");

    auto args = make_command_args({}, {"--frozen"});
    auto options = make_package_options({"docs"});
    const auto planned =
        mg::pkgm::plan_command_from_path(nested, "install", args, options);

    require_planned_command(planned,
                            mg::ManagerType::uv,
                            {"uv", "sync", "--group", "docs", "--frozen"});
  }

  {
    const auto temp = TemporaryDirectory {"plan-nested-poetry"};
    const auto nested = temp.path / "workspace" / "packages" / "api";
    std::filesystem::create_directories(nested);
    write_test_file(temp.path / "workspace" / "poetry.lock",
                    "[[package]]\nname = \"demo\"\n");

    auto args = make_command_args({"pytest"});
    auto options = make_package_options({}, true);
    const auto planned =
        mg::pkgm::plan_command_from_path(nested, "add", args, options);

    require_planned_command(
        planned,
        mg::ManagerType::poetry,
        {"poetry", "add", "--group", "dev", "pytest"});
  }
}

TEST_CASE("package core plans workspace and mixed run commands", "[mg]")
{
  {
    const auto temp = TemporaryDirectory {"plan-pnpm-workspace-run"};
    const auto child = temp.path / "workspace" / "packages" / "app";
    write_test_file(temp.path / "workspace" / "package.json",
                    R"json({
  "name": "workspace-root",
  "packageManager": "pnpm@9.12.0"
})json");
    write_test_file(child / "package.json",
                    R"json({
  "name": "app",
  "scripts": {
    "build": "node build.js"
  }
})json");

    auto args = make_command_args({"build"});
    const auto planned =
        mg::pkgm::plan_command_from_path(child, "run", args, {});

    require_planned_command(planned,
                            mg::ManagerType::pnpm,
                            {"pnpm", "run", "build"});
  }

  {
    const auto temp = TemporaryDirectory {"plan-node-script-over-cargo"};
    write_test_file(temp.path / "Cargo.toml",
                    "[package]\nname = \"demo\"\nversion = \"0.1.0\"\n");
    write_test_file(temp.path / "package-lock.json", "{\n  \"name\": \"demo\"\n}\n");
    write_test_file(temp.path / "package.json",
                    R"json({
  "name": "demo",
  "scripts": {
    "build:apk": "echo build apk"
  }
})json");

    auto args = make_command_args({"build:apk"});
    const auto planned =
        mg::pkgm::plan_command_from_path(temp.path, "run", args, {});

    require_planned_command(planned,
                            mg::ManagerType::npm,
                            {"npm", "run", "build:apk"});
  }
}

TEST_CASE("package core returns no package manager without executing", "[mg]")
{
  const auto temp = TemporaryDirectory {"plan-no-manager"};

  const auto planned = mg::pkgm::plan_command_from_path(
      temp.path,
      "install",
      make_command_args(),
      {});

  REQUIRE_FALSE(planned.has_value());
  REQUIRE(planned.error() == mg::MgError::no_package_manager);
}

TEST_CASE("package core dry-run executes planned command with cwd preview", "[mg]")
{
  const auto temp = TemporaryDirectory {"execute-dry-run-cwd"};
  const auto project = temp.path / "workspace" / "api tools";
  write_test_file(project / "package.json",
                  R"json({
  "name": "api-tools",
  "packageManager": "pnpm@9.12.0"
})json");
  auto capture = CapturedRuntime {};
  auto options = mg::PackageOptions {};
  options.cwd = project;
  options.dry_run = true;

  const auto result =
      mg::pkgm::execute_command("install", make_command_args(), options);

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str().find("Using pnpm package manager")
          != std::string::npos);
  REQUIRE(capture.out.str().find("Executing: [cwd=") != std::string::npos);
  REQUIRE(capture.out.str().find("pnpm install") != std::string::npos);
  REQUIRE(capture.out.str().find("\"") != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("package core reports no package manager through execute command",
          "[mg]")
{
  const auto temp = TemporaryDirectory {"execute-no-manager"};
  auto capture = CapturedRuntime {};
  auto options = mg::PackageOptions {};
  options.cwd = temp.path;
  options.dry_run = true;

  const auto result =
      mg::pkgm::execute_command("install", make_command_args(), options);

  REQUIRE_FALSE(result.has_value());
  REQUIRE(result.error() == mg::MgError::no_package_manager);
  REQUIRE(capture.err.str().find("No supported package manager detected")
          != std::string::npos);
}

TEST_CASE("fs wildcard star stays within a single path segment", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-star-segment"};
  auto out = std::ostringstream {};
  auto err = std::ostringstream {};
  const auto reset = RuntimeReset {};
  mg::set_runtime({
      .out = &out,
      .err = &err,
      .fs_cwd = temp.path,
  });
  write_test_file(temp.path / "src" / "app.cpp", "int main() {}\n");
  write_test_file(temp.path / "src" / "nested" / "app.cpp", "int main() {}\n");

  const auto result = mg::fs::fs_list_wildcard("src/*.cpp", false);

  REQUIRE(result.has_value());
  REQUIRE(out.str() == "  app.cpp\n");
  REQUIRE(err.str().empty());
}

TEST_CASE("fs wildcard double star matches recursive path segments", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-double-star"};
  auto out = std::ostringstream {};
  auto err = std::ostringstream {};
  const auto reset = RuntimeReset {};
  mg::set_runtime({
      .out = &out,
      .err = &err,
      .fs_cwd = temp.path,
  });
  write_test_file(temp.path / "src" / "app.cpp", "int main() {}\n");
  write_test_file(temp.path / "src" / "nested" / "app.cpp", "int main() {}\n");
  write_test_file(temp.path / "src" / "nested" / "keep.txt", "keep\n");

  const auto result = mg::fs::fs_list_wildcard("src/**/*.cpp", false);

  REQUIRE(result.has_value());
  REQUIRE(out.str() == "  app.cpp\n  nested/app.cpp\n");
  REQUIRE(err.str().empty());
}

TEST_CASE("fs wildcard reports no matches and missing roots", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-wildcard-empty"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "src" / "app.cpp", "int main() {}\n");

  const auto no_match = mg::fs::fs_list_wildcard("src/*.zig", false);

  REQUIRE(no_match.has_value());
  REQUIRE(capture.out.str().find("No files matched: src/*.zig")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());

  capture.out.str({});
  capture.out.clear();
  const auto missing_root = mg::fs::fs_list_wildcard("missing/*.cpp", false);

  REQUIRE(missing_root.has_value());
  REQUIRE(capture.err.str().find("Path not found: missing/*.cpp")
          != std::string::npos);
}

TEST_CASE("fs wildcard remove reports no matches", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-remove-wildcard-empty"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "logs" / "keep.log", "keep\n");

  const auto result = mg::fs::fs_remove_wildcard("logs/*.tmp", false, false);

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str().find("No files matched: logs/*.tmp")
          != std::string::npos);
  REQUIRE(std::filesystem::exists(temp.path / "logs" / "keep.log"));
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs commands reject invalid arity without touching files", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-invalid-arity"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;

  const auto write_args =
      std::vector<std::string_view> {"mg", "fs", "write", "note.txt", "hello", "extra"};
  const auto write_result = mg::run(write_args);

  REQUIRE(write_result.has_value());
  REQUIRE(capture.out.str().find("Usage: mg fs write <path> <content>")
          != std::string::npos);
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "note.txt"));

  capture.out.str({});
  capture.out.clear();
  const auto move_args =
      std::vector<std::string_view> {"mg", "fs", "move", "a.txt", "b.txt", "c.txt"};
  const auto move_result = mg::run(move_args);

  REQUIRE(move_result.has_value());
  REQUIRE(capture.out.str().find("Usage: mg fs move <src> <dst>")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs command aliases route through public CLI", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-cli-aliases"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;

  REQUIRE(
      run_args({"mg", "--dry-run", "fs", "touch", "--dir", "-r", "src/", "notes.txt"})
          .has_value());
  REQUIRE(capture.out.str().find("[dry-run] Create directory: src/")
          != std::string::npos);
  REQUIRE(capture.out.str().find("[dry-run] Create directory: notes.txt")
          != std::string::npos);

  capture.out.str({});
  capture.out.clear();
  REQUIRE(run_args({"mg", "fs", "echo", "notes.txt", "hello"}).has_value());
  REQUIRE(run_args({"mg", "fs", "cat", "notes.txt"}).has_value());
  REQUIRE(capture.out.str().find("hello") != std::string::npos);

  capture.out.str({});
  capture.out.clear();
  REQUIRE(run_args({"mg", "fs", "mv", "notes.txt", "final.txt"}).has_value());
  REQUIRE(run_args({"mg", "fs", "test", "final.txt"}).has_value());
  REQUIRE(capture.out.str().find("Exists: final.txt") != std::string::npos);

  capture.out.str({});
  capture.out.clear();
  REQUIRE(run_args({"mg", "fs", "cp", "final.txt", "copy.txt"}).has_value());
  REQUIRE(run_args({"mg", "fs", "ls"}).has_value());
  REQUIRE(capture.out.str().find("  copy.txt\n") != std::string::npos);
  REQUIRE(capture.out.str().find("  final.txt\n") != std::string::npos);

  capture.out.str({});
  capture.out.clear();
  REQUIRE(run_args({"mg", "fs", "rm", "copy.txt", "final.txt"}).has_value());
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "copy.txt"));
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "final.txt"));
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs create handles recursive parent directories", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-create-recursive"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;

  const auto recursive =
      mg::fs::fs_create_extended("notes/daily.txt", false, true, false);
  REQUIRE(recursive.has_value());
  REQUIRE(std::filesystem::exists(temp.path / "notes" / "daily.txt"));

  const auto non_recursive =
      mg::fs::fs_create_extended("logs/today.txt", false, false, false);
  REQUIRE_FALSE(non_recursive.has_value());
  REQUIRE(non_recursive.error() == mg::MgError::create_file_failed);
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "logs" / "today.txt"));
}

TEST_CASE("fs copy requires recursive flag for directories", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-copy-recursive"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "src" / "nested" / "data.txt", "payload\n");

  const auto blocked = mg::fs::fs_copy_extended("src", "backup", false, false);
  REQUIRE(blocked.has_value());
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "backup"));
  REQUIRE(capture.err.str().find("src is a directory, use --recursive")
          != std::string::npos);

  capture.err.str({});
  capture.err.clear();
  const auto copied = mg::fs::fs_copy_extended("src", "backup", true, false);
  REQUIRE(copied.has_value());
  REQUIRE(std::filesystem::exists(temp.path / "backup" / "nested" / "data.txt"));
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs read preserves file contents", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-read"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "notes.txt", "line one\nline two");

  const auto result = mg::fs::fs_read("notes.txt", false);

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str() == "line one\nline two");
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs list marks directories and sorts entries", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-list"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "zeta.txt", "zeta\n");
  write_test_file(temp.path / "alpha.txt", "alpha\n");
  std::filesystem::create_directories(temp.path / "docs");

  const auto result = mg::fs::fs_list(".", false);

  REQUIRE(result.has_value());
  REQUIRE(capture.out.str() == "  alpha.txt\n  docs/\n  zeta.txt\n");
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs remove deletes recursive directory trees", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-remove-recursive"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "workspace" / "cache" / "tmp.txt", "trash\n");

  const auto result = mg::fs::fs_remove("workspace", true, false);

  REQUIRE(result.has_value());
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "workspace"));
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs remove wildcard deletes recursive matches", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-remove-recursive-wildcard"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "build" / "mobile" / "cache" / "app.tmp", "tmp\n");
  write_test_file(temp.path / "build" / "mobile" / "cache" / "keep.txt", "keep\n");

  const auto result = mg::fs::fs_remove_wildcard("build/**/*.tmp", false, false);

  REQUIRE(result.has_value());
  REQUIRE_FALSE(
      std::filesystem::exists(temp.path / "build" / "mobile" / "cache" / "app.tmp"));
  REQUIRE(std::filesystem::exists(
      temp.path / "build" / "mobile" / "cache" / "keep.txt"));
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs move renames files within the workspace", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-move-file"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "draft.txt", "hello\n");

  const auto result = mg::fs::fs_move("draft.txt", "final.txt", false);

  REQUIRE(result.has_value());
  REQUIRE(std::filesystem::exists(temp.path / "final.txt"));
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "draft.txt"));
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs move reports destination parent errors", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-move-parent-errors"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "draft.txt", "hello\n");

  const auto missing_parent = mg::fs::fs_move("draft.txt", "missing/final.txt", false);

  REQUIRE_FALSE(missing_parent.has_value());
  REQUIRE(missing_parent.error() == mg::MgError::move_failed);
  REQUIRE(capture.err.str().find("Destination parent directory not found: missing")
          != std::string::npos);
  REQUIRE(std::filesystem::exists(temp.path / "draft.txt"));
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "missing" / "final.txt"));

  capture.err.str({});
  capture.err.clear();
  write_test_file(temp.path / "parent.txt", "not a directory\n");

  const auto file_parent = mg::fs::fs_move("draft.txt", "parent.txt/final.txt", false);

  REQUIRE_FALSE(file_parent.has_value());
  REQUIRE(file_parent.error() == mg::MgError::move_failed);
  REQUIRE(capture.err.str().find("Destination parent is not a directory: parent.txt")
          != std::string::npos);
  REQUIRE(std::filesystem::exists(temp.path / "draft.txt"));
}

TEST_CASE("fs write overwrites file contents", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-write-overwrite"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;

  REQUIRE(mg::fs::fs_write("state.txt", "draft\n", false).has_value());
  REQUIRE(mg::fs::fs_write("state.txt", "final\n", false).has_value());

  auto input = std::ifstream {temp.path / "state.txt", std::ios::binary};
  auto buffer = std::ostringstream {};
  buffer << input.rdbuf();
  REQUIRE(buffer.str() == "final\n");
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs exists reports present and missing paths", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-exists"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "present.txt", "ok\n");

  mg::fs::fs_exists("present.txt", false);
  mg::fs::fs_exists("missing.txt", false);

  REQUIRE(capture.out.str().find("Exists: present.txt") != std::string::npos);
  REQUIRE(capture.out.str().find("Not found: missing.txt") != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs dry-run operations do not touch files", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-dry-run"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;
  write_test_file(temp.path / "keep.txt", "keep\n");

  REQUIRE(mg::fs::fs_write("created.txt", "new\n", true).has_value());
  REQUIRE(mg::fs::fs_remove("keep.txt", false, true).has_value());
  REQUIRE(mg::fs::fs_move("keep.txt", "moved.txt", true).has_value());

  REQUIRE_FALSE(std::filesystem::exists(temp.path / "created.txt"));
  REQUIRE(std::filesystem::exists(temp.path / "keep.txt"));
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "moved.txt"));
  REQUIRE(capture.out.str().find("[dry-run] Write 4 bytes to: created.txt")
          != std::string::npos);
  REQUIRE(capture.out.str().find("[dry-run] Remove: keep.txt")
          != std::string::npos);
  REQUIRE(capture.out.str().find("[dry-run] Move: keep.txt -> moved.txt")
          != std::string::npos);
  REQUIRE(capture.err.str().empty());
}

TEST_CASE("fs move reports missing source", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-move-missing"};
  auto capture = CapturedRuntime {};
  mg::current_runtime().fs_cwd = temp.path;

  const auto result = mg::fs::fs_move("missing.txt", "out.txt", false);

  REQUIRE_FALSE(result.has_value());
  REQUIRE(result.error() == mg::MgError::move_failed);
  REQUIRE(capture.err.str().find("Source not found: missing.txt")
          != std::string::npos);
  REQUIRE_FALSE(std::filesystem::exists(temp.path / "out.txt"));
}

TEST_CASE("run routes cwd option to fs commands", "[mg]")
{
  const auto temp = TemporaryDirectory {"fs-cwd-write"};
  auto capture = CapturedRuntime {};
  const auto cwd = temp.path.string();
  const auto args = std::vector<std::string_view> {
      "mg",
      "--cwd",
      cwd,
      "fs",
      "write",
      "today.txt",
      "hello from cwd",
  };

  const auto result = mg::run(args);

  REQUIRE(result.has_value());
  REQUIRE(std::filesystem::exists(temp.path / "today.txt"));
  REQUIRE(capture.err.str().empty());
}
