// Workaround for Windows where some mman functions are not defined

#ifdef _WIN32
#include <cstddef>
#include <sys/mman.h>
#ifndef MADV_SEQUENTIAL
inline int madvise(void*, size_t, int) { return 0; }
#define MADV_SEQUENTIAL 0
#endif
#endif
