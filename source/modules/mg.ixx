module;

#include <string_view>

export module mg;

export namespace mg
{
inline constexpr std::string_view k_project_name {"mg"};
inline constexpr std::string_view k_project_version {"0.1.0"};
inline constexpr int k_project_version_major {0};
inline constexpr int k_project_version_minor {1};
inline constexpr int k_project_version_patch {0};

[[nodiscard]] constexpr std::string_view project_name() noexcept
{
  return k_project_name;
}

[[nodiscard]] constexpr std::string_view project_version() noexcept
{
  return k_project_version;
}
}  // namespace mg
