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
#   x86_64-rovelstars-linux-runixos so `clang` defaults to emitting RunixOS code.
#
# Stage 2 notes:
#   - Set LLVM_DEFAULT_TARGET_TRIPLE and LLVM_RUNTIME_TARGETS to
#     x86_64-rovelstars-linux-runixos (and aarch64-rovelstars-linux-runixos for AArch64)
#   - Provide CMAKE_SYSROOT pointing to a RunixOS sysroot image
#   - Re-enable AArch64 builtins via LLVM_BUILTIN_TARGETS
#   - Use the stage1 clang/lld as CMAKE_C_COMPILER / CMAKE_CXX_COMPILER

# ── Sub-projects ──────────────────────────────────────────────────────────────
set(LLVM_TARGETS_TO_BUILD "X86;AArch64" CACHE STRING "" FORCE)
set(LLVM_ENABLE_PROJECTS
  "clang;clang-tools-extra;lld;lldb;bolt;mlir;polly"
  CACHE STRING "" FORCE)
# Stage 1 builds clang and lld only. The runtimes (compiler-rt, libc++, etc.)
# need a RunixOS libc sysroot to link against, and glibc is built AFTER this
# stage. Build the runtimes in a later step once the sysroot exists (see
# NOTE.md section 5 and RovelStars-runtimes.cmake).
set(LLVM_ENABLE_RUNTIMES "" CACHE STRING "" FORCE)

# ── Vendor / branding ─────────────────────────────────────────────────────────
set(CLANG_VENDOR "RovelStars" CACHE STRING "" FORCE)
set(PACKAGE_VENDOR "RovelStars" CACHE STRING "" FORCE)
set(RunixOfficialBuild ON CACHE BOOL "" FORCE)
# RovelStars is the cmake identity flag that enables RunixOS-specific code paths
# throughout clang/CMakeLists.txt, llvm/CMakeLists.txt, bolt/CMakeLists.txt etc.
# When building natively ON RunixOS the cmake Platform module sets this automatically.
# When cross-compiling FROM a Linux host (as in Stage 1 and Stage 2 bootstrap builds)
# the Linux platform module runs instead, so we must set the flag explicitly here.
# Without it, CLANG_INSTALL_LIBDIR_BASENAME defaults to "lib" instead of "LibKit",
# output directories don't follow the RunixOS FHS, and many if(RovelStars) guards
# throughout the build system are never entered.
set(RovelStars ON CACHE BOOL "" FORCE)
# TODO: set(BUG_REPORT_URL "https://os.rovelstars.com/bugreport" CACHE STRING "" FORCE)

# ── Build type ────────────────────────────────────────────────────────────────
set(CMAKE_BUILD_TYPE "Release" CACHE STRING "" FORCE)

# ── Compiler ──────────────────────────────────────────────────────────────────
# CMAKE_C_COMPILER and CMAKE_CXX_COMPILER are intentionally NOT set here.
# The caller must supply them on the cmake command line, e.g.:
#   Stage 1:  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
#   Stage 2:  -DCMAKE_C_COMPILER=/path/to/stage1/bin/clang
#             -DCMAKE_CXX_COMPILER=/path/to/stage1/bin/clang++
# Setting them here with FORCE would override the command-line values because
# llvm/CMakeLists.txt re-includes this file via include() (not -C cache),
# causing the FORCE set() to win and breaking the stage2 compiler discovery.


# ── Linker ────────────────────────────────────────────────────────────────────
# Use "lld" by name rather than an absolute path so the build is reproducible
# across machines with lld installed in different locations.  The caller must
# ensure lld (specifically ld.lld) is on PATH.
# Note: Stage 1 uses the system lld; Stages 2/3 override this on the cmake
# command line with an absolute path to the just-built ld.lld.
set(LLVM_ENABLE_LLD OFF CACHE BOOL "" FORCE)
set(LLVM_USE_LINKER "lld" CACHE STRING "" FORCE)

# ── Target triple ─────────────────────────────────────────────────────────────
# Stage 1: do NOT set LLVM_DEFAULT_TARGET_TRIPLE to a RunixOS triple.
#
# llvm/CMakeLists.txt unconditionally does:
#   set(LLVM_TARGET_TRIPLE "${LLVM_DEFAULT_TARGET_TRIPLE}")
# (a non-cache set, highest priority). LLVM_TARGET_TRIPLE is then passed as
# -DCMAKE_C_COMPILER_TARGET=${LLVM_TARGET_TRIPLE} to the runtimes ExternalProject
# sub-build. If this is a RunixOS triple, the freshly-built stage1 clang tries
# to link runtimes test programs against RunixOS CRTs (*.ral, /Core/LibKit/...)
# that don't exist on the build host - every CMake linker test fails.
#
# Solution: leave LLVM_DEFAULT_TARGET_TRIPLE unset in Stage 1. CMake will
# auto-detect the host triple (x86_64-unknown-linux-gnu). The stage1 compiler
# already knows how to *emit* RunixOS code (the RunixOS triple is registered in
# Triple.cpp); stage2 will set LLVM_DEFAULT_TARGET_TRIPLE to the RunixOS triple
# once a proper RunixOS sysroot is available.
#
# Uncomment in Stage 2:
# set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-rovelstars-linux-runixos" CACHE STRING "" FORCE)

