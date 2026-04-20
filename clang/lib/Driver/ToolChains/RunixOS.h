//===--- RunixOS.h - RunixOS ToolChain Implementations ----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_DRIVER_TOOLCHAINS_RUNIXOS_H
#define LLVM_CLANG_LIB_DRIVER_TOOLCHAINS_RUNIXOS_H

#include "Gnu.h"
#include "clang/Driver/ToolChain.h"

namespace clang {
namespace driver {
namespace toolchains {

class LLVM_LIBRARY_VISIBILITY RunixOS : public Generic_ELF {
public:
  RunixOS(const Driver &D, const llvm::Triple &Triple,
          const llvm::opt::ArgList &Args);

  bool HasNativeLLVMSupport() const override { return true; }

  std::string getMultiarchTriple(const Driver &D,
                                 const llvm::Triple &TargetTriple,
                                 StringRef SysRoot) const override;

  void
  AddClangSystemIncludeArgs(const llvm::opt::ArgList &DriverArgs,
                            llvm::opt::ArgStringList &CC1Args) const override;
  void AddClangCXXStdlibIncludeArgs(
      const llvm::opt::ArgList &DriverArgs,
      llvm::opt::ArgStringList &CC1Args) const override;

  RuntimeLibType GetDefaultRuntimeLibType() const override {
    return ToolChain::RLT_CompilerRT;
  }

  CXXStdlibType GetDefaultCXXStdlibType() const override {
    return ToolChain::CST_Libcxx;
  }

  UnwindLibType GetDefaultUnwindLibType() const override {
    return ToolChain::UNW_CompilerRT;
  }

  const char *getDefaultLinker() const override { return "ld.lld"; }

  SanitizerMask getSupportedSanitizers() const override;

  std::string computeSysRoot() const override;

  std::string getDynamicLinker(const llvm::opt::ArgList &Args) const override;

  bool isPIEDefault(const llvm::opt::ArgList &Args) const override {
    return true;
  }

protected:
  Tool *buildLinker() const override;
  Tool *buildAssembler() const override;
};

} // end namespace toolchains
} // end namespace driver
} // end namespace clang

#endif // LLVM_CLANG_LIB_DRIVER_TOOLCHAINS_RUNIXOS_H