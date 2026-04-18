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

# ── Compiler works bypass ─────────────────────────────────────────────────────
# Skip CMake's built-in compiler link tests in the runtimes sub-build.
#
# During Stage 2, the runtimes ExternalProject sub-cmake runs its
# CXX_SUPPORTS_CUSTOM_LINKER check using the freshly-built stage2 clang
# (targeting x86_64-rovelstars-runixos). That check does a full compile+link,
# but at the time it runs, the builtins for RunixOS (libclang_rt.builtins.ral)
# haven't been installed into the stage2 resource dir yet — they're being built
# concurrently. The link fails with "cannot open libclang_rt.builtins.ral".
#
# Setting CMAKE_C/CXX_COMPILER_WORKS=ON skips the whole compiler-test sequence
# including the linker-capability test, which is safe here because:
#   - The compiler (stage1 or stage2 clang) is already known to work.
#   - The linker (stage1 ld.lld) is already known to work.
#   - The actual runtimes build will verify correctness when it compiles real code.
set(CMAKE_C_COMPILER_WORKS   ON CACHE BOOL "" FORCE)
set(CMAKE_CXX_COMPILER_WORKS ON CACHE BOOL "" FORCE)
set(CMAKE_ASM_COMPILER_WORKS ON CACHE BOOL "" FORCE)

# ── libunwind configuration ───────────────────────────────────────────────────
# libunwind requires unwind table generation. The RunixOS stage2 clang may fail
# its unwind-table capability test when building in a bootstrapped context, so
# explicitly tell libunwind that the compiler supports it and enable it.
set(LIBUNWIND_ENABLE_SHARED   ON  CACHE BOOL "" FORCE)
set(LIBUNWIND_ENABLE_STATIC   ON  CACHE BOOL "" FORCE)
set(LIBUNWIND_USE_COMPILER_RT ON  CACHE BOOL "" FORCE)
# compiler-rt must use libc++ (not libstdc++) as its C++ ABI library on RunixOS.
# RunixOS has no libstdc++ — all C++ ABI support comes from libc++abi.
# Without this, sanitizer shared libs (ubsan_standalone, asan, etc.) fail to link
# with "undefined symbol: typeinfo for std::type_info" because compiler-rt defaults
# to libstdc++ on Linux-like systems.
set(COMPILER_RT_CXX_LIBRARY   "libcxx" CACHE STRING "" FORCE)
# Sanitizers use libc++abi for C++ ABI. INTREE means link against the libc++abi
# being built in this same runtimes batch (uses the cxxabi_shared CMake target).
set(SANITIZER_CXX_ABI          "libcxxabi" CACHE STRING "" FORCE)
set(SANITIZER_CXX_ABI_INTREE   ON          CACHE BOOL   "" FORCE)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -funwind-tables" CACHE STRING "" FORCE)
set(CMAKE_C_FLAGS   "${CMAKE_C_FLAGS}   -funwind-tables" CACHE STRING "" FORCE)
set(LIBCXXABI_USE_LLVM_UNWINDER ON  CACHE BOOL "" FORCE)
set(LIBCXXABI_USE_COMPILER_RT   ON  CACHE BOOL "" FORCE)
set(LIBCXX_USE_COMPILER_RT      ON  CACHE BOOL "" FORCE)
# Tell compiler-rt/Scudo to use LLVM's libunwind instead of GCC's libgcc_s,
# which does not exist on RunixOS. Without this Scudo's GWP-ASan component
# aborts configure with "No suitable unwinder library".
set(COMPILER_RT_USE_LLVM_UNWINDER ON CACHE BOOL "" FORCE)

# Pre-set the compiler flag capability variables that libunwind's CMakeLists
# checks before allowing the shared library to be built. When CMAKE_CXX_COMPILER_WORKS
# is forced ON (to skip the broken link test), cmake's check_cxx_compiler_flag()
# calls are also bypassed, leaving these variables undefined (falsy). Setting
# them here prevents the "Compiler doesn't support generation of unwind tables"
# fatal error in libunwind/src/CMakeLists.txt.
set(CXX_SUPPORTS_FNO_EXCEPTIONS_FLAG  TRUE CACHE BOOL "" FORCE)
set(CXX_SUPPORTS_FUNWIND_TABLES_FLAG  TRUE CACHE BOOL "" FORCE)
set(LIBUNWIND_ENABLE_THREADS          ON   CACHE BOOL "" FORCE)

# ── RovelStars flag ───────────────────────────────────────────────────────────
# Propagate the RovelStars CMake flag into sub-projects that check for it.
set(RovelStars ON CACHE BOOL "" FORCE)
