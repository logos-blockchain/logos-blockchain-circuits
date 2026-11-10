// Workaround for Windows where some mman functions are not defined

#ifdef _WIN32
#include <cstddef>
inline int madvise(void*, size_t, int) { return 0; }
#define MADV_SEQUENTIAL 0
#endif
