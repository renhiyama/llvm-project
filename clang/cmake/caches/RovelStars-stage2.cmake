# RovelStars/RunixOS LLVM Build Cache - Stage 2
#
# Stage 2 of the 3-stage RunixOS bootstrap.
#
# Overview
# --------
# Stage 1 produced a host-native clang/lld in build/stage1/. This cache
# uses that toolchain to cross-compile LLVM and its runtimes targeting
# x86_64-rovelstars-runixos, with a RunixOS sysroot supplied by the caller.
# The resulting toolchain is instrumented for PGO so that Stage 3 can
# produce a fully profile-guided-optimised release toolchain.
#
# Prerequisites
# -------------
#   1. Stage 1 built successfully:
#        build/stage1/bin/clang
#        build/stage1/bin/clang++
#        build/stage1/bin/ld.lld
#   2. A RunixOS x86_64 sysroot image available on the build host.
#      Pass its path as -DCMAKE_SYSROOT=<path> on the cmake command line.
#      The same path is forwarded automatically to the runtimes and builtins
#      sub-builds via the per-target RUNTIMES_*/BUILTINS_* variables below.
#
# Invocation
# ----------
#   cmake -G Ninja \
#     -C clang/cmake/caches/RovelStars-stage2.cmake \
#     -DCMAKE_C_COMPILER=/path/to/build/stage1/bin/clang \
#     -DCMAKE_CXX_COMPILER=/path/to/build/stage1/bin/clang++ \
#     -DLLVM_USE_LINKER=/path/to/build/stage1/bin/ld.lld \
#     -DRUNTIMES_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/runixos-sysroot \
#     -DBUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/runixos-sysroot \
#     -DCMAKE_INSTALL_PREFIX=/path/to/install \
#     llvm
#
# !! IMPORTANT: Do NOT pass -DCMAKE_SYSROOT=... at the top level. !!
#
#   Passing CMAKE_SYSROOT at the top level forces ALL CMake compiler-
#   capability tests (CheckAtomic, CheckCompilerVersion, etc.) to run
#   against the RunixOS sysroot, where libstdc++, libatomic, and other
#   host-assumed libraries do not exist. This causes configure to fail
#   before LLVM's own cmake logic even runs.
#
#   Instead, the sysroot is forwarded *only* to the runtimes and builtins
#   ExternalProject sub-builds via the per-target variables below:
#     -DRUNTIMES_x86_64-rovelstars-runixos_CMAKE_SYSROOT=...
#     -DBUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT=...
#
#   The top-level LLVM build (clang, lld, llvm-lib, etc.) is compiled by
#   the stage1 host clang targeting the host triple — no sysroot needed.
#   Only the runtime libraries (libc++, libunwind, compiler-rt, openmp)
#   and builtins are cross-compiled for x86_64-rovelstars-runixos with
#   the RunixOS sysroot.
#
# Outputs
# -------
#   - A RunixOS-native LLVM toolchain installed under CMAKE_INSTALL_PREFIX
#     using the RunixOS FHS layout (Core/Bin, Core/LibKit, Core/APIHeader, …).
#   - PGO instrumentation profiles written to the directory specified by
#     LLVM_PROFILE_DATA_DIR (defaults to build/stage2/profiles/).
#
# Stage 3
# -------
#   Stage 3 consumes the PGO profiles generated here to produce the final
#   fully-optimised toolchain. Pass the profile directory to Stage 3 via
#   -DLLVM_PROFDATA_FILE=/path/to/merged.profdata after merging with:
#     llvm-profdata merge -output=merged.profdata build/stage2/profiles/*.profraw

# ── Inherit base RovelStars settings ─────────────────────────────────────────
# Pulls in: sub-project list, vendor branding, feature flags, RunixOS FHS
# install paths, LLVM/Clang/LLD package dirs, and RUNTIMES_CACHE_FILES.
# NOTE: RovelStars.cmake intentionally leaves LLVM_DEFAULT_TARGET_TRIPLE
# unset (host default) for Stage 1 safety. We override it explicitly below.
include(${CMAKE_CURRENT_LIST_DIR}/RovelStars.cmake)

