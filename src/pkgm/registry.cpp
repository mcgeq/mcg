#include <string>

#include <mg/pkgm/registry.hpp>

namespace mg::pkgm
{
namespace
{
enum class ActionKind
{
  add,
  remove,
  upgrade,
  install,
  list,
};

void append_all(std::vector<std::string>& argv,
                const std::vector<std::string>& values)
{
  argv.insert(argv.end(), values.begin(), values.end());
}

void append_arg(std::vector<std::string>& argv, std::string_view value)
{
  argv.emplace_back(value);
}

[[nodiscard]] bool is_dev_profile(std::string_view profile) noexcept
{
  return profile == "dev";
}

void append_all_effective_profiles(std::vector<std::string>& argv,
                                   std::string_view flag,
                                   const PackageOptions& options)
{
  for (auto index = std::size_t {0}; index < options.effective_profile_count();
       ++index)
  {
    if (auto profile = options.effective_profile_at(index)) {
      append_arg(argv, flag);
      append_arg(argv, *profile);
    }
  }
}

void append_uv_target_profile_selection(std::vector<std::string>& argv,
                                        const PackageOptions& options)
{
  if (auto profile = options.target_profile()) {
    if (is_dev_profile(*profile) && !options.has_explicit_profile("dev")) {
      if (options.dev) {
        append_arg(argv, "--dev");
      }
      return;
    }

    if (options.dev && !is_dev_profile(*profile)) {
      append_arg(argv, "--dev");
    }
    append_arg(argv, "--group");
    append_arg(argv, *profile);
    return;
  }

  if (options.dev) {
    append_arg(argv, "--dev");
  }
}

void append_pdm_target_profile_selection(std::vector<std::string>& argv,
                                         const PackageOptions& options)
{
  if (auto profile = options.target_profile()) {
    if (is_dev_profile(*profile)) {
      append_arg(argv, "--dev");
      return;
    }

    if (options.dev) {
      append_arg(argv, "--dev");
    }
    append_arg(argv, "--group");
    append_arg(argv, *profile);
    return;
  }

  if (options.dev) {
    append_arg(argv, "--dev");
  }
}

void append_pdm_effective_profile_selection(std::vector<std::string>& argv,
                                            const PackageOptions& options)
{
  auto include_dev = options.dev;
  for (auto index = std::size_t {0}; index < options.profile_count(); ++index) {
    if (auto profile = options.profile_at(index);
        profile && is_dev_profile(*profile))
    {
      include_dev = true;
    }
  }

  if (include_dev) {
    append_arg(argv, "--dev");
  }

  for (auto index = std::size_t {0}; index < options.profile_count(); ++index) {
    const auto profile = options.profile_at(index);
    if (!profile || is_dev_profile(*profile)) {
      continue;
    }

    append_arg(argv, "--group");
    append_arg(argv, *profile);
  }
}

void append_option_args(std::vector<std::string>& argv,
                        ManagerType manager,
                        ActionKind action_kind,
                        const PackageOptions& options)
{
  switch (action_kind) {
    case ActionKind::add:
      switch (manager) {
        case ManagerType::cargo:
          if (options.dev) {
            append_arg(argv, "--dev");
          }
          break;
        case ManagerType::npm:
        case ManagerType::pnpm:
          if (options.dev) {
            append_arg(argv, "--save-dev");
          }
          break;
        case ManagerType::bun:
        case ManagerType::yarn:
          if (options.dev) {
            append_arg(argv, "--dev");
          }
          break;
        case ManagerType::uv:
          append_uv_target_profile_selection(argv, options);
          break;
        case ManagerType::poetry:
          if (auto profile = options.target_profile()) {
            append_arg(argv, "--group");
            append_arg(argv, *profile);
          }
          break;
        case ManagerType::pdm:
          append_pdm_target_profile_selection(argv, options);
          break;
        case ManagerType::pip:
          break;
      }
      break;
    case ActionKind::remove:
      switch (manager) {
        case ManagerType::cargo:
          if (options.dev) {
            append_arg(argv, "--dev");
          }
          break;
        case ManagerType::npm:
        case ManagerType::pnpm:
          if (options.dev) {
            append_arg(argv, "--save-dev");
          }
          break;
        case ManagerType::uv:
          append_uv_target_profile_selection(argv, options);
          break;
        case ManagerType::poetry:
          if (auto profile = options.target_profile()) {
            append_arg(argv, "--group");
            append_arg(argv, *profile);
          }
          break;
        case ManagerType::pdm:
          append_pdm_target_profile_selection(argv, options);
          break;
        case ManagerType::bun:
        case ManagerType::yarn:
        case ManagerType::pip:
          break;
      }
      break;
    case ActionKind::upgrade:
      if (manager == ManagerType::uv) {
        append_all_effective_profiles(argv, "--group", options);
      } else if (manager == ManagerType::pdm) {
        append_pdm_effective_profile_selection(argv, options);
      }
      break;
    case ActionKind::install:
      if (manager == ManagerType::uv) {
        append_all_effective_profiles(argv, "--group", options);
      } else if (manager == ManagerType::poetry) {
        append_all_effective_profiles(argv, "--with", options);
      } else if (manager == ManagerType::pdm) {
        append_pdm_effective_profile_selection(argv, options);
      }
      break;
    case ActionKind::list:
      if (manager == ManagerType::uv) {
        append_all_effective_profiles(argv, "--group", options);
      } else if (manager == ManagerType::pdm) {
        append_pdm_effective_profile_selection(argv, options);
      }
      break;
  }
}
}  // namespace

std::string_view get_manager_name(ManagerType manager) noexcept
{
  return manager_name(manager);
}

bool append_command_args(std::vector<std::string>& argv,
                         ManagerType manager,
                         std::string_view action,
                         const CommandArgs& command_args,
                         const PackageOptions& options)
{
  const auto& packages = command_args.packages;
  const auto& manager_args = command_args.manager_args;

  if (is_exec_action(action)) {
    if (manager_args.empty()) {
      return false;
    }
    append_all(argv, manager_args);
    return true;
  }

  if (is_run_action(action)) {
    switch (manager) {
      case ManagerType::cargo:
      case ManagerType::npm:
      case ManagerType::pnpm:
      case ManagerType::bun:
      case ManagerType::yarn:
      case ManagerType::uv:
      case ManagerType::poetry:
      case ManagerType::pdm:
        append_arg(argv, "run");
        break;
      case ManagerType::pip:
        return false;
    }
    if (packages.empty()) {
      return false;
    }
    append_all(argv, packages);
    if (!manager_args.empty()
        && (manager == ManagerType::npm || manager == ManagerType::pnpm))
    {
      append_arg(argv, "--");
    }
    append_all(argv, manager_args);
    return true;
  }

  if (is_add_action(action)) {
    switch (manager) {
      case ManagerType::cargo:
      case ManagerType::pnpm:
      case ManagerType::bun:
      case ManagerType::yarn:
      case ManagerType::uv:
      case ManagerType::poetry:
      case ManagerType::pdm:
        append_arg(argv, "add");
        break;
      case ManagerType::npm:
      case ManagerType::pip:
        append_arg(argv, "install");
        break;
    }
    append_option_args(argv, manager, ActionKind::add, options);
    if (packages.empty() && manager_args.empty()) {
      return false;
    }
    append_all(argv, packages);
    append_all(argv, manager_args);
    return true;
  }

  if (is_remove_action(action)) {
    switch (manager) {
      case ManagerType::cargo:
      case ManagerType::pnpm:
      case ManagerType::bun:
      case ManagerType::yarn:
      case ManagerType::uv:
      case ManagerType::poetry:
      case ManagerType::pdm:
        append_arg(argv, "remove");
        break;
      case ManagerType::npm:
      case ManagerType::pip:
        append_arg(argv, "uninstall");
        break;
    }
    append_option_args(argv, manager, ActionKind::remove, options);
    if (packages.empty() && manager_args.empty()) {
      return false;
    }
    append_all(argv, packages);
    append_all(argv, manager_args);
    return true;
  }

  if (is_upgrade_action(action)) {
    switch (manager) {
      case ManagerType::cargo:
      case ManagerType::npm:
      case ManagerType::pnpm:
      case ManagerType::bun:
        append_arg(argv, "update");
        break;
      case ManagerType::yarn:
        append_arg(argv, "up");
        break;
      case ManagerType::pip:
        append_arg(argv, "install");
        append_arg(argv, "--upgrade");
        break;
      case ManagerType::uv:
        append_arg(argv, "sync");
        append_option_args(argv, manager, ActionKind::upgrade, options);
        if (packages.empty()) {
          append_arg(argv, "--upgrade");
        } else {
          for (const auto& package : packages) {
            append_arg(argv, "--upgrade-package");
            append_arg(argv, package);
          }
        }
        append_all(argv, manager_args);
        return true;
      case ManagerType::poetry:
      case ManagerType::pdm:
        append_arg(argv, "update");
        break;
    }
    append_option_args(argv, manager, ActionKind::upgrade, options);
    if (packages.empty() && manager_args.empty() && manager == ManagerType::pip)
    {
      return false;
    }
    append_all(argv, packages);
    append_all(argv, manager_args);
    return true;
  }

  if (is_install_action(action)) {
    switch (manager) {
      case ManagerType::cargo:
        append_arg(argv, "check");
        break;
      case ManagerType::npm:
      case ManagerType::pnpm:
      case ManagerType::bun:
      case ManagerType::yarn:
      case ManagerType::pip:
      case ManagerType::poetry:
      case ManagerType::pdm:
        append_arg(argv, "install");
        break;
      case ManagerType::uv:
        append_arg(argv, "sync");
        break;
    }
    append_option_args(argv, manager, ActionKind::install, options);
    append_all(argv, packages);
    append_all(argv, manager_args);
    return true;
  }

  if (is_list_action(action)) {
    switch (manager) {
      case ManagerType::cargo:
      case ManagerType::uv:
        append_arg(argv, "tree");
        break;
      case ManagerType::npm:
      case ManagerType::pnpm:
      case ManagerType::bun:
      case ManagerType::yarn:
      case ManagerType::pip:
      case ManagerType::pdm:
        append_arg(argv, "list");
        break;
      case ManagerType::poetry:
        append_arg(argv, "show");
        break;
    }
    append_option_args(argv, manager, ActionKind::list, options);
    append_all(argv, packages);
    append_all(argv, manager_args);
    return true;
  }

  return false;
}

bool action_requires_packages(std::string_view action) noexcept
{
  return is_add_action(action) || is_remove_action(action);
}

bool action_requires_run_target(std::string_view action) noexcept
{
  return is_run_action(action);
}

bool is_add_action(std::string_view action) noexcept
{
  return iequals(action, "add") || iequals(action, "a");
}

bool is_remove_action(std::string_view action) noexcept
{
  return iequals(action, "remove") || iequals(action, "rm")
      || iequals(action, "r");
}

bool is_upgrade_action(std::string_view action) noexcept
{
  return iequals(action, "upgrade") || iequals(action, "update")
      || iequals(action, "u");
}

bool is_install_action(std::string_view action) noexcept
{
  return iequals(action, "install") || iequals(action, "i");
}

bool is_list_action(std::string_view action) noexcept
{
  return iequals(action, "list") || iequals(action, "analyze")
      || iequals(action, "l");
}

bool is_exec_action(std::string_view action) noexcept
{
  return iequals(action, "exec") || iequals(action, "x");
}

bool is_run_action(std::string_view action) noexcept
{
  return iequals(action, "run");
}
}  // namespace mg::pkgm
