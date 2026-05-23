if(NOT DEFINED MG_BINARY_COMPILE_COMMANDS)
  message(FATAL_ERROR "MG_BINARY_COMPILE_COMMANDS is required")
endif()

if(NOT DEFINED MG_ROOT_COMPILE_COMMANDS)
  message(FATAL_ERROR "MG_ROOT_COMPILE_COMMANDS is required")
endif()

if(NOT EXISTS "${MG_BINARY_COMPILE_COMMANDS}")
  message(
      STATUS
      "Skipping compile_commands sync because '${MG_BINARY_COMPILE_COMMANDS}' does not exist yet."
  )
  return()
endif()

execute_process(
    COMMAND
    "${CMAKE_COMMAND}" -E copy_if_different
    "${MG_BINARY_COMPILE_COMMANDS}"
    "${MG_ROOT_COMPILE_COMMANDS}"
    RESULT_VARIABLE mg_sync_result
)

if(NOT mg_sync_result EQUAL 0)
  message(
      FATAL_ERROR
      "Failed to sync compile_commands.json to '${MG_ROOT_COMPILE_COMMANDS}'."
  )
endif()
