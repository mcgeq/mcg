#pragma once

#include <expected>
#include <span>
#include <string_view>

#include <mg/core/error.hpp>

namespace mg::fs
{
[[nodiscard]] std::expected<void, MgError> handle_command(
    std::string_view cmd, std::span<const std::string_view> args, bool dry_run);
}  // namespace mg::fs
