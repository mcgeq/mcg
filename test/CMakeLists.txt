find_package(Catch2 3 CONFIG REQUIRED)
include(Catch)

add_executable("${mg_test_target}" "${mg_test_source}")
target_link_libraries(
    "${mg_test_target}" PRIVATE
    "${mg_main_target}"
    Catch2::Catch2WithMain
)
target_compile_features("${mg_test_target}" PRIVATE cxx_std_23)
mg_apply_options("${mg_test_target}")
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  target_compile_options("${mg_test_target}" PRIVATE -Wno-c2y-extensions)
endif()
if(mg_enable_clang_tidy AND mg_clang_tidy_profile STREQUAL "strict")
  mg_set_target_clang_tidy(
      "${mg_test_target}"
      PROFILE recommended
      WARNINGS_AS_ERRORS OFF
  )
endif()

catch_discover_tests("${mg_test_target}")

set(package_prefix "${PROJECT_BINARY_DIR}/package")

file(MAKE_DIRECTORY "${mg_package_source_dir}")
configure_file(
    "${PROJECT_SOURCE_DIR}/test/package/CMakeLists.txt.in"
    "${mg_package_source_dir}/CMakeLists.txt"
    @ONLY
)
configure_file(
    "${PROJECT_SOURCE_DIR}/test/package/main.cpp.in"
    "${mg_package_source_dir}/main.cpp"
    @ONLY
)
configure_file(
    "${PROJECT_SOURCE_DIR}/test/package/module_main.cpp.in"
    "${mg_package_source_dir}/module_main.cpp"
    @ONLY
)

add_test(
    NAME "${PROJECT_NAME}.install"
    COMMAND
    "${CMAKE_COMMAND}" --install "${PROJECT_BINARY_DIR}" --prefix
    "${package_prefix}"
)
set_tests_properties(
    "${PROJECT_NAME}.install"
    PROPERTIES
    FIXTURES_SETUP ProjectInstall
)

set(
    mg_package_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${mg_package_source_dir}"
    -B
    "${mg_package_build_dir}"
    --fresh
    -G
    "${CMAKE_GENERATOR}"
    -D
    "CMAKE_PREFIX_PATH=${package_prefix}"
)
if(CMAKE_GENERATOR_PLATFORM)
  list(APPEND mg_package_configure_command -A "${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
  list(APPEND mg_package_configure_command -T "${CMAKE_GENERATOR_TOOLSET}")
endif()
if(CMAKE_CONFIGURATION_TYPES)
  list(
      APPEND
      mg_package_configure_command
      -D
      "CMAKE_CONFIGURATION_TYPES=${CMAKE_CONFIGURATION_TYPES}"
  )
else()
  list(
      APPEND
      mg_package_configure_command
      -D
      "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
  )
  if(CMAKE_CXX_COMPILER)
    list(
        APPEND
        mg_package_configure_command
        -D
        "CMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
    )
  endif()
endif()

add_test(
    NAME "${PROJECT_NAME}.package.configure"
    COMMAND
    ${mg_package_configure_command}
)
set_tests_properties(
    "${PROJECT_NAME}.package.configure"
    PROPERTIES
    FIXTURES_REQUIRED ProjectInstall
    FIXTURES_SETUP ProjectPackageConfigured
)

add_test(
    NAME "${PROJECT_NAME}.package.build"
    COMMAND
    "${CMAKE_COMMAND}" --build "${mg_package_build_dir}"
)
set_tests_properties(
    "${PROJECT_NAME}.package.build"
    PROPERTIES
    FIXTURES_REQUIRED ProjectPackageConfigured
)

if(TARGET "${mg_cli_target}")
  set(
      real_smoke_scenarios_option
      "${mg_project_identifier}_REAL_SMOKE_SCENARIOS"
  )
  set(
      "${real_smoke_scenarios_option}"
      ""
      CACHE STRING
      "Semicolon-separated real package-manager smoke scenarios to run"
  )
  set(real_smoke_scenario_args "")
  if(NOT "${${real_smoke_scenarios_option}}" STREQUAL "")
    string(
        REPLACE
        ";"
        "\\;"
        real_smoke_scenarios_arg
        "${${real_smoke_scenarios_option}}"
    )
    list(
        APPEND
        real_smoke_scenario_args
        "-DREAL_SMOKE_SCENARIOS=${real_smoke_scenarios_arg}"
    )
  endif()

  add_test(
      NAME "${PROJECT_NAME}.cli.smoke"
      COMMAND
      "${CMAKE_COMMAND}"
      -D
      "MG_EXE=$<TARGET_FILE:${mg_cli_target}>"
      -D
      "SMOKE_ROOT=${PROJECT_BINARY_DIR}/mg-cli-smoke"
      -P
      "${PROJECT_SOURCE_DIR}/test/mg_cli_smoke.cmake"
  )

  add_custom_target(
      run-real-smoke
      COMMAND
      "${CMAKE_COMMAND}"
      -D
      "MG_EXE=$<TARGET_FILE:${mg_cli_target}>"
      -D
      "REAL_SMOKE_ROOT=${PROJECT_BINARY_DIR}/mg-cli-real-smoke"
      ${real_smoke_scenario_args}
      -P
      "${PROJECT_SOURCE_DIR}/test/mg_cli_real_smoke.cmake"
      COMMENT "Running real package-manager smoke scenarios"
      VERBATIM
  )
  add_dependencies(run-real-smoke "${mg_cli_target}")

  set(real_smoke_option "${mg_project_identifier}_ENABLE_REAL_SMOKE")
  option(
      "${real_smoke_option}"
      "Add real package-manager smoke scenarios to CTest"
      OFF
  )
  if(${real_smoke_option})
    add_test(
        NAME "${PROJECT_NAME}.cli.real-smoke"
        COMMAND
        "${CMAKE_COMMAND}"
        -D
        "MG_EXE=$<TARGET_FILE:${mg_cli_target}>"
        -D
        "REAL_SMOKE_ROOT=${PROJECT_BINARY_DIR}/mg-cli-real-smoke"
        ${real_smoke_scenario_args}
        -P
        "${PROJECT_SOURCE_DIR}/test/mg_cli_real_smoke.cmake"
    )
  endif()
endif()

add_folders(Test)