# ── RovelStars identity flag ──────────────────────────────────────────────────
# Must be set explicitly for cross-compilation FROM a Linux host.
# When building natively ON RunixOS, cmake/Modules/Platform/RovelStars-Initialize.cmake
# sets this automatically. When cross-compiling from Linux (as in Stage 2), the
# Linux platform module runs instead and the flag is never set — so clang/CMakeLists.txt
# and llvm/CMakeLists.txt never enter their RunixOS-specific branches.
# Consequences of not setting it:
#   - CLANG_INSTALL_LIBDIR_BASENAME defaults to "lib" instead of "LibKit",
#     causing clang's resource dir (where omp.h, omp-tools.h etc. live) to be
#     build/stage2/lib/clang/23 rather than build/stage2/Core/LibKit/clang/23.
#     OpenMP and other runtimes then fail to find their generated headers.
#   - Output and library directories don't follow the RunixOS FHS.
set(RovelStars ON CACHE BOOL "" FORCE)

# ── Compilers (Stage 1 binaries) ──────────────────────────────────────────────
# The caller MUST pass these on the cmake command line, for example:
#
#   -DCMAKE_C_COMPILER=/path/to/build/stage1/bin/clang
#   -DCMAKE_CXX_COMPILER=/path/to/build/stage1/bin/clang++
#
# The build directory varies per developer/CI machine, so no hardcoded path
# is set here. The include() above sets CMAKE_C_COMPILER/CMAKE_CXX_COMPILER
# to the bare "clang"/"clang++" host shims; the -D arguments on the command
# line override those to the stage1 binaries with the highest CMake priority.

# ── Linker (Stage 1 ld.lld) ───────────────────────────────────────────────────
# Use --ld-path= (the non-deprecated spelling) instead of -fuse-ld=.
# The caller MUST pass the absolute path on the cmake command line, e.g.:
#
#   -DLLVM_USE_LINKER=/path/to/build/stage1/bin/ld.lld
#
# LLVM_USE_LINKER accepts either a linker name or an absolute path; an
# absolute path causes the driver to emit --ld-path=<abs> rather than
# -fuse-ld=<name>, which avoids the deprecation warning emitted by stage1
# clang when it processes -fuse-ld=lld.
# The RovelStars.cmake base already sets LLVM_ENABLE_LLD OFF; that is kept
# so the two settings do not conflict.

# ── Target triple ─────────────────────────────────────────────────────────────
# Stage 2 targets RunixOS natively. A sysroot is required (passed by the
# caller via -DCMAKE_SYSROOT=…) so that CRT / runtime link tests succeed.
set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)

