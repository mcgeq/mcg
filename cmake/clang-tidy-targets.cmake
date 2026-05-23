include_guard(GLOBAL)

set(
    CLANG_TIDY_SOURCE_DIRECTORIES
    src
    include
    test
    CACHE STRING
    "; separated directories relative to the project source dir to analyze"
)
set(
    CLANG_TIDY_EXCLUDE_DIRECTORIES
    ""
    CACHE STRING
    "; separated directories relative to the project source dir to skip"
)

find_program(CLANG_TIDY_COMMAND NAMES clang-tidy)

if(NOT CLANG_TIDY_COMMAND)
  message(STATUS "clang-tidy not found; tidy-check target will not be generated")
  return()
endif()

add_custom_target(
    tidy-check
    COMMAND
    "${CMAKE_COMMAND}"
    -D "CLANG_TIDY_COMMAND=${CLANG_TIDY_COMMAND}"
    -D "CLANG_TIDY_CONFIG_FILE=${mg_clang_tidy_config_file}"
    -D "CLANG_TIDY_HEADER_FILTER=${mg_clang_tidy_header_filter}"
    -D "CLANG_TIDY_WARNINGS_AS_ERRORS=${mg_clang_tidy_warnings_as_errors}"
    -D "DIRECTORIES=${CLANG_TIDY_SOURCE_DIRECTORIES}"
    -D "EXCLUDE_DIRECTORIES=${CLANG_TIDY_EXCLUDE_DIRECTORIES}"
    -D "BUILD_DIR=${PROJECT_BINARY_DIR}"
    -P "${PROJECT_SOURCE_DIR}/cmake/run-clang-tidy.cmake"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Running clang-tidy across configured source directories"
    VERBATIM
)
