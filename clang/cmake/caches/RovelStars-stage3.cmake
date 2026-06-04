# RovelStars/RunixOS LLVM Build Cache - Stage 3
#
# Stage 3 of the 3-stage RunixOS LLVM bootstrap.
#
# ── Two modes ────────────────────────────────────────────────────────────────
#
# FAST / VERIFICATION MODE (default, ROVELSTARS_STAGE3_FAST=ON)
# ─────────────────────────────────────────────────────────────
# Builds only clang+lld with no LTO and no PGO.  Goal: confirm the 3-stage
# pipeline compiles for RunixOS as fast as possible.  Build time ~same as
# Stage 1/2.
#
#   cmake -G Ninja \
#     -C clang/cmake/caches/RovelStars-stage3.cmake \
#     -DCMAKE_C_COMPILER=/path/to/build/stage1/bin/clang \
#     -DCMAKE_CXX_COMPILER=/path/to/build/stage1/bin/clang++ \
#     -DLLVM_USE_LINKER=/path/to/build/stage2/Core/Bin/ld.lld \
#     -DRUNTIMES_x86_64-rovelstars-linux-runixos_CMAKE_SYSROOT=/path/to/sysroot \
#     -DBUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_SYSROOT=/path/to/sysroot \
#     -DCMAKE_INSTALL_PREFIX=/RunixOS \
#     -B build/stage3 llvm
#
# FULL / OPTIMISED MODE (ROVELSTARS_STAGE3_FAST=OFF)
# ───────────────────────────────────────────────────
# ThinLTO + PGO USE - the real release-quality toolchain.  Requires a merged
# .profdata file from Stage 2 profile collection.  Takes several hours.
#
#   cmake -G Ninja \
#     -C clang/cmake/caches/RovelStars-stage3.cmake \
#     -DROVELSTARS_STAGE3_FAST=OFF \
#     -DCMAKE_C_COMPILER=/path/to/build/stage1/bin/clang \
#     -DCMAKE_CXX_COMPILER=/path/to/build/stage1/bin/clang++ \
#     -DLLVM_USE_LINKER=/path/to/build/stage2/Core/Bin/ld.lld \
#     -DLLVM_PROFDATA_FILE=/path/to/build/pgo-profiles/stage2.profdata \
#     -DRUNTIMES_x86_64-rovelstars-linux-runixos_CMAKE_SYSROOT=/path/to/sysroot \
#     -DBUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_SYSROOT=/path/to/sysroot \
#     -DCMAKE_INSTALL_PREFIX=/RunixOS \
#     -B build/stage3 llvm
#
# !! IMPORTANT: Do NOT pass -DCMAKE_SYSROOT= at the top level. !!
#    Pass the sysroot only via RUNTIMES_* and BUILTINS_* per-target -D args.
#
# Stage 3 vs Stage 2 differences
# ────────────────────────────────
#   Stage 2  - instrumented (PGO GEN), no LTO, profile collection
#   Stage 3  - fast mode: no LTO/PGO; full mode: PGO USE + ThinLTO

# ── Fast/verification mode toggle ────────────────────────────────────────────
option(ROVELSTARS_STAGE3_FAST
  "Build Stage 3 without LTO or PGO for fast pipeline verification" ON)

# ── Inherit base RovelStars settings ─────────────────────────────────────────
# Pulls in: vendor branding, feature flags, RunixOS FHS install paths,
# LLVM/Clang/LLD package dirs, and RUNTIMES_CACHE_FILES.
# In fast mode we override LLVM_ENABLE_PROJECTS to clang+lld only.
include(${CMAKE_CURRENT_LIST_DIR}/RovelStars.cmake)

# Fast mode: build only clang and lld - the minimum needed to verify the
# 3-stage pipeline produces a working RunixOS-targeting toolchain.
if(ROVELSTARS_STAGE3_FAST)
  set(LLVM_ENABLE_PROJECTS "clang;lld" CACHE STRING "" FORCE)
  message(STATUS "RovelStars Stage 3: FAST/verification mode - "
    "clang+lld only, no LTO, no PGO.  "
    "Pass -DROVELSTARS_STAGE3_FAST=OFF for the full optimised build.")
endif()

