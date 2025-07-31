#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "log4cxx" for configuration ""
set_property(TARGET log4cxx APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(log4cxx PROPERTIES
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/liblog4cxx.15.5.0.dylib"
  IMPORTED_SONAME_NOCONFIG "@rpath/liblog4cxx.15.dylib"
  )

list(APPEND _cmake_import_check_targets log4cxx )
list(APPEND _cmake_import_check_files_for_log4cxx "${_IMPORT_PREFIX}/lib/liblog4cxx.15.5.0.dylib" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