# ── Runtimes target ───────────────────────────────────────────────────────────
# "default" = build runtimes for the host triple. Stage 2 changes this to
# "x86_64-rovelstars-linux-runixos" once a RunixOS sysroot is available.
# set(LLVM_RUNTIME_TARGETS "default" CACHE STRING "" FORCE)

# ── Builtins ──────────────────────────────────────────────────────────────────
# Stage 1: build builtins for the host only ("default" = host triple).
# In Stage 2:
#   set(LLVM_BUILTIN_TARGETS "x86_64-rovelstars-linux-runixos" CACHE STRING "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-linux-runixos_RovelStars               ON           CACHE BOOL   "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_INSTALL_LIBDIR     "Core/LibKit" CACHE STRING "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_INSTALL_BINDIR     "Core/Bin"    CACHE STRING "" FORCE)
#   set(BUILTINS_x86_64-rovelstars-linux-runixos_CMAKE_SYSROOT            "/path/to/runixos-sysroot" CACHE PATH "" FORCE)
# AArch64 (Stage 2/3 only, requires its own sysroot):
#   set(BUILTINS_aarch64-rovelstars-linux-runixos_RovelStars               ON           CACHE BOOL   "" FORCE)
#   set(BUILTINS_aarch64-rovelstars-linux-runixos_CMAKE_INSTALL_LIBDIR     "Core/LibKit" CACHE STRING "" FORCE)
#   set(BUILTINS_aarch64-rovelstars-linux-runixos_CMAKE_SYSROOT            "/path/to/aarch64-sysroot" CACHE PATH "" FORCE)
set(LLVM_BUILTIN_TARGETS "default" CACHE STRING "" FORCE)

# ── Reproducibility flags ────────────────────────────────────────────────────
# LLVM_APPEND_VC_REV embeds the live `git rev-parse HEAD` SHA into every clang
# binary via VCSVersion.inc.  This makes two builds from the same source but
# different git states differ byte-for-byte.  Turn it off so Stage 2 and Stage 3
# produce identical binaries when built from the same source, enabling proper
# bootstrap reproducibility verification.
# If you want the SHA in release builds, override on the command line:
#   -DLLVM_APPEND_VC_REV=ON -DLLVM_FORCE_VC_REVISION=<pinned-sha>
set(LLVM_APPEND_VC_REV       OFF CACHE BOOL   "" FORCE)
set(LLVM_FORCE_VC_REVISION   ""  CACHE STRING "" FORCE)

# For bit-for-bit reproducible static archives (.ral files), set
# SOURCE_DATE_EPOCH=0 in the build environment before invoking cmake.
# This makes ar/ranlib use a fixed epoch timestamp for archive members
# instead of the current wall-clock time.  Example wrapper:
#   export SOURCE_DATE_EPOCH=0
#   export ZERO_AR_DATE=1   # for llvm-ar determinism
#   cmake -C clang/cmake/caches/RovelStars.cmake ...

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
# RunixOS filesystem layout (matches the cmake fork's RunixOS platform):
#   Binaries   -> Core/Bin
#   Libraries  -> Core/LibKit
#   Headers    -> Core/APIHeader
#   Data       -> Core/StoreRoom
#   Config     -> Core/Config
#   Man pages  -> Core/StoreRoom/Manual
#
set(CMAKE_INSTALL_BINDIR        "Core/Bin"               CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SBINDIR       "Core/Bin"               CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBDIR        "Core/LibKit"            CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBEXECDIR    "Core/LibKit"            CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INCLUDEDIR    "Core/APIHeader"         CACHE STRING "" FORCE)
set(CMAKE_INSTALL_DATADIR       "Core/StoreRoom"         CACHE STRING "" FORCE)
set(CMAKE_INSTALL_MANDIR        "Core/StoreRoom/Manual"  CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SYSCONFDIR    "Core/Config"            CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INFODIR       "Core/StoreRoom/Info"    CACHE STRING "" FORCE)

# ── LLVM / Clang / LLD CMake package install dirs ────────────────────────────
# These must be concrete paths - variable references like ${CMAKE_INSTALL_LIBDIR}
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
