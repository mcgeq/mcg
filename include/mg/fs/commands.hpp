#pragma once

#include <expected>
#include <mg/core/error.hpp>

#include <span>
#include <string_view>

namespace mg::fs
{
[[nodiscard]] auto handle_command(std::string_view cmd,
                                  std::span<const std::string_view> args,
                                  bool dry_run) -> std::expected<void, MgError>;
}  // namespace mg::fs
