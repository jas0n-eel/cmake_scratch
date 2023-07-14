include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(cmake_scratch_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(cmake_scratch_setup_options)
  option(cmake_scratch_ENABLE_HARDENING "Enable hardening" ON)
  option(cmake_scratch_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cmake_scratch_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cmake_scratch_ENABLE_HARDENING
    OFF)

  cmake_scratch_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cmake_scratch_PACKAGING_MAINTAINER_MODE)
    option(cmake_scratch_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cmake_scratch_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cmake_scratch_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cmake_scratch_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cmake_scratch_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cmake_scratch_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cmake_scratch_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cmake_scratch_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cmake_scratch_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cmake_scratch_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cmake_scratch_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cmake_scratch_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cmake_scratch_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cmake_scratch_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cmake_scratch_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cmake_scratch_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cmake_scratch_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cmake_scratch_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cmake_scratch_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cmake_scratch_ENABLE_IPO
      cmake_scratch_WARNINGS_AS_ERRORS
      cmake_scratch_ENABLE_USER_LINKER
      cmake_scratch_ENABLE_SANITIZER_ADDRESS
      cmake_scratch_ENABLE_SANITIZER_LEAK
      cmake_scratch_ENABLE_SANITIZER_UNDEFINED
      cmake_scratch_ENABLE_SANITIZER_THREAD
      cmake_scratch_ENABLE_SANITIZER_MEMORY
      cmake_scratch_ENABLE_UNITY_BUILD
      cmake_scratch_ENABLE_CLANG_TIDY
      cmake_scratch_ENABLE_CPPCHECK
      cmake_scratch_ENABLE_COVERAGE
      cmake_scratch_ENABLE_PCH
      cmake_scratch_ENABLE_CACHE)
  endif()

  cmake_scratch_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cmake_scratch_ENABLE_SANITIZER_ADDRESS OR cmake_scratch_ENABLE_SANITIZER_THREAD OR cmake_scratch_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cmake_scratch_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cmake_scratch_global_options)
  if(cmake_scratch_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cmake_scratch_enable_ipo()
  endif()

  cmake_scratch_supports_sanitizers()

  if(cmake_scratch_ENABLE_HARDENING AND cmake_scratch_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cmake_scratch_ENABLE_SANITIZER_UNDEFINED
       OR cmake_scratch_ENABLE_SANITIZER_ADDRESS
       OR cmake_scratch_ENABLE_SANITIZER_THREAD
       OR cmake_scratch_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cmake_scratch_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cmake_scratch_ENABLE_SANITIZER_UNDEFINED}")
    cmake_scratch_enable_hardening(cmake_scratch_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cmake_scratch_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cmake_scratch_warnings INTERFACE)
  add_library(cmake_scratch_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cmake_scratch_set_project_warnings(
    cmake_scratch_warnings
    ${cmake_scratch_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cmake_scratch_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(cmake_scratch_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cmake_scratch_enable_sanitizers(
    cmake_scratch_options
    ${cmake_scratch_ENABLE_SANITIZER_ADDRESS}
    ${cmake_scratch_ENABLE_SANITIZER_LEAK}
    ${cmake_scratch_ENABLE_SANITIZER_UNDEFINED}
    ${cmake_scratch_ENABLE_SANITIZER_THREAD}
    ${cmake_scratch_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cmake_scratch_options PROPERTIES UNITY_BUILD ${cmake_scratch_ENABLE_UNITY_BUILD})

  if(cmake_scratch_ENABLE_PCH)
    target_precompile_headers(
      cmake_scratch_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cmake_scratch_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cmake_scratch_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cmake_scratch_ENABLE_CLANG_TIDY)
    cmake_scratch_enable_clang_tidy(cmake_scratch_options ${cmake_scratch_WARNINGS_AS_ERRORS})
  endif()

  if(cmake_scratch_ENABLE_CPPCHECK)
    cmake_scratch_enable_cppcheck(${cmake_scratch_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cmake_scratch_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cmake_scratch_enable_coverage(cmake_scratch_options)
  endif()

  if(cmake_scratch_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cmake_scratch_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cmake_scratch_ENABLE_HARDENING AND NOT cmake_scratch_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cmake_scratch_ENABLE_SANITIZER_UNDEFINED
       OR cmake_scratch_ENABLE_SANITIZER_ADDRESS
       OR cmake_scratch_ENABLE_SANITIZER_THREAD
       OR cmake_scratch_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cmake_scratch_enable_hardening(cmake_scratch_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
