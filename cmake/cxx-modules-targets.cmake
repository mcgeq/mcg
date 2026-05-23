include_guard(GLOBAL)

add_library("${mg_modules_target}")
add_library("${mg_modules_alias}" ALIAS "${mg_modules_target}")
set_property(TARGET "${mg_modules_target}" PROPERTY EXPORT_NAME "modules")

target_sources(
    "${mg_modules_target}"
    PUBLIC
    FILE_SET cxx_modules TYPE CXX_MODULES
    BASE_DIRS
    "${PROJECT_SOURCE_DIR}/source/modules"
    FILES
    "${mg_module_interface_source}"
)

target_compile_features("${mg_modules_target}" PUBLIC cxx_std_23)
mg_apply_options("${mg_modules_target}")

if(mg_enable_clang_tidy AND mg_clang_tidy_profile STREQUAL "strict")
  mg_set_target_clang_tidy(
      "${mg_modules_target}"
      PROFILE recommended
      WARNINGS_AS_ERRORS OFF
  )
endif()

if(PROJECT_IS_TOP_LEVEL AND mg_build_cli)
  add_executable("${mg_modules_cli_target}" "${mg_module_cli_source}")
  add_executable("${mg_modules_cli_alias}" ALIAS "${mg_modules_cli_target}")

  set_property(
      TARGET "${mg_modules_cli_target}"
      PROPERTY
      OUTPUT_NAME
      "${MG_MODULES_CLI_OUTPUT_NAME}"
  )
  set_property(
      TARGET "${mg_modules_cli_target}"
      PROPERTY
      CXX_SCAN_FOR_MODULES
      ON
  )
  target_compile_features("${mg_modules_cli_target}" PRIVATE cxx_std_23)
  target_link_libraries(
      "${mg_modules_cli_target}" PRIVATE
      "${mg_modules_target}"
  )
  add_dependencies("${mg_modules_cli_target}" "${mg_modules_target}")
  mg_apply_options("${mg_modules_cli_target}")

  if(mg_enable_clang_tidy AND mg_clang_tidy_profile STREQUAL "strict")
    mg_set_target_clang_tidy(
        "${mg_modules_cli_target}"
        PROFILE recommended
        WARNINGS_AS_ERRORS OFF
    )
  endif()
endif()
