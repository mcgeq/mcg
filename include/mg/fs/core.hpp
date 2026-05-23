#pragma once

#include <expected>
#include <mg/core/error.hpp>

#include <string_view>

namespace mg::fs
{
[[nodiscard]] auto fs_create_extended(std::string_view path,
                                      bool is_dir,
                                      bool recursive,
                                      bool dry_run) -> std::expected<void, MgError>;
[[nodiscard]] auto fs_remove(std::string_view path, bool recursive, bool dry_run)
    -> std::expected<void, MgError>;
[[nodiscard]] auto fs_remove_wildcard(std::string_view pattern,
                                      bool recursive,
                                      bool dry_run) -> std::expected<void, MgError>;
[[nodiscard]] auto fs_copy_extended(std::string_view src,
                                    std::string_view dst,
                                    bool recursive,
                                    bool dry_run) -> std::expected<void, MgError>;
[[nodiscard]] auto fs_move(std::string_view src, std::string_view dst, bool dry_run)
    -> std::expected<void, MgError>;
[[nodiscard]] auto fs_list(std::string_view path, bool dry_run)
    -> std::expected<void, MgError>;
[[nodiscard]] auto fs_list_wildcard(std::string_view pattern, bool dry_run)
    -> std::expected<void, MgError>;
void fs_exists(std::string_view path, bool dry_run);
[[nodiscard]] auto fs_read(std::string_view path, bool dry_run)
    -> std::expected<void, MgError>;
[[nodiscard]] auto fs_write(std::string_view path,
                            std::string_view content,
                            bool dry_run) -> std::expected<void, MgError>;
}  // namespace mg::fs
