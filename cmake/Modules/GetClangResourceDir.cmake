# get clang resource directory
#
# usage:
#  get_clang_resource_dir(out_var [PREFIX prefix] [SUBDIR subdirectory])
#
# user can use `PREFIX` to prepend some path to it or use `SUBDIR` to
# get subdirectory under clang resource dir

function(get_clang_resource_dir out_var)
  cmake_parse_arguments(ARG "" "PREFIX;SUBDIR" "" ${ARGN})

  if(DEFINED CLANG_RESOURCE_DIR AND NOT CLANG_RESOURCE_DIR STREQUAL "")
    set(ret_dir bin)
    cmake_path(APPEND ret_dir ${CLANG_RESOURCE_DIR})
  else()
    if (NOT CLANG_VERSION_MAJOR)
      string(REGEX MATCH "^[0-9]+" CLANG_VERSION_MAJOR ${PACKAGE_VERSION})
    endif()
    if(RovelStars)
      if(ARG_PREFIX)
        # Build-time: PREFIX is parent of LibKit, so use basename
        set(ret_dir ${ARG_PREFIX}/LibKit/clang/${CLANG_VERSION_MAJOR})
      else()
        # Install-time: relative to CMAKE_INSTALL_PREFIX, needs full path
        set(ret_dir ${CMAKE_INSTALL_LIBDIR}/clang/${CLANG_VERSION_MAJOR})
      endif()
    else()
      set(ret_dir lib${LLVM_LIBDIR_SUFFIX}/clang/${CLANG_VERSION_MAJOR})
      if(ARG_PREFIX)
        set(ret_dir ${ARG_PREFIX}/${ret_dir})
      endif()
    endif()
    if(ARG_SUBDIR)
      set(ret_dir ${ret_dir}/${ARG_SUBDIR})
    endif()
  endif()

  set(${out_var} ${ret_dir} PARENT_SCOPE)
endfunction()
