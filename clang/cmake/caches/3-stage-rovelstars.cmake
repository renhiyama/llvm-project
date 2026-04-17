# 3-stage bootstrap build for RunixOS
#
# Overview
# --------
# This cache drives a 3-stage LLVM bootstrap targeting RunixOS:
#
#   Stage 1  (this file)  — built with the host compiler; produces clang/lld
#                           in build/stage2/tools/clang/stage2-bins/
#   Stage 2  (RovelStars-stage2.cmake) — built with stage1 clang; cross-
#                           compiles LLVM for x86_64-rovelstars-runixos with
#                           PGO instrumentation enabled (LLVM_ENABLE_PGO=GEN)
#   Stage 3  (future)     — built with the PGO-instrumented stage2 toolchain;
#                           consumes merged *.profdata to produce the final
#                           fully-optimised RunixOS-native LLVM release
#
# Usage
# -----
#   # Configure from the llvm-project root:
#   cmake -G Ninja \
#     -C clang/cmake/caches/3-stage-rovelstars.cmake \
#     -DCMAKE_INSTALL_PREFIX=/path/to/install \
#     -DCMAKE_SYSROOT=/path/to/runixos-sysroot \
#     -DRUNTIMES_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/runixos-sysroot \
#     -DBUILTINS_x86_64-rovelstars-runixos_CMAKE_SYSROOT=/path/to/runixos-sysroot \
#     -B build/stage1 \
#     llvm
#
#   # Build through all three stages:
#   ninja -C build/stage1 stage2
#   ninja -C build/stage1 stage3          # once stage2 PGO profiles are ready
#
#   # Or just build stage2 and install:
#   ninja -C build/stage1 stage2-install-distribution
#
# Notes
# -----
#   - CMAKE_SYSROOT at the top level is NOT automatically forwarded into the
#     runtimes/builtins ExternalProject sub-builds.  Pass the sysroot
#     explicitly via the RUNTIMES_* and BUILTINS_* -D arguments shown above.
#   - LLVM_USE_LINKER is set to /usr/bin/ld.lld for stage1 (system lld).
#     Stage2 overrides it to the stage1 ld.lld via RovelStars-stage2.cmake.
#   - Do NOT set BOOTSTRAP_LLVM_ENABLE_LLD here; stage1 clang uses an
#     absolute linker path via LLVM_USE_LINKER, and BOOTSTRAP_LLVM_ENABLE_LLD
#     conflicts with that mechanism.

# ── Stage 1 configuration ─────────────────────────────────────────────────────

# Include RovelStars base settings (vendor, features, RunixOS FHS paths, etc.).
# RovelStars.cmake intentionally leaves LLVM_DEFAULT_TARGET_TRIPLE unset so
# that the stage1 runtimes sub-build targets the host triple and can find host
# CRTs.  We set the RunixOS triple explicitly below for the overall 3-stage
# build so that stage2 and beyond inherit the correct default.
include(${CMAKE_CURRENT_LIST_DIR}/RovelStars.cmake)

# Enable bootstrap so CMake knows to drive subsequent stages.
set(CLANG_ENABLE_BOOTSTRAP ON CACHE BOOL "")

# Stage 1 only needs to build enough to bootstrap; Native covers the host arch.
set(LLVM_TARGETS_TO_BUILD "Native" CACHE STRING "")

# The canonical RunixOS target triple for this 3-stage build.
# RovelStars.cmake leaves this unset (for stage1 host-runtimes safety); we
# set it here so stage2/stage3 receive the correct default target.
set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-rovelstars-runixos" CACHE STRING "")

# Stage 1 only needs clang and lld — the minimal toolchain required to drive
# stage2.  Runtimes and builtins are built in stage2 against the RunixOS sysroot.
set(LLVM_ENABLE_PROJECTS "clang;lld" CACHE STRING "")

# Use the system lld for stage1 via an absolute path.  This causes the stage1
# clang driver to emit --ld-path=<abs> rather than the deprecated -fuse-ld=lld,
# suppressing the deprecation warning.  LLVM_ENABLE_LLD is kept OFF (set by
# RovelStars.cmake) so the two mechanisms do not conflict.
set(LLVM_USE_LINKER "/usr/bin/ld.lld" CACHE STRING "")

# ── Bootstrap passthrough ──────────────────────────────────────────────────────

# Point stage2 at the RovelStars-stage2 cache so it picks up cross-compilation
# settings, LTO, PGO=GEN, and per-target runtime/builtin configuration.
set(CLANG_BOOTSTRAP_CMAKE_ARGS
  -C ${CMAKE_CURRENT_LIST_DIR}/RovelStars-stage2.cmake
  CACHE STRING "")

# Propagate the RunixOS install layout and identity flags into all bootstrap
# stages.  CMAKE_SYSROOT and the per-target sysroot variables are intentionally
# excluded here — they must be forwarded explicitly by the caller because the
# ExternalProject sub-build does not inherit the parent's CMakeCache.
set(CLANG_BOOTSTRAP_PASSTHROUGH
  CMAKE_INSTALL_PREFIX
  CMAKE_INSTALL_BINDIR
  CMAKE_INSTALL_SBINDIR
  CMAKE_INSTALL_LIBDIR
  CMAKE_INSTALL_LIBEXECDIR
  CMAKE_INSTALL_INCLUDEDIR
  CMAKE_INSTALL_DATADIR
  CMAKE_INSTALL_MANDIR
  CMAKE_INSTALL_SYSCONFDIR
  LLVM_DEFAULT_TARGET_TRIPLE
  RovelStars
  RunixOfficialBuild
  CACHE STRING "")

# ── Bootstrap targets ──────────────────────────────────────────────────────────
set(CLANG_BOOTSTRAP_TARGETS
  clang
  check-all
  check-llvm
  check-clang
  install-distribution
  install-distribution-toolchain
  stage3
  stage3-clang
  stage3-check-all
  stage3-check-llvm
  stage3-check-clang
  CACHE STRING "")
