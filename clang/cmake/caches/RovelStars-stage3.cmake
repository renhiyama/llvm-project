# RovelStars/RunixOS LLVM Build Cache - Stage 3
#
# Stage 3 of the 3-stage RunixOS LLVM bootstrap.
#
# Overview
# --------
# Stage 2 produced an instrumented toolchain that collected PGO profiles
# during its own build (and any additional workloads you ran through it).
# Stage 3 uses those merged profiles to produce the final, fully
# profile-guided-optimised RunixOS-native LLVM toolchain.
#
# Prerequisites
# -------------
#   1. Stage 2 built and profiled successfully:
#        build/stage2/Core/Bin/clang
#        build/stage2/Core/Bin/ld.lld
#   2. PGO profiles merged into a single .profdata file:
#        build/stage2/Core/Bin/llvm-profdata merge \
#          -output=build/pgo-profiles/stage2.profdata \
#          build/stage2/profiles/*.profraw
#      (The build itself already emits profiles; run additional workloads
#       like compiling a RunixOS package tree for richer coverage.)
#   3. A RunixOS x86_64 sysroot (same one used for Stage 2):
#        /home/ren/coding/rovelos/sysroot-runixos  (or wherever yours lives)
#
# Invocation
# ----------
#   cmake -G Ninja \
#     -C clang/cmake/caches/RovelStars-stage3.cmake \
#     -DCMAKE_C_COMPILER=/path/to/build/stage2/Core/Bin/clang \
#     -DCMAKE_CXX_COMPILER=/path/to/build/stage2/Core/Bin/clang++ \
#     -DLLVM_USE_LINKER=/path/to/build/stage2/Core/Bin/ld.lld \
#     -DLLVM_PROFDATA_FILE=/path/to/build/pgo-profiles/stage2.profdata \
#     -DRUNTIMES_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/sysroot \
#     -DBUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/sysroot \
#     -DCMAKE_INSTALL_PREFIX=/RunixOS \
#     -B build/stage3 \
#     llvm
#
# !! IMPORTANT: Do NOT pass -DCMAKE_SYSROOT= at the top level. !!
#    See RovelStars-stage2.cmake for the full explanation.  Pass the sysroot
#    only via the per-target RUNTIMES_* and BUILTINS_* -D variables above.
#
# Outputs
# -------
#   The final optimised RunixOS-native toolchain installed under
#   CMAKE_INSTALL_PREFIX using the RunixOS FHS layout:
#     Core/Bin/         — clang, clang++, lld, lldb, llvm-* tools
#     Core/LibKit/      — shared/static libraries, compiler-rt, libc++, etc.
#     Core/APIHeader/   — C/C++ headers
#     Core/Data/        — data files, man pages
#     Core/Config/      — configuration files
#
# Stage 3 vs Stage 2 differences
# --------------------------------
#   Stage 2  — instrumented (PGO GEN), no LTO, for profile collection only
#   Stage 3  — PGO USE + ThinLTO, release-quality, no instrumentation overhead

# ── Inherit base RovelStars settings ─────────────────────────────────────────
# Pulls in: sub-project list, vendor branding, feature flags, RunixOS FHS
# install paths, LLVM/Clang/LLD package dirs, and RUNTIMES_CACHE_FILES.
# NOTE: RovelStars.cmake intentionally leaves LLVM_DEFAULT_TARGET_TRIPLE
# unset (host default) for Stage 1 safety. We override it explicitly below.
include(${CMAKE_CURRENT_LIST_DIR}/RovelStars.cmake)

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
set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)

# ── Runtime and builtin targets ───────────────────────────────────────────────
set(LLVM_RUNTIME_TARGETS "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)
set(LLVM_BUILTIN_TARGETS "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)

# AArch64 — uncomment once an aarch64-rovelstars-runixos sysroot is available:
# set(LLVM_RUNTIME_TARGETS
#   "x86_64-rovelstars-runixos;aarch64-rovelstars-runixos" CACHE STRING "" FORCE)
# set(LLVM_BUILTIN_TARGETS
#   "x86_64-rovelstars-runixos;aarch64-rovelstars-runixos" CACHE STRING "" FORCE)

# ── PGO: consume the Stage 2 profiles ────────────────────────────────────────
# The caller MUST pass: -DLLVM_PROFDATA_FILE=/path/to/stage2.profdata
# LLVM_BUILD_INSTRUMENTED must be OFF (no new instrumentation in Stage 3).
set(LLVM_BUILD_INSTRUMENTED OFF CACHE STRING "" FORCE)

# HandleLLVMOptions.cmake reads LLVM_PROFDATA_FILE and adds
# -fprofile-instr-use="<path>" to CMAKE_C_FLAGS / CMAKE_CXX_FLAGS.
# LLVM_PROFDATA_FILE is intentionally not set here because it must be an
# absolute path supplied by the caller via -D.

# ── LTO ───────────────────────────────────────────────────────────────────────
# Enable ThinLTO for Stage 3 now that compiler and linker are self-hosted.
# Stage 2 lld (ld.lld from build/stage2/Core/Bin/) fully supports ThinLTO
# summary version 13 emitted by the Stage 2 clang, so the version mismatch
# that blocked LTO in Stage 2 no longer applies.
set(LLVM_ENABLE_LTO "Thin" CACHE STRING "" FORCE)

# ── compiler-rt / runtime library settings ────────────────────────────────────
# Same as Stage 2: use LLVM's unwinder and builtins, libc++abi for sanitizers.
set(COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(COMPILER_RT_ENABLE_STATIC_UNWINDER OFF CACHE BOOL "" FORCE)
set(COMPILER_RT_USE_BUILTINS_LIBRARY ON CACHE BOOL "" FORCE)
set(SANITIZER_CXX_ABI "libcxxabi" CACHE STRING "" FORCE)
set(SANITIZER_CXX_ABI_INTREE ON CACHE BOOL "" FORCE)
set(COMPILER_RT_CXX_LIBRARY "libcxx" CACHE STRING "" FORCE)

# Per-target RUNTIMES_ passthroughs (same as Stage 2).
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_ENABLE_STATIC_UNWINDER OFF CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_USE_BUILTINS_LIBRARY ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBCXXABI_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBCXXABI_USE_COMPILER_RT   ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBCXX_USE_COMPILER_RT      ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBUNWIND_USE_COMPILER_RT   ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_CXX_LIBRARY "libcxx" CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_SANITIZER_CXX_ABI         "libcxxabi" CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_SANITIZER_CXX_ABI_INTREE  ON          CACHE BOOL   "" FORCE)

# cmake package discovery path for find_package(LLVM) in the runtimes sub-build.
set(RUNTIMES_x86_64-rovelstars-runixos_CMAKE_PREFIX_PATH
  "${CMAKE_BINARY_DIR}/Core/LibKit" CACHE PATH "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LLVM_LIBRARY_DIR
  "${CMAKE_BINARY_DIR}/Core/LibKit" CACHE PATH "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LLVM_TOOLS_BINARY_DIR
  "${CMAKE_BINARY_DIR}/Core/Bin" CACHE PATH "" FORCE)

# ── Builtins per-target settings ──────────────────────────────────────────────
set(BUILTINS_x86_64-rovelstars-runixos_RovelStars               ON           CACHE BOOL   "" FORCE)
set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR     "Core/LibKit" CACHE STRING "" FORCE)
set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_INSTALL_BINDIR     "Core/Bin"    CACHE STRING "" FORCE)
# Sysroot is supplied by the caller via:
#   -DBUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/sysroot

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
