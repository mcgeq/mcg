cmake_minimum_required(VERSION 3.14)

macro(default name)
  if(NOT DEFINED "${name}")
    set("${name}" "${ARGN}")
  endif()
endmacro()

default(DIRECTORIES src include test)
default(EXCLUDE_DIRECTORIES "")
default(BUILD_DIR "${CMAKE_BINARY_DIR}")
default(CLANG_TIDY_CONFIG_FILE "")
default(CLANG_TIDY_HEADER_FILTER "^${CMAKE_SOURCE_DIR}/(include|src|test)/")
default(CLANG_TIDY_WARNINGS_AS_ERRORS OFF)

if(NOT DEFINED CLANG_TIDY_COMMAND)
  set(CLANG_TIDY_COMMAND clang-tidy)
endif()

set(compile_commands "${BUILD_DIR}/compile_commands.json")
if(NOT EXISTS "${compile_commands}")
  message(
      FATAL_ERROR
      "Missing compile_commands.json in '${BUILD_DIR}'. Configure with "
      "CMAKE_EXPORT_COMPILE_COMMANDS=ON before running tidy-check."
  )
endif()

set(files "")
foreach(directory IN LISTS DIRECTORIES)
  foreach(
      extension
      IN ITEMS
      *.c
      *.cc
      *.cpp
      *.cxx
  )
    file(
        GLOB_RECURSE matched_files
        LIST_DIRECTORIES false
        "${CMAKE_SOURCE_DIR}/${directory}/${extension}"
    )
    list(APPEND files ${matched_files})
  endforeach()
endforeach()

list(REMOVE_DUPLICATES files)

if(files STREQUAL "")
  message(STATUS "No source files matched tidy-check directories")
  return()
endif()

set(filtered_files "")
foreach(file IN LISTS files)
  file(RELATIVE_PATH relative_file "${CMAKE_SOURCE_DIR}" "${file}")
  string(REPLACE "\\" "/" relative_file "${relative_file}")
  set(excluded OFF)
  foreach(directory IN LISTS EXCLUDE_DIRECTORIES)
    if(directory STREQUAL "")
      continue()
    endif()

    string(REPLACE "\\" "/" directory "${directory}")
    string(REGEX REPLACE "/+$" "" normalized_directory "${directory}")
    string(
        REGEX REPLACE
        "([][+.*()^$?{}|\\\\])"
        "\\\\\\1"
        normalized_directory_regex
        "${normalized_directory}"
    )
    if(relative_file STREQUAL "${normalized_directory}"
       OR relative_file MATCHES "^${normalized_directory_regex}/")
      set(excluded ON)
      break()
    endif()
  endforeach()

  if(NOT excluded)
    list(APPEND filtered_files "${file}")
  endif()
endforeach()

if(filtered_files STREQUAL "")
  message(STATUS "No source files remained after applying clang-tidy exclusions")
  return()
endif()

foreach(file IN LISTS filtered_files)
  set(
      command
      "${CLANG_TIDY_COMMAND}"
      -p
      "${BUILD_DIR}"
      "--header-filter=${CLANG_TIDY_HEADER_FILTER}"
  )
  if(NOT CLANG_TIDY_CONFIG_FILE STREQUAL "")
    list(APPEND command "--config-file=${CLANG_TIDY_CONFIG_FILE}")
  endif()
  if(CLANG_TIDY_WARNINGS_AS_ERRORS)
    list(APPEND command "--warnings-as-errors=*")
  endif()
  list(APPEND command "${file}")

  execute_process(
      COMMAND ${command}
      WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
      RESULT_VARIABLE result
  )
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "'${file}': clang-tidy returned with ${result}")
  endif()
endforeach()
