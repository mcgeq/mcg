#pragma once

#include <string_view>

#include <mg/project_config.hpp>

namespace mg
{
[[nodiscard]] constexpr std::string_view project_name() noexcept
{
  return k_project_name;
}

[[nodiscard]] constexpr std::string_view project_version() noexcept
{
  return k_project_version;
}
}  // namespace mg
