# RovelStars/RunixOS LLVM Build Cache - Stage 1
#
# This is the Stage 1 bootstrap build cache. It builds LLVM/Clang/LLD/etc.
# on the build host (x86_64-unknown-linux-gnu), producing a toolchain that
# can then be used in Stage 2 to cross-compile everything for RunixOS with a
# proper sysroot.
#
# Why Stage 1 targets the host triple for runtimes:
#   The runtimes ExternalProject sub-build receives
#   -DCMAKE_C_COMPILER_TARGET=${LLVM_RUNTIME_TARGETS} and tries to link test
#   programs against that target's CRTs. Since RunixOS CRTs (/Core/LibKit,
#   *.ral, *.rdl) don't exist on the build host yet, every CMake linker test
#   fails. We use LLVM_RUNTIME_TARGETS="default" so the runtimes build
#   targets the host, while LLVM_DEFAULT_TARGET_TRIPLE is still set to
#   x86_64-rovelstars-runixos so `clang` defaults to emitting RunixOS code.
#
# Stage 2 notes:
#   - Set LLVM_DEFAULT_TARGET_TRIPLE and LLVM_RUNTIME_TARGETS to
#     x86_64-rovelstars-runixos (and aarch64-rovelstars-runixos for AArch64)
#   - Provide CMAKE_SYSROOT pointing to a RunixOS sysroot image
#   - Re-enable AArch64 builtins via LLVM_BUILTIN_TARGETS
#   - Use the stage1 clang/lld as CMAKE_C_COMPILER / CMAKE_CXX_COMPILER

# ── Sub-projects ──────────────────────────────────────────────────────────────
set(LLVM_TARGETS_TO_BUILD "X86;AArch64" CACHE STRING "" FORCE)
set(LLVM_ENABLE_PROJECTS
  "clang;clang-tools-extra;lld;lldb;bolt;mlir;polly"
  CACHE STRING "" FORCE)
set(LLVM_ENABLE_RUNTIMES
  "compiler-rt;libcxx;libcxxabi;libunwind;openmp"
  CACHE STRING "" FORCE)

# ── Vendor / branding ─────────────────────────────────────────────────────────
set(CLANG_VENDOR "RovelStars" CACHE STRING "" FORCE)
set(PACKAGE_VENDOR "RovelStars" CACHE STRING "" FORCE)
set(RunixOfficialBuild ON CACHE BOOL "" FORCE)
# TODO: set(BUG_REPORT_URL "https://os.rovelstars.com/bugreport" CACHE STRING "" FORCE)

# ── Build type ────────────────────────────────────────────────────────────────
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)

# ── Compiler (use system clang for stage 1) ───────────────────────────────────
set(CMAKE_C_COMPILER   "clang"   CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER "clang++" CACHE STRING "" FORCE)

# ── Linker ────────────────────────────────────────────────────────────────────
# Use LLVM_USE_LINKER with the absolute path to the system ld.lld.
# LLVM_ENABLE_LLD is mutually exclusive with LLVM_USE_LINKER (they conflict),
# so we use LLVM_USE_LINKER directly. The absolute path ensures both the
# top-level build and the runtimes ExternalProject sub-build (which receives
# LLVM_USE_LINKER as a -D passthrough argument) can locate the linker without
# searching relative to the freshly-built stage1 compiler prefix.
set(LLVM_ENABLE_LLD OFF CACHE BOOL "" FORCE)
set(LLVM_USE_LINKER "/usr/bin/ld.lld" CACHE STRING "" FORCE)

# ── Target triple ─────────────────────────────────────────────────────────────
# Stage 1: do NOT set LLVM_DEFAULT_TARGET_TRIPLE to a RunixOS triple.
#
# llvm/CMakeLists.txt unconditionally does:
#   set(LLVM_TARGET_TRIPLE "${LLVM_DEFAULT_TARGET_TRIPLE}")
# (a non-cache set, highest priority). LLVM_TARGET_TRIPLE is then passed as
# -DCMAKE_C_COMPILER_TARGET=${LLVM_TARGET_TRIPLE} to the runtimes ExternalProject
# sub-build. If this is a RunixOS triple, the freshly-built stage1 clang tries
# to link runtimes test programs against RunixOS CRTs (*.ral, /Core/LibKit/...)
# that don't exist on the build host — every CMake linker test fails.
#
# Solution: leave LLVM_DEFAULT_TARGET_TRIPLE unset in Stage 1. CMake will
# auto-detect the host triple (x86_64-unknown-linux-gnu). The stage1 compiler
# already knows how to *emit* RunixOS code (the RunixOS triple is registered in
# Triple.cpp); stage2 will set LLVM_DEFAULT_TARGET_TRIPLE to the RunixOS triple
# once a proper RunixOS sysroot is available.
#
# Uncomment in Stage 2:
# set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)

# ── Runtimes target ───────────────────────────────────────────────────────────
# "default" = build runtimes for the host triple. Stage 2 changes this to
# "x86_64-rovelstars-runixos" once a RunixOS sysroot is available.
# set(LLVM_RUNTIME_TARGETS "default" CACHE STRING "" FORCE)

