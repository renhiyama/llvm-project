# RovelStars/RunixOS - Runtimes initial cache (Stage 1)
#
# This file is passed via RUNTIMES_CACHE_FILES to the runtimes ExternalProject
# sub-build. It does two critical things for a Stage 1 build:
#
# 1. Override LLVM_USE_LINKER with the full path to the system ld.lld.
#    The freshly-built stage1 clang binary lives in build/stage1/bin/ and
#    its default target triple is x86_64-rovelstars-runixos. When CMake runs
#    the CXX_SUPPORTS_CUSTOM_LINKER test with "-fuse-ld=lld", clang tries to
#    link against RunixOS CRT / runtime libs that don't exist on the build
#    machine, causing the test to fail. Using the full absolute path bypasses
#    the linker-discovery problem and the test still succeeds because
#    CMAKE_C_COMPILER_TARGET is overridden to the host triple below.
#
# 2. Override CMAKE_C/CXX_COMPILER_TARGET to the host triple for the runtimes
#    configure step. Stage 1 runtimes (libcxx, libunwind, compiler-rt, openmp)
#    must be built for the host machine so that the build itself works. The
#    RunixOS triple is used as the *install* target triple in Stage 2/3 once a
#    proper RunixOS sysroot is available.
#
# Stage 2 / Stage 3 note:
#   Replace the COMPILER_TARGET lines with x86_64-rovelstars-runixos (or
#   aarch64-rovelstars-runixos) and provide a CMAKE_SYSROOT pointing to the
#   RunixOS sysroot image.

# ── Linker ────────────────────────────────────────────────────────────────────
# Use the absolute path to the system lld so the freshly-built stage1 clang
# can locate it without searching PATH relative to its own prefix.
# LLVM_USE_LINKER is set to "lld" by the top-level LLVM_ENABLE_LLD passthrough;
# overriding it here (via -C cache file) is not sufficient because -D flags
# take precedence. The ExternalProject machinery passes it as a -D argument.
# We work around this by using the full path, which clang accepts as-is via
# -fuse-ld=<absolute-path>.
set(LLVM_USE_LINKER "/usr/bin/ld.lld" CACHE STRING "" FORCE)

# ── Host triple override for Stage 1 ─────────────────────────────────────────
# Force the runtimes sub-build to target the host triple so that CRT files,
# system headers, and libraries are found correctly on the build machine.
# Without this the stage1 clang (default triple x86_64-rovelstars-runixos)
# looks for RunixOS-specific paths that don't exist on the build host.
set(CMAKE_C_COMPILER_TARGET   "x86_64-unknown-linux-gnu" CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_TARGET "x86_64-unknown-linux-gnu" CACHE STRING "" FORCE)
set(CMAKE_ASM_COMPILER_TARGET "x86_64-unknown-linux-gnu" CACHE STRING "" FORCE)
set(LLVM_DEFAULT_TARGET_TRIPLE "x86_64-unknown-linux-gnu" CACHE STRING "" FORCE)

# ── RunixOS install layout ────────────────────────────────────────────────────
# Mirror the RunixOS filesystem hierarchy so runtimes install to the right
# locations even in Stage 1.
set(CMAKE_INSTALL_BINDIR        "Core/Bin"       CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SBINDIR       "Core/Bin"       CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBDIR        "Core/LibKit"    CACHE STRING "" FORCE)
set(CMAKE_INSTALL_LIBEXECDIR    "Core/LibKit"    CACHE STRING "" FORCE)
set(CMAKE_INSTALL_INCLUDEDIR    "Core/APIHeader" CACHE STRING "" FORCE)
set(CMAKE_INSTALL_DATADIR       "Core/Data"      CACHE STRING "" FORCE)
set(CMAKE_INSTALL_MANDIR        "Core/Data/man"  CACHE STRING "" FORCE)
set(CMAKE_INSTALL_SYSCONFDIR    "Core/Config"    CACHE STRING "" FORCE)

# ── RovelStars flag ───────────────────────────────────────────────────────────
# Propagate the RovelStars CMake flag into sub-projects that check for it.
set(RovelStars ON CACHE BOOL "" FORCE)
