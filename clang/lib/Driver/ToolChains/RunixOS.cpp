//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "RunixOS.h"
#include "clang/Config/config.h"
#include "clang/Driver/CommonArgs.h"
#include "clang/Driver/Driver.h"
#include "clang/Driver/SanitizerArgs.h"
#include "clang/Options/Options.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/VirtualFileSystem.h"

using namespace clang::driver;
using namespace clang::driver::toolchains;
using namespace clang;
using namespace llvm::opt;

using tools::addPathIfExists;

std::string RunixOS::getMultiarchTriple(const Driver &D,
                                        const llvm::Triple &TargetTriple,
                                        StringRef SysRoot) const {
  switch (TargetTriple.getArch()) {
  case llvm::Triple::x86_64:
    return "x86_64-rovelstars-runixos";
  case llvm::Triple::aarch64:
    return "aarch64-rovelstars-runixos";
  default:
    return TargetTriple.str();
  }
}

RunixOS::RunixOS(const Driver &D, const llvm::Triple &Triple,
                 const ArgList &Args)
    : Generic_ELF(D, Triple, Args) {
  // Initialise GCC installation detection. RunixOS prefers compiler-rt, but
  // a GCC toolchain may still be present in /Core/LibKit and we want the
  // GCCInstallationDetector to find it so that GCC-based multilib paths and
  // CRT objects are located correctly when needed.
  GCCInstallation.init(Triple, Args);

  std::string SysRoot = computeSysRoot();

  path_list &Paths = getFilePaths();

  // RunixOS uses its own filesystem hierarchy rather than the traditional FHS.
  // There is no /usr, /lib, or /lib64 on RunixOS; libraries live under
  // /Core/LibKit (system, immutable ring) and optionally under
  // /Construct/LibKit (user ring, admin-writable).
  addPathIfExists(D, concat(SysRoot, "/Core/LibKit"), Paths);
  addPathIfExists(D, concat(SysRoot, "/Construct/LibKit"), Paths);
}

Tool *RunixOS::buildLinker() const {
  return new tools::gnutools::Linker(*this);
}

Tool *RunixOS::buildAssembler() const {
  return new tools::gnutools::Assembler(*this);
}

std::string RunixOS::computeSysRoot() const {
  if (!getDriver().SysRoot.empty())
    return getDriver().SysRoot;
  return std::string();
}

std::string RunixOS::getDynamicLinker(const ArgList &Args) const {
  switch (getTriple().getArch()) {
  case llvm::Triple::x86_64:
    return "/Core/LibKit/ld-runixos-x86-64.rdl.2";
  case llvm::Triple::aarch64:
    return "/Core/LibKit/ld-runixos-aarch64.rdl.1";
  default:
    llvm_unreachable("unsupported architecture for RunixOS dynamic linker");
  }
}

void RunixOS::AddClangSystemIncludeArgs(const ArgList &DriverArgs,
                                        ArgStringList &CC1Args) const {
  const Driver &D = getDriver();
  std::string SysRoot = computeSysRoot();

  if (DriverArgs.hasArg(options::OPT_nostdinc))
    return;

  // Add the compiler's built-in resource directory headers (e.g. stdint.h,
  // float.h).  These are clang-internal and do not live under the sysroot.
  if (!DriverArgs.hasArg(options::OPT_nobuiltininc)) {
    SmallString<128> ResourceDirInclude(D.ResourceDir);
    llvm::sys::path::append(ResourceDirInclude, "include");
    addSystemInclude(DriverArgs, CC1Args, ResourceDirInclude);
  }

  if (DriverArgs.hasArg(options::OPT_nostdlibinc))
    return;

  // Primary system headers — immutable, SIP-protected ring.
  // RunixOS has no /usr; all system headers live under /Core/APIHeader.
  addSystemInclude(DriverArgs, CC1Args, concat(SysRoot, "/Core/APIHeader"));

  // Optional user-ring headers (/Construct/APIHeader).  Only add this path
  // when the directory actually exists so that a minimal sysroot without a
  // Construct tree still works cleanly.
  if (D.getVFS().exists(concat(SysRoot, "/Construct/APIHeader")))
    addSystemInclude(DriverArgs, CC1Args,
                     concat(SysRoot, "/Construct/APIHeader"));
}

void RunixOS::AddClangCXXStdlibIncludeArgs(const ArgList &DriverArgs,
                                            ArgStringList &CC1Args) const {
  if (DriverArgs.hasArg(options::OPT_nostdlibinc) ||
      DriverArgs.hasArg(options::OPT_nostdincxx))
    return;

  // RunixOS ships libc++ as its only C++ standard library.  The headers are
  // installed at /Core/APIHeader/c++/v1, mirroring the RunixOS FHS convention
  // where all system headers live under /Core/APIHeader.
  std::string SysRoot = computeSysRoot();
  addSystemInclude(DriverArgs, CC1Args,
                   concat(SysRoot, "/Core/APIHeader/c++/v1"));
}

SanitizerMask RunixOS::getSupportedSanitizers() const {
  const bool IsX86_64 = getTriple().getArch() == llvm::Triple::x86_64;

  SanitizerMask Res = ToolChain::getSupportedSanitizers();

  // Sanitizers supported on all RunixOS targets.
  Res |= SanitizerKind::Address;
  Res |= SanitizerKind::HWAddress;
  Res |= SanitizerKind::KernelAddress;
  Res |= SanitizerKind::MemTag;
  Res |= SanitizerKind::Thread;
  Res |= SanitizerKind::Memory;
  Res |= SanitizerKind::Leak;
  Res |= SanitizerKind::Undefined;
  Res |= SanitizerKind::CFI;
  Res |= SanitizerKind::DataFlow;
  Res |= SanitizerKind::PointerCompare;
  Res |= SanitizerKind::PointerSubtract;
  Res |= SanitizerKind::Vptr;
  Res |= SanitizerKind::Realtime;
  Res |= SanitizerKind::Scudo;

  // x86_64-only sanitizers.
  if (IsX86_64) {
    Res |= SanitizerKind::KernelMemory;
    Res |= SanitizerKind::NumericalStability;
  }

  return Res;
}