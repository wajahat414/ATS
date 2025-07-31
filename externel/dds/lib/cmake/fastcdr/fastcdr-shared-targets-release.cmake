#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "fastcdr" for configuration "Release"
set_property(TARGET fastcdr APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(fastcdr PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libfastcdr.2.3.0.dylib"
  IMPORTED_SONAME_RELEASE "@rpath/libfastcdr.2.dylib"
  )

list(APPEND _cmake_import_check_targets fastcdr )
list(APPEND _cmake_import_check_files_for_fastcdr "${_IMPORT_PREFIX}/lib/libfastcdr.2.3.0.dylib" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
