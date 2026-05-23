#pragma once

#include <span>
#include <string_view>

namespace mg::cli
{
[[nodiscard]] auto main_help_lines() noexcept -> std::span<const std::string_view>;
[[nodiscard]] auto fs_help_lines() noexcept -> std::span<const std::string_view>;
[[nodiscard]] auto version_line() -> std::string_view;

void print_help();
void print_fs_help();
void print_version();
}  // namespace mg::cli
