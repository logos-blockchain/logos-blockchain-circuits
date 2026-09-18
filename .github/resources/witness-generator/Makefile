.PHONY: linux macos windows linux-lib macos-lib windows-lib windows-cross-lib build clean

# ---- Arguments ----
ifndef PROJECT
$(error PROJECT is not set. Usage: make PROJECT=<name>. E.g.: make PROJECT=pol linux)
endif

# ---- Common ----
CXX             ?= g++
AR              ?= ar
PRIORITY_FLAGS  ?=
CXXFLAGS_COMMON := -std=c++11 -O3 -I. -Wno-address-of-packed-member -Dmain=circom_main
COMMON_SRCS     := main.cpp calcwit.cpp fr.cpp $(PROJECT).cpp
COMMON_OBJS     := $(COMMON_SRCS:.cpp=.o)
LIB_ONLY_SRCS   := $(PROJECT)/ffi.cpp circom_adapter.cpp
LIB_ONLY_OBJS   := $(LIB_ONLY_SRCS:.cpp=.o)
LIB_SRCS        := $(COMMON_SRCS) $(LIB_ONLY_SRCS)
LIB_OBJS        := $(COMMON_OBJS) $(LIB_ONLY_OBJS)
DEPS_HPP        := circom.hpp calcwit.hpp fr.hpp types.hpp $(PROJECT)/ffi.hpp
BIN             := $(PROJECT)
ifeq ($(OS),windows)
LIB_EXT         := .lib
LIB_PREFIX      :=
else
LIB_EXT         := .a
LIB_PREFIX      := lib
endif
LIB             := $(LIB_PREFIX)$(PROJECT)$(LIB_EXT)

# ---- Linux (x86_64 and aarch64) ----
# NOTE: linux (bin) links system gmp via -lgmp. CI uses linux-lib only, which
# relies on PRIORITY_FLAGS to prefer the gmp built from source over the system one.
linux: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON)
linux: LDFLAGS=-static
linux: LDLIBS=-lgmp
linux: $(BIN)

linux-lib: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON) -fPIC
linux-lib: $(LIB)

# ---- macOS ----
# NOTE: macos (bin) hardcodes Homebrew gmp for both includes and linking. CI uses
# macos-lib only, which relies on PRIORITY_FLAGS to prefer the gmp built from source.
macos: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON) -I/opt/homebrew/include -include gmp_patch.hpp -mmacosx-version-min=11.0
macos: LDFLAGS=-Wl,-search_paths_first -Wl,-dead_strip
macos: LDLIBS=/opt/homebrew/lib/libgmp.a
macos: $(BIN)

macos-lib: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON) -fPIC -I/opt/homebrew/include -include gmp_patch.hpp -mmacosx-version-min=11.0
macos-lib: $(LIB)

# ---- Windows (MinGW) ----
# NOTE: windows (bin) links system gmp via -lgmp. CI uses windows-lib only, which
# relies on PRIORITY_FLAGS to prefer the gmp built from source over the system one.
windows: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON) -I/include -Duint="unsigned int"
windows: LDFLAGS=-static
windows: LDLIBS=-L/lib -lgmp -lmman
windows: $(BIN)

windows-lib: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON) -fPIC -I/include -Duint="unsigned int"
windows-lib: $(LIB)

# ---- Windows (MinGW cross, built on Linux) ----
# Same sources as windows-lib, compiled with the toolchain a cross-compiling
# consumer links with. OS=windows-cross keeps the lib<name>.a naming GNU ld
# resolves from -l<name>, and the archive is isolated by renaming rather than
# by `ld -r` (see isolate-symbols.sh for why that pass cannot be used on PE).
windows-cross-lib: CXXFLAGS=$(PRIORITY_FLAGS) $(CXXFLAGS_COMMON) -fPIC -Duint="unsigned int"
windows-cross-lib: $(LIB_OBJS)
	sh $(ISOLATE) $(PROJECT) $(NM) $(OBJDUMP) $(OBJCOPY) $(LIB_OBJS)
	rm -f $(LIB)
	$(AR) rcs $(LIB) $(LIB_OBJS)

# Localizes witness-generator implementation symbols to prevent conflicts when multiple circuit libraries are linked
# into the same binary.
# See CONTRIBUTING.md § "Symbol Isolation".
PUBLIC_SYMS := $(PROJECT)_generate_witness $(PROJECT)_generate_witness_from_files
LOCAL_OBJ   := $(PROJECT)_local.o
OBJCOPY     := $(if $(filter windows,$(OS)),objcopy,llvm-objcopy)
NM          ?= nm
OBJDUMP     ?= objdump
ISOLATE     ?= ../../.github/resources/witness-generator/isolate-symbols.sh
SYM_PREFIX  := $(if $(filter macos,$(OS)),_,)

# ---- Rules ----
$(BIN): $(COMMON_OBJS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(LIB): $(LIB_OBJS)
	ld -r -o $(LOCAL_OBJ) $^
	$(OBJCOPY) $(foreach sym,$(PUBLIC_SYMS),--keep-global-symbol=$(SYM_PREFIX)$(sym)) $(LOCAL_OBJ)
	rm -f $@
	ar rcs $@ $(LOCAL_OBJ)
	rm $(LOCAL_OBJ)

%.o: %.cpp $(DEPS_HPP)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(COMMON_OBJS) $(LIB_ONLY_OBJS) $(BIN) $(LIB) $(LOCAL_OBJ)
