#pragma once

#include <span>
#include <string_view>

namespace mg::cli
{
[[nodiscard]] std::span<const std::string_view> main_help_lines() noexcept;
[[nodiscard]] std::span<const std::string_view> fs_help_lines() noexcept;
[[nodiscard]] std::string_view version_line();

void print_help();
void print_fs_help();
void print_version();
}  // namespace mg::cli