# ── Bypass libstdc++ version check ───────────────────────────────────────────
# (Applies in both fast and full mode - same root cause either way.)
# CheckCompilerVersion.cmake runs check_cxx_source_compiles (compile+link) to
# verify libstdc++ is at least version 7.4.  The link step fails when
# CMAKE_SHARED_LIBRARY_SUFFIX=.rdl (set by llvm/CMakeLists.txt when RovelStars=ON)
# because cmake resolves -lstdc++ to libstdc++.rdl which doesn't exist on the
# Linux build host.
#
# Pre-asserting LLVM_LIBSTDCXX_MIN=1 makes CheckCompilerVersion.cmake skip the
# failing compile/link test (the if(NOT LLVM_LIBSTDCXX_MIN) FATAL_ERROR is never
# reached).  This is correct: the host system has a modern enough libstdc++,
# and RunixOS itself uses libc++ rather than libstdc++ anyway.
#
# We intentionally do NOT set LLVM_ENABLE_LIBCXX=ON here: that would cause all
# stage3 host-executed build tools (tblgen, clang-tidy-confusable-chars-gen, etc.)
# to link against libc++.so.1, which is not installed on the Linux build host,
# causing "cannot open shared object file" errors at build time.
set(LLVM_LIBSTDCXX_MIN        1 CACHE INTERNAL "pre-asserted: bypass version check" FORCE)
set(LLVM_LIBSTDCXX_SOFT_ERROR 1 CACHE INTERNAL "pre-asserted: bypass version check" FORCE)

# ── RovelStars identity flag ──────────────────────────────────────────────────
# Must be set explicitly when cross-compiling from a non-RunixOS host.
set(RovelStars ON CACHE BOOL "" FORCE)

# ── Compilers (Stage 2 binaries) ─────────────────────────────────────────────
# The caller MUST pass these on the cmake command line:
#   -DCMAKE_C_COMPILER=/path/to/build/stage2/Core/Bin/clang
#   -DCMAKE_CXX_COMPILER=/path/to/build/stage2/Core/Bin/clang++
# The base RovelStars.cmake no longer sets bare "clang"/"clang++" to avoid
# overriding the caller's explicit paths.

# ── Linker (Stage 2 ld.lld) ──────────────────────────────────────────────────
# Use the Stage 2-built lld.  The caller passes:
#   -DLLVM_USE_LINKER=/path/to/build/stage2/Core/Bin/ld.lld
# This is the first stage where we can use the self-hosted RunixOS lld,
# eliminating the "taking a path is deprecated" warning from earlier stages.

# ── Default target triple ─────────────────────────────────────────────────────
# Stage 3 targets RunixOS natively, same as Stage 2.
set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-rovelstars-linux-runixos" CACHE STRING "" FORCE)

# ── Runtime and builtin targets ───────────────────────────────────────────────
set(LLVM_RUNTIME_TARGETS "x86_64-rovelstars-linux-runixos" CACHE STRING "" FORCE)
set(LLVM_BUILTIN_TARGETS "x86_64-rovelstars-linux-runixos" CACHE STRING "" FORCE)

# AArch64 - uncomment once an aarch64-rovelstars-linux-runixos sysroot is available:
# set(LLVM_RUNTIME_TARGETS
#   "x86_64-rovelstars-linux-runixos;aarch64-rovelstars-linux-runixos" CACHE STRING "" FORCE)
# set(LLVM_BUILTIN_TARGETS
#   "x86_64-rovelstars-linux-runixos;aarch64-rovelstars-linux-runixos" CACHE STRING "" FORCE)

# ── PGO and LTO ───────────────────────────────────────────────────────────────
# Fast mode:  no PGO, no LTO - fastest possible build.
# Full mode:  PGO USE (from Stage 2 profiles) + ThinLTO.
set(LLVM_BUILD_INSTRUMENTED OFF CACHE STRING "" FORCE)

if(ROVELSTARS_STAGE3_FAST)
  # No LTO - avoids the multi-hour ThinLTO code-generation phase that makes
  # Stage 3 full-mode so slow.  The resulting toolchain is functionally
  # identical; only peak performance is lower.
  set(LLVM_ENABLE_LTO        OFF  CACHE STRING "" FORCE)
  # Disable runtimes and builtins for pipeline verification.
  # Without this, the default builtins target tries to cross-compile i386
  # compiler-rt builtins using the RunixOS sysroot headers which don't support
  # i386 (__float128 / __TC__ mode errors).
  set(LLVM_RUNTIME_TARGETS   ""   CACHE STRING "" FORCE)
  set(LLVM_BUILTIN_TARGETS   ""   CACHE STRING "" FORCE)
  set(LLVM_ENABLE_RUNTIMES   ""   CACHE STRING "" FORCE)
  set(COMPILER_RT_BUILD_BUILTINS OFF CACHE BOOL "" FORCE)
else()
  # Full optimised mode: ThinLTO + PGO USE.
  # Caller MUST pass: -DLLVM_PROFDATA_FILE=/path/to/stage2.profdata
  # LLVM_PROFDATA_FILE is intentionally not set here (must be absolute path).
  set(LLVM_ENABLE_LTO "Thin" CACHE STRING "" FORCE)
endif()

