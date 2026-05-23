cmake_minimum_required(VERSION 3.25)

include(cmake/prelude.cmake)

project(
    mg
    VERSION 0.1.0
    DESCRIPTION "A cross-ecosystem package manager CLI"
    HOMEPAGE_URL "https://www.gemc.club"
    LANGUAGES CXX
)

# Project naming settings. The shipped command-line executable stays `mg`.
set(MG_INCLUDE_DIR_NAME "mg")
set(MG_LIBRARY_BASENAME "mg")
set(MG_LIBRARY_NAMESPACE "mg")
set(MG_CLI_OUTPUT_NAME "mg")
set(MG_MODULES_CLI_OUTPUT_NAME "mg-modules")

include(cmake/project-metadata.cmake)
include(cmake/dependencies.cmake)
include(cmake/variables.cmake)
include(cmake/project-options.cmake)

if(CMAKE_EXPORT_COMPILE_COMMANDS)
  add_custom_target(
      sync-compile-commands ALL
      COMMAND
      "${CMAKE_COMMAND}"
      -D
      "MG_BINARY_COMPILE_COMMANDS=${PROJECT_BINARY_DIR}/compile_commands.json"
      -D
      "MG_ROOT_COMPILE_COMMANDS=${PROJECT_SOURCE_DIR}/compile_commands.json"
      -P
      "${PROJECT_SOURCE_DIR}/cmake/sync-compile-commands.cmake"
      COMMENT "Syncing compile_commands.json for clangd-based editors"
      VERBATIM
  )
endif()

configure_file(
    "${PROJECT_SOURCE_DIR}/cmake/project-config.hpp.in"
    "${mg_generated_include_dir}/${MG_INCLUDE_DIR_NAME}/project_config.hpp"
    @ONLY
)

add_library("${mg_main_target}")
add_library("${mg_main_alias}" ALIAS "${mg_main_target}")

target_sources(
    "${mg_main_target}"
    PRIVATE
    ${mg_library_sources}
    ${mg_private_headers}
    PUBLIC
    FILE_SET HEADERS
    BASE_DIRS
    "${PROJECT_SOURCE_DIR}/include"
    "${mg_generated_include_dir}"
    FILES
    ${mg_public_headers}
    "${mg_generated_include_dir}/${MG_INCLUDE_DIR_NAME}/project_config.hpp"
)

target_include_directories(
    "${mg_main_target}" ${warning_guard}
    PUBLIC
    "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>"
    "$<BUILD_INTERFACE:${mg_generated_include_dir}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
    PRIVATE
    "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
)

target_compile_features("${mg_main_target}" PUBLIC cxx_std_23)
mg_apply_options("${mg_main_target}")

set(mg_build_cli_option "${mg_project_identifier}_BUILD_CLI")
option(
    "${mg_build_cli_option}"
    "Build the example command-line executable"
    ${PROJECT_IS_TOP_LEVEL}
)
set(mg_build_cli "${${mg_build_cli_option}}")

if(mg_enable_cxx_modules)
  include(cmake/cxx-modules-targets.cmake)
endif()

if(mg_build_cli)
  add_executable("${mg_cli_target}" src/main.cpp)
  add_executable("${mg_cli_alias}" ALIAS "${mg_cli_target}")

  set_property(TARGET "${mg_cli_target}" PROPERTY OUTPUT_NAME "${MG_CLI_OUTPUT_NAME}")
  target_compile_features("${mg_cli_target}" PRIVATE cxx_std_23)
  target_link_libraries("${mg_cli_target}" PRIVATE "${mg_main_target}")
  mg_apply_options("${mg_cli_target}")
  if(mg_enable_clang_tidy AND mg_clang_tidy_profile STREQUAL "strict")
    mg_set_target_clang_tidy(
        "${mg_cli_target}"
        PROFILE recommended
        WARNINGS_AS_ERRORS OFF
    )
  endif()
endif()

if(NOT CMAKE_SKIP_INSTALL_RULES)
  include(cmake/install-rules.cmake)
endif()

if(NOT mg_developer_mode)
  return()
elseif(NOT PROJECT_IS_TOP_LEVEL)
  message(
      AUTHOR_WARNING
      "Developer mode is intended for developers of ${PROJECT_NAME}"
  )
endif()

include(cmake/dev-mode.cmake)