# ── Runtime targets ───────────────────────────────────────────────────────────
set(LLVM_RUNTIME_TARGETS "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)

# ── Builtin targets ───────────────────────────────────────────────────────────
set(LLVM_BUILTIN_TARGETS "x86_64-rovelstars-runixos" CACHE STRING "" FORCE)
# AArch64 variant — uncomment when an aarch64-rovelstars-runixos sysroot is
# available and add "aarch64-rovelstars-runixos" to the list above:
# set(LLVM_BUILTIN_TARGETS
#   "x86_64-rovelstars-runixos;aarch64-rovelstars-runixos" CACHE STRING "" FORCE)

# ── LTO ───────────────────────────────────────────────────────────────────────
# LTO is disabled for stage 2 bootstrap builds.
#
# Rationale: LLVM_ENABLE_LTO causes ALL objects (including cmake configure-time
# try_compile tests) to be emitted as ThinLTO bitcode. The cmake tests are linked
# by LLVM_USE_LINKER (the stage1 system ld.lld v22), but the stage2 clang (v23)
# produces ThinLTO summary version 13 which the old system lld v22 cannot read:
#   ld.lld: error: Invalid summary version 13. Version should be in the range [1-12]
# This causes every check_c_source_compiles() test in polly/ISL and elsewhere to
# fail at configure time, aborting the build.
#
# To re-enable LTO for a specific build, pass -DLLVM_ENABLE_LTO=Thin on the cmake
# command line AFTER a stage2 ld.lld is available and set as LLVM_USE_LINKER.
# For a proper 3-stage bootstrap, LTO belongs in stage 3 where the compiler and
# linker are both self-hosted RunixOS binaries.
# set(LLVM_ENABLE_LTO "Thin" CACHE STRING "" FORCE)

# ── PGO instrumentation ───────────────────────────────────────────────────────
# GEN mode instruments the stage 2 binaries. Run the desired workloads
# (e.g. compiling a RunixOS userspace tree) after install to collect
# *.profraw files, then merge them with llvm-profdata and pass the result
# to Stage 3 via -DLLVM_PROFDATA_FILE=<merged.profdata>.
set(LLVM_ENABLE_PGO "GEN" CACHE STRING "" FORCE)

# ── compiler-rt / runtime library settings ────────────────────────────────────
# These are passed through to the runtimes ExternalProject sub-build via the
# COMPILER_RT PASSTHROUGH_PREFIXES mechanism in llvm/runtimes/CMakeLists.txt.
# Without these, Scudo's GWP-ASan component aborts configure with
# "No suitable unwinder library" because it can't find libgcc_s on RunixOS.
set(COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(COMPILER_RT_ENABLE_STATIC_UNWINDER OFF CACHE BOOL "" FORCE)
# Also set per-target so the runtimes ExternalProject runtime_register_target
# machinery picks it up directly (the COMPILER_RT PASSTHROUGH_PREFIXES scan
# only forwards variables that are in CMake's variable list at generation time;
# the explicit per-target form is always forwarded).
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_ENABLE_STATIC_UNWINDER OFF CACHE BOOL "" FORCE)
# libcxx/libcxxabi/libunwind: use compiler-rt and LLVM unwinder on RunixOS.
# Also forwarded per-target to ensure they reach the runtimes sub-cmake.
set(RUNTIMES_x86_64-rovelstars-runixos_LIBCXXABI_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBCXXABI_USE_COMPILER_RT   ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBCXX_USE_COMPILER_RT      ON CACHE BOOL "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LIBUNWIND_USE_COMPILER_RT   ON CACHE BOOL "" FORCE)
# Pass the top-level LLVM library and tools directories to the runtimes sub-build.
#
# Background: runtimes/CMakeLists.txt calls find_package(LLVM PATHS "${LLVM_BINARY_DIR}")
# to discover LLVM_LIBRARY_DIR and LLVM_TOOLS_BINARY_DIR. On a standard Linux build the
# cmake package files live in build/stage2/lib/cmake/llvm/, but on RunixOS they are
# installed to build/stage2/Core/LibKit/cmake/llvm/. Because find_package uses the
# standard lib/cmake search path it fails (LLVM_FOUND=OFF), and the fallback in
# runtimes/CMakeLists.txt computes LLVM_LIBRARY_DIR as a path RELATIVE to the runtimes
# binary dir. This causes all compiler-rt output-directory calculations inside the
# runtimes cmake (which use LLVM_LIBRARY_DIR as an anchor) to be wrong — the builtins
# sources file ends up at a relative unresolvable path inside the runtimes binary dir.
#
# Fixes:
#   1. Pass CMAKE_PREFIX_PATH pointing to the RunixOS cmake package root so
#      find_package(LLVM) succeeds and LLVM_FOUND=ON.
#   2. Also pass LLVM_LIBRARY_DIR and LLVM_TOOLS_BINARY_DIR explicitly as absolute
#      paths so the runtimes cmake can set LLVM_TREE_AVAILABLE=ON even if
#      find_package somehow still fails.
set(RUNTIMES_x86_64-rovelstars-runixos_CMAKE_PREFIX_PATH
  "${CMAKE_BINARY_DIR}/Core/LibKit" CACHE PATH "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LLVM_LIBRARY_DIR
  "${CMAKE_BINARY_DIR}/Core/LibKit" CACHE PATH "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_LLVM_TOOLS_BINARY_DIR
  "${CMAKE_BINARY_DIR}/Core/Bin" CACHE PATH "" FORCE)
# compiler-rt needs to know to use libc++ (not libstdc++) for C++ ABI symbols
# (typeinfo, dynamic_cast, etc.) on RunixOS. Without this, sanitizer shared libs
# (ubsan_standalone, asan, etc.) fail to link with "undefined symbol: typeinfo for
# std::type_info" because they default to libstdc++ which doesn't exist on RunixOS.
set(RUNTIMES_x86_64-rovelstars-runixos_COMPILER_RT_CXX_LIBRARY "libcxx" CACHE STRING "" FORCE)
set(COMPILER_RT_CXX_LIBRARY "libcxx" CACHE STRING "" FORCE)
# Tell sanitizers to use libc++abi for C++ ABI support (typeinfo, dynamic_cast).
# Without this SANITIZER_CXX_ABI defaults to "default" which resolves to libstdc++
# on Linux-like systems — but RunixOS has no libstdc++. Setting INTREE tells
# compiler-rt to link against the libc++abi being built in the same runtimes batch.
set(RUNTIMES_x86_64-rovelstars-runixos_SANITIZER_CXX_ABI         "libc++abi" CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_SANITIZER_CXX_ABI_INTREE  ON          CACHE BOOL   "" FORCE)
set(SANITIZER_CXX_ABI        "libc++abi" CACHE STRING "" FORCE)
set(SANITIZER_CXX_ABI_INTREE ON          CACHE BOOL   "" FORCE)

# ── RunixOS FHS install paths (stage 2 override / explicit restatement) ───────
# RovelStars.cmake already sets these; they are repeated here for clarity and
# to make the stage 2 cache self-documenting. FORCE ensures they win even if
# a user's environment has conflicting cache entries.
set(CMAKE_INSTALL_BINDIR        "Core/Bin"           CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SBINDIR       "Core/Bin"           CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBDIR        "Core/LibKit"        CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBEXECDIR    "Core/LibKit"        CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INCLUDEDIR    "Core/APIHeader"     CACHE STRING "" FORCE)
set(CMAKE_INSTALL_DATADIR       "Core/Data"          CACHE STRING "" FORCE)
set(CMAKE_INSTALL_MANDIR        "Core/Data/man"      CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SYSCONFDIR    "Core/Config"        CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INFODIR       "Core/Data/info"     CACHE STRING "" FORCE)

# ── Per-target runtime settings: x86_64-rovelstars-runixos ───────────────────
#
# CMAKE_SYSROOT: the caller MUST supply this, either via the top-level
# -DCMAKE_SYSROOT=… (which does NOT propagate into sub-builds automatically)
# or by passing it explicitly on the cmake command line:
#   -DRUNTIMES_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/runixos-sysroot
#
set(RUNTIMES_x86_64-rovelstars-runixos_LLVM_ENABLE_RUNTIMES
  "compiler-rt;libcxx;libcxxabi;libunwind;openmp"
  CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR
  "Core/LibKit"
  CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_CMAKE_INSTALL_BINDIR
  "Core/Bin"
  CACHE STRING "" FORCE)
set(RUNTIMES_x86_64-rovelstars-runixos_RovelStars ON CACHE BOOL "" FORCE)

# ── Per-target builtin settings: x86_64-rovelstars-runixos ───────────────────
#
# CMAKE_SYSROOT: same requirement as for runtimes above.
# Pass via:
#   -DBUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/runixos-sysroot
#
set(BUILTINS_x86_64-rovelstars-runixos_RovelStars ON CACHE BOOL "" FORCE)
set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR
  "Core/LibKit"
  CACHE STRING "" FORCE)
set(BUILTINS_x86_64-rovelstars-runixos_CMAKE_INSTALL_BINDIR
  "Core/Bin"
  CACHE STRING "" FORCE)

# ── AArch64 per-target settings (Stage 2/3, currently commented out) ─────────
# Uncomment and add "aarch64-rovelstars-runixos" to LLVM_BUILTIN_TARGETS /
# LLVM_RUNTIME_TARGETS above once an AArch64 RunixOS sysroot is available.
#
# set(RUNTIMES_aarch64-rovelstars-runixos_LLVM_ENABLE_RUNTIMES
#   "compiler-rt;libcxx;libcxxabi;libunwind;openmp"
#   CACHE STRING "" FORCE)
# set(RUNTIMES_aarch64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR
#   "Core/LibKit"
#   CACHE STRING "" FORCE)
# set(RUNTIMES_aarch64-rovelstars-runixos_CMAKE_INSTALL_BINDIR
#   "Core/Bin"
#   CACHE STRING "" FORCE)
# set(RUNTIMES_aarch64-rovelstars-runixos_RovelStars ON CACHE BOOL "" FORCE)
#
# set(BUILTINS_aarch64-rovelstars-runixos_RovelStars ON CACHE BOOL "" FORCE)
# set(BUILTINS_aarch64-rovelstars-runixos_CMAKE_INSTALL_LIBDIR
#   "Core/LibKit"
#   CACHE STRING "" FORCE)
# set(BUILTINS_aarch64-rovelstars-runixos_CMAKE_INSTALL_BINDIR
#   "Core/Bin"
#   CACHE STRING "" FORCE)
# set(BUILTINS_aarch64-rovelstars-runixos_CMAKE_SYSROOT
#   "/path/to/aarch64-runixos-sysroot"
#   CACHE PATH "" FORCE)