# ── compiler-rt / runtime library settings ────────────────────────────────────
# Same as Stage 2: use LLVM's unwinder and builtins, libc++abi for sanitizers.
set(COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(COMPILER_RT_ENABLE_STATIC_UNWINDER OFF CACHE BOOL "" FORCE)
set(COMPILER_RT_USE_BUILTINS_LIBRARY ON CACHE BOOL "" FORCE)
set(SANITIZER_CXX_ABI "libcxxabi" CACHE STRING "" FORCE)
set(SANITIZER_CXX_ABI_INTREE ON CACHE BOOL "" FORCE)
set(COMPILER_RT_CXX_LIBRARY "libcxx" CACHE STRING "" FORCE)

# Per-target RUNTIMES_ passthroughs (same as Stage 2).
set(RUNTIMES_x86_64-rovelstars-linux-runixos_COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_COMPILER_RT_ENABLE_STATIC_UNWINDER OFF CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_COMPILER_RT_USE_BUILTINS_LIBRARY ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_LIBCXXABI_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_LIBCXXABI_USE_COMPILER_RT   ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_LIBCXX_USE_COMPILER_RT      ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_LIBUNWIND_USE_COMPILER_RT   ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_COMPILER_RT_CXX_LIBRARY "libcxx" CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_SANITIZER_CXX_ABI         "libcxxabi" CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_SANITIZER_CXX_ABI_INTREE  ON          CACHE BOOL   "" FORCE)

# RovelStars flag must also be forwarded per-target so the runtimes cmake
# variable scan (get_cmake_property VARIABLES) picks it up and passes it
# as -DRovelStars=ON to the runtimes sub-cmake.  Without this, GetClangResourceDir
# uses the non-RovelStars path and computes wrong compiler-rt output dirs.
set(RUNTIMES_x86_64-rovelstars-linux-runixos_RovelStars ON CACHE BOOL "" FORCE)

# cmake package discovery path for find_package(LLVM) in the runtimes sub-build.
# These absolute paths ensure that runtimes/CMakeLists.txt sets LLVM_TREE_AVAILABLE=ON
# and uses the top-level build dir's Core/LibKit for LLVM_LIBRARY_OUTPUT_INTDIR.
# Without them the fallback in runtimes/CMakeLists.txt sets LLVM_LIBRARY_DIR to a
# path relative to the runtimes binary dir, causing compiler-rt output-directory
# calculations to produce doubled/wrong paths (e.g. Core/LibKit/../lib/clang/23
# instead of Core/LibKit/clang/23).
set(RUNTIMES_x86_64-rovelstars-linux-runixos_CMAKE_PREFIX_PATH
  "${CMAKE_BINARY_DIR}/Core/LibKit" CACHE PATH "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_LLVM_LIBRARY_DIR
  "${CMAKE_BINARY_DIR}/Core/LibKit" CACHE PATH "" FORCE)
set(RUNTIMES_x86_64-rovelstars-linux-runixos_LLVM_TOOLS_BINARY_DIR
  "${CMAKE_BINARY_DIR}/Core/Bin" CACHE PATH "" FORCE)

# ── Builtins per-target settings ──────────────────────────────────────────────
set(BUILTINS_x86_64-rovelstars-linux-runixos_RovelStars               ON           CACHE BOOL   "" FORCE)
set(BUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_INSTALL_LIBDIR     "Core/LibKit" CACHE STRING "" FORCE)
set(BUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_INSTALL_BINDIR     "Core/Bin"    CACHE STRING "" FORCE)
# Sysroot is supplied by the caller via:
#   -DBUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_SYSROOT=/path/to/sysroot

# ── RunixOS FHS install paths ─────────────────────────────────────────────────
# Same layout as Stage 2.  Explicitly restated here for self-documentation.
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
set(LLVM_INSTALL_PACKAGE_DIR    "Core/LibKit/cmake/llvm"   CACHE STRING "" FORCE)
set(CLANG_INSTALL_PACKAGE_DIR   "Core/LibKit/cmake/clang"  CACHE STRING "" FORCE)
set(LLD_INSTALL_PACKAGE_DIR     "Core/LibKit/cmake/lld"    CACHE STRING "" FORCE)
set(CLANG_INSTALL_LIBDIR_BASENAME "Core/LibKit"            CACHE STRING "" FORCE)
set(LIBUNWIND_INSTALL_INCLUDE_DIR "Core/APIHeader"         CACHE STRING "" FORCE)

# ── Runtimes sub-build initial cache ─────────────────────────────────────────
# RovelStars-runtimes.cmake handles: RunixOS install layout, compiler-works
# bypass for bootstrapping, libunwind/libcxxabi flags, and SANITIZER_CXX_ABI.
set(RUNTIMES_CACHE_FILES "${CMAKE_CURRENT_LIST_DIR}/RovelStars-runtimes.cmake" CACHE STRING "" FORCE)
