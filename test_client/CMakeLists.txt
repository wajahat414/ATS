# CMakeLists.txt - Updated version with TypeObjectSupport files
cmake_minimum_required(VERSION 3.16)
project(TestNewOrderClient)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fix the typo: external not externel
set(DDS_HOME "${CMAKE_CURRENT_SOURCE_DIR}/../externel/dds")
message(STATUS "Using DDS_HOME: ${DDS_HOME}")

# Verify DDS installation
if(NOT EXISTS "${DDS_HOME}/include/fastdds")
    message(FATAL_ERROR "FastDDS not found at ${DDS_HOME}. Please check your DDS installation.")
endif()

# Include directories
include_directories(
    ${DDS_HOME}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../GenTools/idl
    ${CMAKE_CURRENT_SOURCE_DIR}/../Common
)

# Link directories
link_directories(
    ${DDS_HOME}/lib
)

# Include ALL required files including TypeObjectSupport
set(REQUIRED_IDL_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/../GenTools/idl/NewOrderSinglePubSubTypes.cxx"
    "${CMAKE_CURRENT_SOURCE_DIR}/../GenTools/idl/HeaderPubSubTypes.cxx"
    "${CMAKE_CURRENT_SOURCE_DIR}/../GenTools/idl/NewOrderSingleTypeObjectSupport.cxx"
    "${CMAKE_CURRENT_SOURCE_DIR}/../GenTools/idl/HeaderTypeObjectSupport.cxx"
)

# Check if required files exist
foreach(source_file ${REQUIRED_IDL_SOURCES})
    if(NOT EXISTS ${source_file})
        message(WARNING "Required IDL source file not found: ${source_file}")
    else()
        message(STATUS "Found: ${source_file}")
    endif()
endforeach()

# Filter out missing files
set(AVAILABLE_IDL_SOURCES)
foreach(source_file ${REQUIRED_IDL_SOURCES})
    if(EXISTS ${source_file})
        list(APPEND AVAILABLE_IDL_SOURCES ${source_file})
    endif()
endforeach()

message(STATUS "Using available IDL sources:")
foreach(source_file ${AVAILABLE_IDL_SOURCES})
    message(STATUS "  - ${source_file}")
endforeach()

# Create test executable with available sources
add_executable(test_new_order 
    discovery_test.cpp
    ${AVAILABLE_IDL_SOURCES}
)



# Link libraries
target_link_libraries(test_new_order
    fastdds
    fastcdr
    pthread
)

# For macOS, set runtime library paths
if(APPLE)
    set_target_properties(test_new_order PROPERTIES
        INSTALL_RPATH "${DDS_HOME}/lib"
        BUILD_WITH_INSTALL_RPATH TRUE
        BUILD_RPATH "${DDS_HOME}/lib"
    )
endif()


# Print build information
message(STATUS "====================================")
message(STATUS "Test Client Build Configuration:")
message(STATUS "DDS_HOME: ${DDS_HOME}")
message(STATUS "Available IDL Sources: ${AVAILABLE_IDL_SOURCES}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "====================================")
