#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "foonathan_memory" for configuration ""
set_property(TARGET foonathan_memory APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(foonathan_memory PROPERTIES
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libfoonathan_memory-0.7.4.dylib"
  IMPORTED_SONAME_NOCONFIG "@rpath/libfoonathan_memory-0.7.4.dylib"
  )

list(APPEND _cmake_import_check_targets foonathan_memory )
list(APPEND _cmake_import_check_files_for_foonathan_memory "${_IMPORT_PREFIX}/lib/libfoonathan_memory-0.7.4.dylib" )

# Import target "foonathan_memory_node_size_debugger" for configuration ""
set_property(TARGET foonathan_memory_node_size_debugger APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(foonathan_memory_node_size_debugger PROPERTIES
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/bin/nodesize_dbg"
  )

list(APPEND _cmake_import_check_targets foonathan_memory_node_size_debugger )
list(APPEND _cmake_import_check_files_for_foonathan_memory_node_size_debugger "${_IMPORT_PREFIX}/bin/nodesize_dbg" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
