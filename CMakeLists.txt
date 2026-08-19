##################################################################################################### SETUP 

set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_SOURCE_DIR} CACHE PATH "install prefix" FORCE)
cmake_minimum_required(VERSION 3.15)
project(common-modules VERSION 1.0 LANGUAGES C CXX)
get_filename_component(REPO_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

# Enable clang-tidy if available
find_program(CLANG_TIDY_EXE NAMES clang-tidy)
if(CLANG_TIDY_EXE)
  # Use the repository root .clang-tidy config for all compile-time analysis.
  set(CMAKE_CXX_CLANG_TIDY
      "${CLANG_TIDY_EXE};--config-file=${REPO_ROOT_DIR}/.clang-tidy;-p;${CMAKE_BINARY_DIR}")
  # Generate compile_commands.json for clang-tidy and IDE support
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
endif()

# Use a modern C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Target‑specific compile options (debug build with pthread)
set(_common_modules_compile_options -g -O0)

# Code coverage flags (only for Debug builds)
set(_common_modules_coverage_compile_options)
set(_common_modules_coverage_link_options)
set(_common_modules_link_options)  # placeholder for any additional link options (currently empty)
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(_common_modules_coverage_compile_options --coverage -fprofile-arcs -ftest-coverage)
  set(_common_modules_coverage_link_options --coverage)
endif()

##################################################################################################### BUILD MODULE(S)

add_library(coordinate_conversions SHARED)
target_sources(coordinate_conversions PRIVATE
    coordinate-conversions/src/CoordinateConversions.cpp
)
target_include_directories(coordinate_conversions PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/coordinate-conversions/include>
    $<INSTALL_INTERFACE:include>
)
target_link_options(coordinate_conversions PUBLIC ${_common_modules_coverage_link_options})
# Apply coverage compile options to the coordinate-conversions library when in Debug mode
target_compile_options(coordinate_conversions PUBLIC ${_common_modules_coverage_compile_options})

# Install the library and export a target for downstream consumption
install(TARGETS coordinate_conversions
    EXPORT coordinate_conversions_targets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include)
install(EXPORT coordinate_conversions_targets
    FILE coordinate_conversions-config.cmake
    NAMESPACE common_modules::
    DESTINATION lib/cmake/coordinate_conversions)
install(FILES coordinate-conversions/include/CoordinateConversions.hpp
    DESTINATION include)

# Build Detect Core library
add_library(detect_core SHARED)
target_sources(detect_core PRIVATE
    detect-core/src/Result.cpp
    detect-core/src/Config.cpp
    detect-core/src/Model.cpp
    detect-core/src/Evaluation.cpp
    # Feature related source files are located in the 'features' subdirectory
    detect-core/src/features/FeatureRegistry.cpp
    detect-core/src/features/FeatureState.cpp
    detect-core/src/features/FeatureValue.cpp
    detect-core/src/feature-extraction/impl/snr/SnrFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/jnr/JnrFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/estimated-position/EstimatedPosFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/angle-error/AngleErrorFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/estimated-uvr/EstimatedUvrFeatureExtractor.cpp
    detect-core/src/detection-evaluation/impl/SnrThresholdEvaluator.cpp
    detect-core/src/detection-evaluation/impl/AngleEvaluator.cpp
    detect-core/src/detection-evaluation/impl/AngleEvaluation.cpp
    detect-core/src/detection-evaluation/impl/RangeEvaluator.cpp
    detect-core/src/detection-evaluation/impl/RangeEvaluation.cpp
    detect-core/src/detection-evaluation/impl/SnrThresholdEvaluation.cpp
    detect-core/src/pipeline/Pipeline.cpp
    detect-core/src/pipeline/PipelineAssembler.cpp
    detect-core/src/Context.cpp
)
target_include_directories(detect_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
    # Add the nested include directory so headers like "Result.hpp" can be found directly
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include/detect-core
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
# Include coverage compile options when building in Debug mode so that
# code coverage data is collected for the Detect Core library and its
# source files. The coverage flags are defined earlier in the file as
# _common_modules_coverage_compile_options and _common_modules_coverage_link_options.
target_compile_options(detect_core PUBLIC ${_common_modules_compile_options} ${_common_modules_coverage_compile_options})
target_link_options(detect_core PUBLIC ${_common_modules_coverage_link_options})

# Ensure symbols from internal implementation files are hidden by default.
# The `-fvisibility=hidden` flag works with GCC/Clang and respects the
# CXX_VISIBILITY_PRESET property set above. This way only symbols explicitly
# marked with default visibility (e.g., the public API in the headers under
# `detect-core/include`) become part of the shared object's exported symbol table.
target_compile_options(detect_core PRIVATE -fvisibility=hidden)
# Define DETECT_CORE_BUILD so that Export.hpp marks symbols for export when building the library
target_compile_definitions(detect_core PRIVATE DETECT_CORE_BUILD)
install(TARGETS detect_core
    EXPORT detect_core_targets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include)
install(EXPORT detect_core_targets
    FILE detect_core-config.cmake
    NAMESPACE common_modules::
    DESTINATION lib/cmake/detect_core
)

# ============================================================================
# DataLogger Library
# ============================================================================

# ---------------------------------------------------------------------------
# Find DXR Libraries from Maven Dependencies
# ---------------------------------------------------------------------------
set(MAVEN_DEPS_DIR "${CMAKE_BINARY_DIR}/../dependencies" CACHE PATH "Maven dependencies directory")

# Try to find DXR headers and libraries
find_path(DXR_INCLUDE_DIR
    NAMES dxr.h
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/dxr/include
        ${MAVEN_DEPS_DIR}/U-SYSSERV-INTERFACES-6.3.0/linux-os8.5-gcc8.5.0/dxr/include
        ${MAVEN_DEPS_DIR}/*/linux-*/dxr/include
    NO_DEFAULT_PATH
)

find_library(DXR_DEAPI_LIBRARY
    NAMES dxr_deapi libdxr_deapi
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/dxr/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/dxr/lib
    NO_DEFAULT_PATH
)

find_library(DXR_CCAPI_LIBRARY
    NAMES dxr_ccapi libdxr_ccapi
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/dxr/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/dxr/lib
    NO_DEFAULT_PATH
)

find_library(DXR_COMMON_LIBRARY
    NAMES dxr_common libdxr_common
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/dxr/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/dxr/lib
    NO_DEFAULT_PATH
)

# Find supporting libraries (GENLOG, ARC Common, Time Services)
find_library(GENLOG_LIBRARY
    NAMES genlog libgenlog
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/genlog/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/genlog/lib
    NO_DEFAULT_PATH
)

find_library(ARC_COMMON_LIBRARY
    NAMES arc_common libarc_common
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/arc_common/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/arc_common/lib
    NO_DEFAULT_PATH
)

find_library(TIME_SERVICES_LIBRARY
    NAMES time libtime
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/time/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/time/lib
    NO_DEFAULT_PATH
)

find_library(DXR_EXECVERID_LIBRARY
    NAMES dxrexecverid libdxrexecverid
    PATHS 
        ${MAVEN_DEPS_DIR}/U-SYSSERV-CRX-6.3.0/linux-os8.5-gcc8.5.0-64b-dds6.1.2.23/dxr/lib
        ${MAVEN_DEPS_DIR}/*/linux-*/dxr/lib
    NO_DEFAULT_PATH
)

# Check if DXR was found
if(DXR_INCLUDE_DIR AND DXR_DEAPI_LIBRARY)
    set(HAVE_DXR TRUE)
    message(STATUS "DXR found:")
    message(STATUS "  Include dir: ${DXR_INCLUDE_DIR}")
    message(STATUS "  DE API library: ${DXR_DEAPI_LIBRARY}")
    if(DXR_CCAPI_LIBRARY)
        message(STATUS "  CC API library: ${DXR_CCAPI_LIBRARY}")
    endif()
    if(DXR_COMMON_LIBRARY)
        message(STATUS "  Common library: ${DXR_COMMON_LIBRARY}")
    endif()
    if(GENLOG_LIBRARY)
        message(STATUS "  GENLOG library: ${GENLOG_LIBRARY}")
    endif()
    if(ARC_COMMON_LIBRARY)
        message(STATUS "  ARC Common library: ${ARC_COMMON_LIBRARY}")
    endif()
    if(TIME_SERVICES_LIBRARY)
        message(STATUS "  Time Services library: ${TIME_SERVICES_LIBRARY}")
    endif()
else()
    set(HAVE_DXR FALSE)
    message(WARNING "DXR libraries not found - DxrLogger will be stub only")
    message(STATUS "  Searched in: ${MAVEN_DEPS_DIR}")
endif()

# Configure DxrConfig.hpp header
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include/DataLogger/DxrConfig.hpp.in
    ${CMAKE_CURRENT_BINARY_DIR}/DataLogger/include/DataLogger/DxrConfig.hpp
    @ONLY
)

# ---------------------------------------------------------------------------
# DataLogger Library Target
# ---------------------------------------------------------------------------
add_library(data_logger SHARED)
target_sources(data_logger PRIVATE
    DataLogger/src/DataLogger.cpp
    DataLogger/src/TextLogger.cpp
    DataLogger/src/TraceLogger.cpp
    DataLogger/src/DxrLogger.cpp
    DataLogger/src/H5Schema.cpp
    DataLogger/src/H5Record.cpp
    DataLogger/src/H5Logger.cpp
    DataLogger/src/writers/H5Writer.cpp
    DataLogger/src/LogConfig.cpp
    DataLogger/src/LogLevel.cpp
    DataLogger/src/LogEntry.cpp
    DataLogger/src/writers/FileWriter.cpp
    DataLogger/src/formatting/TextFormatter.cpp
    DataLogger/src/formatting/BinaryFormatter.cpp
    DataLogger/src/sync/ProcessLock.cpp
    DataLogger/src/dxr/DxrErrorHandler.cpp
    DataLogger/src/dxr/DxrBufferPoolManager.cpp
    DataLogger/src/dxr/DxrDataExtractor.cpp
)

target_include_directories(data_logger PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include/DataLogger
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/src
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/DataLogger/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/DataLogger/include/DataLogger>
)

target_compile_options(data_logger PUBLIC 
    ${_common_modules_compile_options} 
    ${_common_modules_coverage_compile_options}
)

target_compile_options(data_logger PRIVATE -fvisibility=hidden)
target_compile_definitions(data_logger PRIVATE DATALOGGER_BUILD)

# Link pthread for file locking support
target_link_libraries(data_logger PRIVATE pthread)

# Optional: HDF5 for H5Logger
find_package(HDF5 COMPONENTS C QUIET)
if(HDF5_FOUND)
    message(STATUS "HDF5 found: ${HDF5_INCLUDE_DIRS}")
    target_include_directories(data_logger PRIVATE ${HDF5_INCLUDE_DIRS})
    target_link_libraries(data_logger PRIVATE ${HDF5_LIBRARIES})
    target_compile_definitions(data_logger PRIVATE HAVE_HDF5)
else()
    message(STATUS "HDF5 not found - H5Logger will throw on construction")
endif()

# Link DXR libraries if available
if(HAVE_DXR)
    target_include_directories(data_logger PRIVATE ${DXR_INCLUDE_DIR})
    target_link_libraries(data_logger PRIVATE 
        ${DXR_DEAPI_LIBRARY}
        ${DXR_COMMON_LIBRARY}
        ${ARC_COMMON_LIBRARY}
    )
    
    # DXR execverid library (required for DXR_GetExecutableVersionId)
    if(DXR_EXECVERID_LIBRARY)
        target_link_libraries(data_logger PRIVATE ${DXR_EXECVERID_LIBRARY})
    endif()
    # Optional libraries
    if(DXR_CCAPI_LIBRARY)
        target_link_libraries(data_logger PRIVATE ${DXR_CCAPI_LIBRARY})
    endif()
    if(ARC_COMMON_LIBRARY)
        target_link_libraries(data_logger PRIVATE ${ARC_COMMON_LIBRARY})
    endif()
    if(GENLOG_LIBRARY)
        target_link_libraries(data_logger PRIVATE ${GENLOG_LIBRARY})
    endif()
    
    # Time Services (optional)
    if(TIME_SERVICES_LIBRARY)
        target_link_libraries(data_logger PRIVATE ${TIME_SERVICES_LIBRARY})
        target_compile_definitions(data_logger PRIVATE HAVE_TIME_SERVICES)
    endif()
    
    target_compile_definitions(data_logger PRIVATE HAVE_DXR)
endif()

target_link_options(data_logger PUBLIC ${_common_modules_coverage_link_options})

# Installation
install(TARGETS data_logger
    EXPORT data_logger_targets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include
)

install(DIRECTORY DataLogger/include/DataLogger
    DESTINATION include
    FILES_MATCHING PATTERN "*.hpp"
)

install(EXPORT data_logger_targets
    FILE data_logger-config.cmake
    NAMESPACE CommonModules::
    DESTINATION lib/cmake/data_logger
)

# Build Detect Sim library
add_library(detect_sim SHARED)
target_sources(detect_sim PRIVATE
    detect-sim/src/Context.cpp
    detect-sim/src/Config.cpp
    detect-sim/src/Model.cpp
    detect-sim/src/ModelAssembler.cpp
    detect-sim/src/impl/DefaultTruthExtrapolator.cpp
    detect-sim/src/impl/DefaultRangeChecker.cpp
    detect-sim/src/impl/DefaultAngleChecker.cpp
)
target_include_directories(detect_sim PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-sim/include
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-sim/include/detect-sim
)
target_compile_options(detect_sim PUBLIC ${_common_modules_compile_options} ${_common_modules_coverage_compile_options})
target_link_options(detect_sim PUBLIC ${_common_modules_coverage_link_options})
target_compile_options(detect_sim PRIVATE -fvisibility=hidden)
target_compile_definitions(detect_sim PRIVATE DETECT_SIM_BUILD)
install(TARGETS detect_sim
    EXPORT detect_sim_targets
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include)
install(EXPORT detect_sim_targets
    FILE detect_sim-config.cmake
    NAMESPACE common_modules::
    DESTINATION lib/cmake/detect_sim
)
install(DIRECTORY detect-sim/include/detect-sim
    DESTINATION include)
##################################################################################################### BUILD MODULE(S) TESTS
# gtest_discover_tests(coordinate-conversions-tests)
find_package(GTest REQUIRED)
# Enable CTest integration with GoogleTest so individual TESTs are visible to ctest
include(GoogleTest)
# Benchmark library is optional; it is only needed for the benchmark executable.
find_package(benchmark QUIET)

add_executable(coordinate-conversions-tests
    coordinate-conversions/src/CoordinateConversions.xUnit.cpp
)
# Link only the GTest main target. Add definition to disable GTest's internal
# pthread usage (which can conflict with the shared‑library build on this
# platform). This avoids the double‑free crash during test registration.
# Explicitly link both GTest libraries and pthread to avoid missing symbols and
# the double‑free crash caused by incomplete pthread handling when GTest is
# built as shared libraries.
target_link_libraries(coordinate-conversions-tests PRIVATE GTest::gtest GTest::gtest_main coordinate_conversions pthread)
target_compile_options(coordinate-conversions-tests PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(coordinate-conversions-tests PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(coordinate-conversions-tests PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/coordinate-conversions/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
)

enable_testing()
# Discover and register each GoogleTest test with CTest instead of a single wrapper test
gtest_discover_tests(coordinate-conversions-tests)

add_test(
    NAME coordinate_conversions_junit
    COMMAND coordinate-conversions-tests --gtest_output=xml:../coordinate-conversions-test-report.xml
)

# ---------------------------------------------------------------------------
# Detect Core User-Level Test
# ---------------------------------------------------------------------------
# This test exercises the public API of the detect_core library as a consumer
# would. It links against the built detect_core shared library, GTest and the
# pthread library (required by GTest on many platforms).

add_executable(detect_core_user_test
  detect-core/tests/ApiTest.cpp
)

target_link_libraries(detect_core_user_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_user_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_user_test PRIVATE ${_common_modules_coverage_link_options})

target_include_directories(detect_core_user_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
)

# Register the Detect Core unit test with CTest so it runs alongside other tests.
add_test(
    NAME detect_core_user_test 
    COMMAND detect_core_user_test --gtest_output=xml:../detect-core-user-test-report.xml)

# ---------------------------------------------------------------------------
# Detect Sim User-Level Test
# ---------------------------------------------------------------------------
add_executable(detect_sim_user_test
  detect-sim/tests/ApiTest.cpp
)

target_link_libraries(detect_sim_user_test PRIVATE
  detect_sim
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_sim_user_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_sim_user_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_sim_user_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/detect-sim/include
)
add_test(
    NAME detect_sim_user_test
    COMMAND detect_sim_user_test --gtest_output=xml:../detect-sim-user-test-report.xml)

# ---------------------------------------------------------------------------
# Additional Detect Core unit tests for comprehensive branch coverage
# ---------------------------------------------------------------------------

# --------------------------------------------------------------------------- PipelineTest 
add_executable(detect_core_pipeline_test
  detect-core/tests/pipeline/PipelineTest.cpp
)
target_link_libraries(detect_core_pipeline_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_pipeline_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_pipeline_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_pipeline_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
target_sources(detect_core_pipeline_test PRIVATE
  detect-core/src/pipeline/Pipeline.cpp
  detect-core/src/pipeline/PipelineAssembler.cpp
)
target_sources(detect_core_pipeline_test PRIVATE
  detect-core/src/features/FeatureRegistry.cpp
  detect-core/src/features/FeatureState.cpp
  detect-core/src/features/FeatureValue.cpp
  detect-core/src/feature-extraction/impl/jnr/JnrFeatureExtractor.cpp
  detect-core/src/feature-extraction/impl/snr/SnrFeatureExtractor.cpp
  detect-core/src/feature-extraction/impl/estimated-position/EstimatedPosFeatureExtractor.cpp
  detect-core/src/feature-extraction/impl/angle-error/AngleErrorFeatureExtractor.cpp
  detect-core/src/feature-extraction/impl/estimated-uvr/EstimatedUvrFeatureExtractor.cpp
  detect-core/src/detection-evaluation/impl/SnrThresholdEvaluator.cpp
  detect-core/src/detection-evaluation/impl/AngleEvaluator.cpp
  detect-core/src/detection-evaluation/impl/RangeEvaluator.cpp

)
add_test(
    NAME detect_core_pipeline_test
    COMMAND detect_core_pipeline_test --gtest_output=xml:../detect-core-pipeline-test-report.xml)

# --------------------------------------------------------------------------- ConfigTest
add_executable(detect_core_config_test
  detect-core/tests/ConfigTest.cpp
)
target_link_libraries(detect_core_config_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_config_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_config_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_config_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
add_test(
    NAME detect_core_config_test
    COMMAND detect_core_config_test --gtest_output=xml:../detect-core-config-test-report.xml)

# --------------------------------------------------------------------------- FeatureStateTest
add_executable(detect_core_feature_state_test
  detect-core/tests/features/FeatureStateTest.cpp
  detect-core/src/feature-extraction/impl/jnr/JnrFeatureExtractor.cpp
  detect-core/src/feature-extraction/impl/snr/SnrFeatureExtractor.cpp
  detect-core/src/detection-evaluation/impl/SnrThresholdEvaluator.cpp
  detect-core/src/features/FeatureValue.cpp
  detect-core/src/features/FeatureRegistry.cpp
  detect-core/src/features/FeatureState.cpp
)
target_link_libraries(detect_core_feature_state_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_feature_state_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_feature_state_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_feature_state_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
add_test(
    NAME detect_core_feature_state_test
    COMMAND detect_core_feature_state_test --gtest_output=xml:../detect-core-feature-state-test-report.xml)

# --------------------------------------------------------------------------- JnrFeatureExtractorTest
add_executable(detect_core_jnr_extractor_test
  detect-core/tests/feature-extraction/jnr/JnrFeatureExtractorTest.cpp
  detect-core/src/feature-extraction/impl/jnr/JnrFeatureExtractor.cpp
  detect-core/src/features/FeatureRegistry.cpp
  detect-core/src/features/FeatureState.cpp
  detect-core/src/features/FeatureValue.cpp
)
target_link_libraries(detect_core_jnr_extractor_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_jnr_extractor_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_jnr_extractor_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_jnr_extractor_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
add_test(
    NAME detect_core_jnr_extractor_test
    COMMAND detect_core_jnr_extractor_test --gtest_output=xml:../detect-core-jnr-extractor-test-report.xml)


# ----------------------------------------------------------------- Begin EstimatedPosFeatureExtractorTest
add_executable(detect_core_estimated_pos_extractor_test
  detect-core/tests/feature-extraction/estimated-position/EstimatedPosFeatureExtractorTest.cpp
  detect-core/src/feature-extraction/impl/estimated-position/EstimatedPosFeatureExtractor.cpp
  detect-core/src/features/FeatureRegistry.cpp
  detect-core/src/features/FeatureState.cpp
  detect-core/src/features/FeatureValue.cpp
)
target_link_libraries(detect_core_estimated_pos_extractor_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_estimated_pos_extractor_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_estimated_pos_extractor_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_estimated_pos_extractor_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
add_test(NAME detect_core_estimated_pos_extractor_test COMMAND detect_core_estimated_pos_extractor_test)

# ------------------------------------------------------------------End EstimatedPosFeatureExtractorTest

# ------------------------------------------------------------------ Begin EstimatedUvrFeatureExtractorTest
add_executable(detect_core_estimated_uvr_extractor_test
  detect-core/tests/feature-extraction/estimated-uvr/EstimatedUvrFeatureExtractorTest.cpp
  detect-core/src/feature-extraction/impl/estimated-uvr/EstimatedUvrFeatureExtractor.cpp
  detect-core/src/features/FeatureRegistry.cpp
  detect-core/src/features/FeatureState.cpp
  detect-core/src/features/FeatureValue.cpp
)
target_link_libraries(detect_core_estimated_uvr_extractor_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_estimated_uvr_extractor_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_estimated_uvr_extractor_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_estimated_uvr_extractor_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
add_test(NAME detect_core_estimated_uvr_extractor_test COMMAND detect_core_estimated_uvr_extractor_test)

# ------------------------------------------------------------------End EstimatedUvrFeatureExtractorTest

# ------------------------------------------------------------------ Begin AngleErrorFeatureExtractorTest
add_executable(detect_core_angle_error_extractor_test
  detect-core/tests/feature-extraction/angle-error/AngleErrorFeatureExtractorTest.cpp
  detect-core/src/feature-extraction/impl/angle-error/AngleErrorFeatureExtractor.cpp
  detect-core/src/feature-extraction/impl/estimated-uvr/EstimatedUvrFeatureExtractor.cpp
  detect-core/src/features/FeatureRegistry.cpp
  detect-core/src/features/FeatureState.cpp
  detect-core/src/features/FeatureValue.cpp
)
target_link_libraries(detect_core_angle_error_extractor_test PRIVATE
  detect_core
  GTest::gtest
  GTest::gtest_main
  pthread
)
target_compile_options(detect_core_angle_error_extractor_test PRIVATE ${_common_modules_coverage_compile_options})
target_link_options(detect_core_angle_error_extractor_test PRIVATE ${_common_modules_coverage_link_options})
target_include_directories(detect_core_angle_error_extractor_test PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/include
  ${CMAKE_CURRENT_SOURCE_DIR}/detect-core/src
)
add_test(NAME detect_core_angle_error_extractor_test COMMAND detect_core_angle_error_extractor_test)

# ------------------------------------------------------------------End AngleErrorFeatureExtractorTest


# Benchmark target for coordinate-conversions (optional)
add_executable(coordinate_conversions_bench
    coordinate-conversions/src/CoordinateConversions_benchmark.cpp
)
if(TARGET benchmark::benchmark)
    target_link_libraries(coordinate_conversions_bench PRIVATE coordinate_conversions benchmark::benchmark)

    # Register benchmarks with CTest as a single test. This allows `ctest`
    # (and thus `mvn test`) to run the benchmarks and emit the JSON report
    # used by the CI dashboard. We write the JSON one level above the
    # CMake binary dir (CMAKE_BINARY_DIR == target/cmake-build), i.e.
    # into target/benchmark-report.json.
    add_test(
        NAME coordinate_conversions_bench
        COMMAND coordinate_conversions_bench
                --benchmark_out=../coordinate-conversions-benchmark-report.json
                --benchmark_format=json
    )
    set_tests_properties(coordinate_conversions_bench PROPERTIES LABELS "benchmark")
else()
    message(WARNING "Benchmark library not found; coordinate_conversions benchmark executable will not be built.")
endif()
target_compile_options(coordinate_conversions_bench PRIVATE ${_common_modules_compile_options})
target_link_options(coordinate_conversions_bench PRIVATE ${_common_modules_link_options})

# ---------------------------------------------------------------------------
# Detect Core Benchmark (optional)
# ---------------------------------------------------------------------------
add_executable(detect_core_bench
    detect-core/tests/benchmarks/InBeamBenchmark.cpp
    detect-core/tests/benchmarks/feature-extraction/jnr/JnrFeatureExtractorBenchmark.cpp
    detect-core/tests/benchmarks/feature-extraction/snr/SnrFeatureExtractorBenchmark.cpp
    detect-core/tests/benchmarks/feature-extraction/estimated-position/EstimatedPosFeatureExtractorBenchmark.cpp
    detect-core/tests/benchmarks/feature-extraction/estimated-uvr/EstimatedUvrFeatureExtractorBenchmark.cpp
    detect-core/tests/benchmarks/feature-extraction/angle-error/AngleErrorFeatureExtractorBenchmark.cpp
    detect-core/tests/benchmarks/detection-evaluation/SnrThresholdEvaluatorBenchmark.cpp
    detect-core/tests/benchmarks/detection-evaluation/AngleEvaluatorBenchmark.cpp
    detect-core/tests/benchmarks/detection-evaluation/RangeEvaluatorBenchmark.cpp

)
target_sources(detect_core_bench PRIVATE
    detect-core/src/features/FeatureRegistry.cpp
    detect-core/src/features/FeatureState.cpp
    detect-core/src/features/FeatureValue.cpp
    detect-core/src/feature-extraction/impl/snr/SnrFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/jnr/JnrFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/estimated-position/EstimatedPosFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/angle-error/AngleErrorFeatureExtractor.cpp
    detect-core/src/feature-extraction/impl/estimated-uvr/EstimatedUvrFeatureExtractor.cpp
    detect-core/src/detection-evaluation/impl/SnrThresholdEvaluator.cpp
    detect-core/src/detection-evaluation/impl/AngleEvaluator.cpp
    detect-core/src/detection-evaluation/impl/AngleEvaluation.cpp
    detect-core/src/detection-evaluation/impl/RangeEvaluator.cpp
    detect-core/src/detection-evaluation/impl/RangeEvaluation.cpp
    detect-core/src/detection-evaluation/impl/SnrThresholdEvaluation.cpp
)
if(TARGET benchmark::benchmark)
    # Link both the benchmark library and its main target to provide the required entry point.
    target_link_libraries(detect_core_bench PRIVATE detect_core benchmark::benchmark benchmark::benchmark_main)

    # Register the Detect Core benchmark with CTest. The JSON report is written
    # alongside the other benchmark report for consistency.
    add_test(
        NAME detect_core_bench
        COMMAND detect_core_bench
                --benchmark_out=../detect-core-benchmark-report.json
                --benchmark_format=json
    )
    set_tests_properties(detect_core_bench PROPERTIES LABELS "benchmark")
else()
    message(WARNING "Benchmark library not found; detect_core benchmark executable will not be built.")
endif()
target_compile_options(detect_core_bench PRIVATE ${_common_modules_compile_options})
target_link_options(detect_core_bench PRIVATE ${_common_modules_link_options})


# ============================================================================
# DataLogger Tests
# ============================================================================
add_executable(data_logger_user_test
    DataLogger/tests/DataLoggerUserTest.cpp
)
target_link_libraries(data_logger_user_test PRIVATE
    data_logger
    GTest::gtest
    GTest::gtest_main
    pthread
)
target_compile_options(data_logger_user_test PRIVATE 
    ${_common_modules_coverage_compile_options}
)
target_link_options(data_logger_user_test PRIVATE 
    ${_common_modules_coverage_link_options}
)
target_include_directories(data_logger_user_test PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
)

# Discover and register each GoogleTest test with CTest
gtest_discover_tests(data_logger_user_test)

add_test(
    NAME data_logger_user_test_junit
    COMMAND data_logger_user_test --gtest_output=xml:../data-logger-user-test-report.xml
)

# ============================================================================
# DataLogger Demo Executable (no DXR required)
# ============================================================================
add_executable(data_logger_demo
    DataLogger/examples/basic_datalogger_demo.cpp
)

target_link_libraries(data_logger_demo PRIVATE
    data_logger
    pthread
)

target_include_directories(data_logger_demo PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
)

target_compile_options(data_logger_demo PRIVATE ${_common_modules_compile_options})
target_link_options(data_logger_demo PRIVATE ${_common_modules_link_options})

# =========================================================================
# H5Logger Example Executable (requires HDF5)
# =========================================================================
add_executable(h5_example
    DataLogger/examples/h5_example.cpp
)

target_link_libraries(h5_example PRIVATE
    data_logger
    pthread
)

target_include_directories(h5_example PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
)

target_compile_options(h5_example PRIVATE ${_common_modules_compile_options})
target_link_options(h5_example PRIVATE ${_common_modules_link_options})

# ============================================================================
# DataLogger Benchmark (optional)
# ============================================================================
add_executable(data_logger_bench
    DataLogger/tests/benchmarks/DataLoggerBenchmark.cpp
)
if(TARGET benchmark::benchmark)
    target_link_libraries(data_logger_bench PRIVATE 
        data_logger 
        benchmark::benchmark 
        benchmark::benchmark_main
        pthread
    )
    target_include_directories(data_logger_bench PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
    )
    
    # Register the DataLogger benchmark with CTest
    add_test(
        NAME data_logger_bench
        COMMAND data_logger_bench
                --benchmark_out=../data-logger-benchmark-report.json
                --benchmark_format=json
    )
    set_tests_properties(data_logger_bench PROPERTIES LABELS "benchmark")
else()
    message(WARNING "Benchmark library not found; data_logger benchmark executable will not be built.")
endif()
target_compile_options(data_logger_bench PRIVATE ${_common_modules_compile_options})
target_link_options(data_logger_bench PRIVATE ${_common_modules_link_options})

# ============================================================================
# DXR API Test (optional - only if DXR is available)
# ============================================================================
if(HAVE_DXR)
    add_executable(dxr_api_test
        DataLogger/tests/dxr_api_test.cpp
    )
    
    target_include_directories(dxr_api_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
        ${CMAKE_CURRENT_BINARY_DIR}/DataLogger/include
        ${DXR_INCLUDE_DIR}
    )
    
    target_link_libraries(dxr_api_test PRIVATE
        ${DXR_DEAPI_LIBRARY}
        ${DXR_COMMON_LIBRARY}
        pthread
    )
    
    # DXR execverid library (required)
    if(DXR_EXECVERID_LIBRARY)
        target_link_libraries(dxr_api_test PRIVATE ${DXR_EXECVERID_LIBRARY})
    endif()
    
    if(ARC_COMMON_LIBRARY)
        target_link_libraries(dxr_api_test PRIVATE ${ARC_COMMON_LIBRARY})
    endif()
    if(GENLOG_LIBRARY)
        target_link_libraries(dxr_api_test PRIVATE ${GENLOG_LIBRARY})
    endif()
    
    target_compile_definitions(dxr_api_test PRIVATE HAVE_DXR)
    target_compile_options(dxr_api_test PRIVATE ${_common_modules_compile_options})
    
    # Don't register as a test - it requires DXR daemon to be running
    # Run manually with: ./dxr_api_test
    # Note: This test is intentionally not added to CTest to avoid Maven build failures
    
    message(STATUS "DXR API test program will be built (run manually)")
    
    # ============================================================================
    # DXR Example Program
    # ============================================================================
    add_executable(dxr_example
        DataLogger/examples/dxr_example.cpp
    )
    
    target_include_directories(dxr_example PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/DataLogger/include
        ${CMAKE_CURRENT_BINARY_DIR}/DataLogger/include
    )
    
    target_link_libraries(dxr_example PRIVATE
        data_logger
        pthread
    )
    
    target_compile_options(dxr_example PRIVATE ${_common_modules_compile_options})
    
    message(STATUS "DXR example program will be built")
else()
    message(STATUS "DXR API test program skipped (DXR not available)")
    message(STATUS "DXR example program skipped (DXR not available)")
endif()
# ---------------------------------------------------------------------------
# Detect Sim Benchmark (optional)
# ---------------------------------------------------------------------------
add_executable(detect_sim_bench
    detect-sim/tests/benchmarks/InBeamBenchmark.cpp
)
if(TARGET benchmark::benchmark)
    target_link_libraries(detect_sim_bench PRIVATE detect_sim benchmark::benchmark benchmark::benchmark_main)

    add_test(
        NAME detect_sim_bench
        COMMAND detect_sim_bench
                --benchmark_out=../detect-sim-benchmark-report.json
                --benchmark_format=json
    )
    set_tests_properties(detect_sim_bench PROPERTIES LABELS "benchmark")
else()
    message(WARNING "Benchmark library not found; detect_sim benchmark executable will not be built.")
endif()
target_compile_options(detect_sim_bench PRIVATE ${_common_modules_compile_options})
target_link_options(detect_sim_bench PRIVATE ${_common_modules_link_options})
