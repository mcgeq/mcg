include(cmake/folders.cmake)

include(CTest)
if(BUILD_TESTING)
  add_subdirectory(test)
endif()

set(mg_build_benchmarks_option "${mg_project_identifier}_BUILD_BENCHMARKS")
option(
    "${mg_build_benchmarks_option}"
    "Build benchmark targets for local performance regression tracking"
    OFF
)
set(mg_build_benchmarks "${${mg_build_benchmarks_option}}")
if(mg_build_benchmarks)
  add_subdirectory(benchmark)
endif()

set(mg_build_fuzz_tests_option "${mg_project_identifier}_BUILD_FUZZ_TESTS")
option(
    "${mg_build_fuzz_tests_option}"
    "Build libFuzzer-based fuzz targets for parser and API hardening"
    OFF
)
set(mg_build_fuzz_tests "${${mg_build_fuzz_tests_option}}")
if(mg_build_fuzz_tests)
  add_subdirectory(fuzz)
endif()

if(TARGET "${mg_cli_target}")
  add_custom_target(
      run-exe
      COMMAND "${mg_cli_target}"
      VERBATIM
  )
  add_dependencies(run-exe "${mg_cli_target}")
endif()

if(TARGET "${mg_modules_cli_target}")
  add_custom_target(
      run-modules-exe
      COMMAND "${mg_modules_cli_target}"
      VERBATIM
  )
  add_dependencies(run-modules-exe "${mg_modules_cli_target}")
endif()

option(BUILD_MCSS_DOCS "Build documentation using Doxygen and m.css" OFF)
if(BUILD_MCSS_DOCS)
  include(cmake/docs.cmake)
endif()

if(ENABLE_COVERAGE)
  include(cmake/coverage.cmake)
endif()

include(cmake/lint-targets.cmake)
include(cmake/clang-tidy-targets.cmake)
include(cmake/spell-targets.cmake)

add_folders(Project)
