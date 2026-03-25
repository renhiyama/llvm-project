# 3-stage bootstrap build for RunixOS
#
# Usage:
#   cmake -G Ninja -C clang/cmake/caches/3-stage-rovelstars.cmake \
#     -DCMAKE_INSTALL_PREFIX=/home/user/ROS \
#     -DCMAKE_INSTALL_BINDIR=Core/Bin \
#     -DCMAKE_INSTALL_LIBDIR=Core/LibKit \
#     -DCMAKE_INSTALL_INCLUDEDIR=Core/APIHeader \
#     -DCMAKE_INSTALL_DATADIR=Core/StoreRoom \
#     llvm
#   ninja stage3

# Stage 1: Build with host compiler
set(CLANG_ENABLE_BOOTSTRAP ON CACHE BOOL "")
set(LLVM_TARGETS_TO_BUILD Native CACHE STRING "")

# Include RovelStars base settings for stage 1
include(${CMAKE_CURRENT_LIST_DIR}/RovelStars.cmake)

# Projects for all stages. Builtins are built via LLVM_BUILTIN_TARGETS
# in RovelStars.cmake. Full compiler-rt runtimes require a sysroot
# and should be built separately after glibc is installed.
set(LLVM_ENABLE_PROJECTS "clang;lld" CACHE STRING "")

# Bootstrap stages use LLD and LTO for faster builds
set(BOOTSTRAP_LLVM_ENABLE_LLD ON CACHE BOOL "")
set(BOOTSTRAP_LLVM_ENABLE_LTO ON CACHE BOOL "")

# Pass RovelStars flag to all subsequent stages
set(BOOTSTRAP_RovelStars ON CACHE BOOL "")

# Pass RunixOS install paths through to bootstrap stages
set(CLANG_BOOTSTRAP_PASSTHROUGH
  CMAKE_INSTALL_BINDIR
  CMAKE_INSTALL_LIBDIR
  CMAKE_INSTALL_INCLUDEDIR
  CMAKE_INSTALL_DATADIR
  CMAKE_INSTALL_LIBEXECDIR
  CMAKE_INSTALL_MANDIR
  CMAKE_INSTALL_SBINDIR
  CMAKE_INSTALL_SYSCONFDIR
  RovelStars
  RunixOfficialBuild
  CACHE STRING "")

# Each bootstrap stage re-reads the RovelStars cache
set(CLANG_BOOTSTRAP_CMAKE_ARGS
  -C ${CMAKE_CURRENT_LIST_DIR}/RovelStars.cmake
  CACHE STRING "")

# Bootstrap targets — stage2 builds stage3
set(CLANG_BOOTSTRAP_TARGETS
  clang
  check-all
  check-llvm
  check-clang
  stage3
  stage3-clang
  stage3-check-all
  stage3-check-llvm
  stage3-check-clang
  CACHE STRING "")
