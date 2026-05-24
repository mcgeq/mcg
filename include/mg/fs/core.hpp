#pragma once

#include <expected>
#include <string_view>

#include <mg/core/error.hpp>

namespace mg::fs
{
[[nodiscard]] std::expected<void, MgError> fs_create_extended(
    std::string_view path, bool is_dir, bool recursive, bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_remove(std::string_view path,
                                                     bool recursive,
                                                     bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_remove_wildcard(
    std::string_view pattern, bool recursive, bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_copy_extended(
    std::string_view src, std::string_view dst, bool recursive, bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_move(std::string_view src,
                                                   std::string_view dst,
                                                   bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_list(std::string_view path,
                                                   bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_list_wildcard(
    std::string_view pattern, bool dry_run);
void fs_exists(std::string_view path, bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_read(std::string_view path,
                                                   bool dry_run);
[[nodiscard]] std::expected<void, MgError> fs_write(std::string_view path,
                                                    std::string_view content,
                                                    bool dry_run);
}  // namespace mg::fs
