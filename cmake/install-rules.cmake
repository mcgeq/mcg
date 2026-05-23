include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(
    TARGETS "${mg_main_target}"
    EXPORT "${mg_export_name}"
    RUNTIME COMPONENT "${PROJECT_NAME}_Runtime"
    LIBRARY COMPONENT "${PROJECT_NAME}_Runtime"
    ARCHIVE COMPONENT "${PROJECT_NAME}_Development"
    FILE_SET HEADERS COMPONENT "${PROJECT_NAME}_Development"
)

if(TARGET "${mg_modules_target}")
  install(
      TARGETS "${mg_modules_target}"
      EXPORT "${mg_export_name}"
      RUNTIME COMPONENT "${PROJECT_NAME}_Runtime"
      LIBRARY COMPONENT "${PROJECT_NAME}_Runtime"
      ARCHIVE COMPONENT "${PROJECT_NAME}_Development"
      FILE_SET cxx_modules DESTINATION
      "${CMAKE_INSTALL_INCLUDEDIR}/${MG_INCLUDE_DIR_NAME}/modules"
      COMPONENT "${PROJECT_NAME}_Development"
      CXX_MODULES_BMI DESTINATION ""
  )
endif()

if(TARGET "${mg_cli_target}")
  install(
      TARGETS "${mg_cli_target}"
      RUNTIME COMPONENT "${PROJECT_NAME}_Runtime"
  )
endif()

write_basic_package_version_file(
    "${PROJECT_BINARY_DIR}/${mg_config_version_file}"
    VERSION "${PROJECT_VERSION}"
    COMPATIBILITY SameMajorVersion
)

set(mg_package_dependency_block "")
foreach(mg_dependency_snippet IN LISTS mg_package_dependency_find_snippets)
  string(APPEND mg_package_dependency_block "${mg_dependency_snippet}\n")
endforeach()

configure_package_config_file(
    "${PROJECT_SOURCE_DIR}/cmake/project-config.cmake.in"
    "${PROJECT_BINARY_DIR}/${mg_config_file}"
    INSTALL_DESTINATION "${mg_package_install_dir}"
)

if(TARGET "${mg_modules_target}")
  install(
      EXPORT "${mg_export_name}"
      NAMESPACE "${mg_package_namespace}"
      DESTINATION "${mg_package_install_dir}"
      FILE "${mg_export_name}.cmake"
      CXX_MODULES_DIRECTORY modules
      COMPONENT "${PROJECT_NAME}_Development"
  )
else()
  install(
      EXPORT "${mg_export_name}"
      NAMESPACE "${mg_package_namespace}"
      DESTINATION "${mg_package_install_dir}"
      FILE "${mg_export_name}.cmake"
      COMPONENT "${PROJECT_NAME}_Development"
  )
endif()

install(
    FILES
    "${PROJECT_BINARY_DIR}/${mg_config_file}"
    "${PROJECT_BINARY_DIR}/${mg_config_version_file}"
    DESTINATION "${mg_package_install_dir}"
    COMPONENT "${PROJECT_NAME}_Development"
)

if(PROJECT_IS_TOP_LEVEL)
  include(CPack)
endif()