# ── Builtins ──────────────────────────────────────────────────────────────────
# Stage 1: build builtins for the host only ("default" = host triple).
# In Stage 2:
#   set(LLVM_BUILTIN_TARGETS "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-runixos_RovelStars               ON           CACHE BOOL   "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR     "Core/LibKit" CACHE STRING "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_INSTALL_BINDIR     "Core/Bin"    CACHE STRING "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT            "/path/to/runixos-sysroot" CACHE PATH "" FORCE)
# AArch64 (Stage 2/3 only, requires its own sysroot):
#   set(BUILTINS_aarch64-rovelstars-runixos_RovelStars               ON           CACHE BOOL   "" FORCE)
#   set(BUILTINS_aarch64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR     "Core/LibKit" CACHE STRING "" FORCE)
#   set(BUILTINS_aarch64-rovelstars-runixos_CMAKE_SYSROOT            "/path/to/aarch64-sysroot" CACHE PATH "" FORCE)
set(LLVM_BUILTIN_TARGETS "default" CACHE STRING "" FORCE)

# ── Feature flags ─────────────────────────────────────────────────────────────
set(LLVM_ENABLE_WERROR        OFF CACHE BOOL "" FORCE)
set(LLVM_ENABLE_ASSERTIONS    OFF CACHE BOOL "" FORCE)
set(LLVM_ENABLE_PIC            ON CACHE BOOL "" FORCE)
set(LLVM_ENABLE_ZLIB           ON CACHE BOOL "" FORCE)
set(LLVM_ENABLE_ZSTD           ON CACHE BOOL "" FORCE)
set(LLVM_ENABLE_LIBCXX        OFF CACHE BOOL "" FORCE)
set(LLVM_OPTIMIZED_TABLEGEN    ON CACHE BOOL "" FORCE)
set(LLVM_INCLUDE_DOCS         OFF CACHE BOOL "" FORCE)
set(LLVM_INCLUDE_EXAMPLES     OFF CACHE BOOL "" FORCE)
set(LLVM_INCLUDE_TESTS         ON CACHE BOOL "" FORCE)
set(LLVM_BUILD_TESTS          OFF CACHE BOOL "" FORCE)
set(LLVM_PARALLEL_LINK_JOBS     4 CACHE STRING "" FORCE)

# ── RunixOS filesystem hierarchy install paths ───────────────────────────────
# RunixOS does not follow the GNU/FHS layout. All paths are set as literal
# strings so they resolve correctly when the cache is first loaded (before
# GNUInstallDirs variables are computed by CMake).
#
# RunixOS filesystem layout:
#   Binaries   -> Core/Bin
#   Libraries  -> Core/LibKit
#   Headers    -> Core/APIHeader
#   Data       -> Core/Data
#   Config     -> Core/Config
#   Man pages  -> Core/Data/man
#
set(CMAKE_INSTALL_BINDIR        "Core/Bin"           CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SBINDIR       "Core/Bin"           CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBDIR        "Core/LibKit"        CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBEXECDIR    "Core/LibKit"        CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INCLUDEDIR    "Core/APIHeader"     CACHE STRING "" FORCE)
set(CMAKE_INSTALL_DATADIR       "Core/Data"          CACHE STRING "" FORCE)
set(CMAKE_INSTALL_MANDIR        "Core/Data/man"      CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SYSCONFDIR    "Core/Config"        CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INFODIR       "Core/Data/info"     CACHE STRING "" FORCE)

# ── LLVM / Clang / LLD CMake package install dirs ────────────────────────────
# These must be concrete paths — variable references like ${CMAKE_INSTALL_LIBDIR}
# are not resolved when the cache file is loaded before GNUInstallDirs runs.
set(LLVM_INSTALL_PACKAGE_DIR    "Core/LibKit/cmake/llvm"   CACHE STRING "" FORCE)
set(CLANG_INSTALL_PACKAGE_DIR   "Core/LibKit/cmake/clang"  CACHE STRING "" FORCE)
set(LLD_INSTALL_PACKAGE_DIR     "Core/LibKit/cmake/lld"    CACHE STRING "" FORCE)

# Clang resource dir and lib dir basename (used by Driver::GetResourcesPath).
set(CLANG_INSTALL_LIBDIR_BASENAME "Core/LibKit"            CACHE STRING "" FORCE)

# ── Runtime install overrides ────────────────────────────────────────────────
set(LIBUNWIND_INSTALL_INCLUDE_DIR "Core/APIHeader"         CACHE STRING "" FORCE)

# ── Runtimes sub-build initial cache ─────────────────────────────────────────
# RovelStars-runtimes.cmake is loaded by the runtimes ExternalProject sub-cmake
# via -C (initial cache). It mirrors the RunixOS install layout into the
# runtimes sub-build and documents the stage-1 host-triple override rationale.
set(RUNTIMES_CACHE_FILES "${CMAKE_CURRENT_LIST_DIR}/RovelStars-runtimes.cmake" CACHE STRING "" FORCE)
