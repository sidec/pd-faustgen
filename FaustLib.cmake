## Create Faust Lib
message(STATUS "Faust Library")


## Save the llvm directory and change it for subdirectory
if(DEFINED LLVM_DIR)
  set(LLVM_DIR_TEMP   ${LLVM_DIR})
  set(LLVM_DIR        "./../.${LLVM_DIR_TEMP}")
endif()

## Hardcoded targets for faust
## The pinned LLVM archive (see .github/workflows/makefile.yml) is built with
## the DLL runtime (/MD); /MT fails LNK2038 against it, so keep faust on /MD.
set(MSVC_STATIC         OFF CACHE STRING  "Use static runtimes with MSVC" FORCE)
set(INCLUDE_STATIC      ON  CACHE STRING  "Include static library"        FORCE)
set(INCLUDE_EXECUTABLE  OFF CACHE STRING  "Include runtime executable"    FORCE)
set(INCLUDE_DYNAMIC     OFF CACHE STRING  "Include dynamic library"       FORCE)
set(INCLUDE_OSC         OFF CACHE STRING  "Include Faust OSC library"     FORCE)
set(INCLUDE_HTTP        OFF CACHE STRING  "Include Faust HTTPD library"   FORCE)

## Hardcoded backends for faust
set(ASMJS_BACKEND  OFF                            CACHE STRING  "Include ASMJS backend" FORCE)
set(C_BACKEND      OFF                            CACHE STRING  "Include C backend"         FORCE)
set(CPP_BACKEND    OFF                            CACHE STRING  "Include CPP backend"       FORCE)
set(FIR_BACKEND    OFF                            CACHE STRING  "Include FIR backend"       FORCE)
set(INTERP_BACKEND OFF                            CACHE STRING  "Include INTERPRETER backend" FORCE)
set(JAVA_BACKEND   OFF                            CACHE STRING  "Include JAVA backend"      FORCE)
set(JS_BACKEND     OFF                            CACHE STRING  "Include JAVASCRIPT backend" FORCE)
set(LLVM_BACKEND   COMPILER STATIC DYNAMIC        CACHE STRING  "Include LLVM backend"      FORCE)
set(OLDCPP_BACKEND OFF                            CACHE STRING  "Include old CPP backend"   FORCE)
set(RUST_BACKEND   OFF                            CACHE STRING  "Include RUST backend"      FORCE)
set(WASM_BACKEND   OFF                            CACHE STRING  "Include WASM backend"  FORCE)

## Call the faust cmakelist.txt
add_subdirectory(./faust/build EXCLUDE_FROM_ALL)

if(MSVC)
    set_property(TARGET staticlib APPEND_STRING PROPERTY COMPILE_FLAGS " /EHsc /D WIN32 -D_SCL_SECURE_NO_WARNINGS")
    set_property(TARGET staticlib APPEND_STRING PROPERTY LINK_FLAGS " /ignore:4099 ")
endif()

if(WIN32)
    # faust's staticlib source glob stops at */*.cpp, so generator/interpreter/
    # is excluded, yet instructions_compiler.cpp always instantiates the
    # interpreter compiler and references interpreter_dsp; Windows DLL links
    # must resolve every symbol (Linux allows the undefined refs in a .so).
    target_sources(staticlib PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/faust/compiler/generator/interpreter/interpreter_dsp_aux.cpp")
endif()

## Restore llvm directory
if(DEFINED LLVM_DIR)
  set(LLVM_DIR ${LLVM_DIR_TEMP})
endif()
