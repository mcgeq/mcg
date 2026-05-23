include_guard(GLOBAL)

include(GNUInstallDirs)

string(MAKE_C_IDENTIFIER "${PROJECT_NAME}" mg_project_identifier)

string(TOLOWER "${PROJECT_NAME}" mg_default_library_basename)
string(
    MAKE_C_IDENTIFIER
    "${mg_default_library_basename}"
    mg_default_library_basename
)

if(NOT DEFINED MG_INCLUDE_DIR_NAME)
  set(MG_INCLUDE_DIR_NAME "${PROJECT_NAME}")
endif()

if(NOT DEFINED MG_LIBRARY_BASENAME)
  set(MG_LIBRARY_BASENAME "${mg_default_library_basename}")
endif()

if(NOT DEFINED MG_LIBRARY_NAMESPACE)
  set(MG_LIBRARY_NAMESPACE "${MG_LIBRARY_BASENAME}")
endif()

set(mg_main_target "${PROJECT_NAME}")
set(mg_main_alias "${PROJECT_NAME}::${PROJECT_NAME}")
set(mg_cli_target "${PROJECT_NAME}_cli")
set(mg_cli_alias "${PROJECT_NAME}::cli")
set(mg_modules_target "${PROJECT_NAME}_modules")
set(mg_modules_alias "${PROJECT_NAME}::modules")
set(mg_modules_cli_target "${PROJECT_NAME}_modules_cli")
set(mg_modules_cli_alias "${PROJECT_NAME}::modules_cli")
set(mg_test_target "${PROJECT_NAME}_test")
set(mg_benchmark_target "${PROJECT_NAME}_benchmark")
set(mg_fuzz_target "${PROJECT_NAME}_fuzz")
set(mg_export_name "${PROJECT_NAME}Targets")
set(mg_package_namespace "${PROJECT_NAME}::")
set(mg_config_file "${PROJECT_NAME}Config.cmake")
set(mg_config_version_file "${PROJECT_NAME}ConfigVersion.cmake")
set(mg_package_install_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")

set(mg_generated_include_dir "${PROJECT_BINARY_DIR}/generated/include")
set(
    mg_public_header
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/${MG_LIBRARY_BASENAME}.hpp"
)
set(
    mg_public_headers
    "${mg_public_header}"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/app.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/cli/help.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/cli/parser.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/core/config.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/core/error.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/core/logger.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/core/project_info.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/core/runtime.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/core/types.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/fs/commands.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/fs/core.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/pkgm/core.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/pkgm/detect.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/pkgm/executor.hpp"
    "${PROJECT_SOURCE_DIR}/include/${MG_INCLUDE_DIR_NAME}/pkgm/registry.hpp"
)
set(
    mg_library_source
    "${PROJECT_SOURCE_DIR}/src/${MG_LIBRARY_BASENAME}.cpp"
)
set(mg_module_name "${MG_LIBRARY_BASENAME}")
set(
    mg_library_sources
    "${mg_library_source}"
    "${PROJECT_SOURCE_DIR}/src/app.cpp"
    "${PROJECT_SOURCE_DIR}/src/cli/help.cpp"
    "${PROJECT_SOURCE_DIR}/src/cli/parser.cpp"
    "${PROJECT_SOURCE_DIR}/src/core/config.cpp"
    "${PROJECT_SOURCE_DIR}/src/core/error.cpp"
    "${PROJECT_SOURCE_DIR}/src/core/logger.cpp"
    "${PROJECT_SOURCE_DIR}/src/core/runtime.cpp"
    "${PROJECT_SOURCE_DIR}/src/core/types.cpp"
    "${PROJECT_SOURCE_DIR}/src/fs/commands.cpp"
    "${PROJECT_SOURCE_DIR}/src/fs/core.cpp"
    "${PROJECT_SOURCE_DIR}/src/pkgm/core.cpp"
    "${PROJECT_SOURCE_DIR}/src/pkgm/detect.cpp"
    "${PROJECT_SOURCE_DIR}/src/pkgm/executor.cpp"
    "${PROJECT_SOURCE_DIR}/src/pkgm/registry.cpp"
)
set(mg_private_headers "")
set(
    mg_module_interface_source
    "${PROJECT_SOURCE_DIR}/source/modules/${mg_module_name}.ixx"
)
set(
    mg_module_cli_source
    "${PROJECT_SOURCE_DIR}/src/main_modules.cpp"
)
set(
    mg_test_source
    "${PROJECT_SOURCE_DIR}/test/src/${MG_LIBRARY_BASENAME}_test.cpp"
)
set(
    mg_benchmark_source
    "${PROJECT_SOURCE_DIR}/benchmark/src/${MG_LIBRARY_BASENAME}_benchmark.cpp"
)
set(
    mg_fuzz_source
    "${PROJECT_SOURCE_DIR}/fuzz/src/${MG_LIBRARY_BASENAME}_fuzz.cpp"
)
set(mg_package_source_dir "${PROJECT_BINARY_DIR}/package-smoke-src")
set(mg_package_build_dir "${PROJECT_BINARY_DIR}/package-smoke")
set(
    mg_package_test_target
    "${MG_LIBRARY_BASENAME}_package_smoke_test"
)
set(
    mg_package_module_test_target
    "${MG_LIBRARY_BASENAME}_package_module_smoke_test"
)
