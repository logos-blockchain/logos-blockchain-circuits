.PHONY: linux macos windows linux-lib macos-lib windows-lib build clean

# ---- Arguments ----
ifndef PROJECT
$(error PROJECT is not set. Usage: make PROJECT=<name>. E.g.: make PROJECT=pol linux)
endif

# ---- Common ----
CXX             := g++
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
linux: CXXFLAGS=$(CXXFLAGS_COMMON)
linux: LDFLAGS=-static
linux: LDLIBS=-lgmp
linux: $(BIN)

linux-lib: CXXFLAGS=$(CXXFLAGS_COMMON) -fPIC
linux-lib: $(LIB)

# ---- macOS ----
macos: CXXFLAGS=$(CXXFLAGS_COMMON) -I/opt/homebrew/include -include gmp_patch.hpp
macos: LDFLAGS=-Wl,-search_paths_first -Wl,-dead_strip
macos: LDLIBS=/opt/homebrew/lib/libgmp.a
macos: $(BIN)

macos-lib: CXXFLAGS=$(CXXFLAGS_COMMON) -fPIC -I/opt/homebrew/include -include gmp_patch.hpp
macos-lib: $(LIB)

# ---- Windows (MinGW) ----
windows: CXXFLAGS=$(CXXFLAGS_COMMON) -I/include -Duint="unsigned int"
windows: LDFLAGS=-static
windows: LDLIBS=-L/lib -lgmp -lmman
windows: $(BIN)

windows-lib: CXXFLAGS=$(CXXFLAGS_COMMON) -fPIC -I/include -Duint="unsigned int"
windows-lib: $(LIB)

# ---- Rules ----
$(BIN): $(COMMON_OBJS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(LIB): $(LIB_OBJS)
	ar rcs $@ $^

%.o: %.cpp $(DEPS_HPP)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(COMMON_OBJS) $(LIB_ONLY_OBJS) $(BIN) $(LIB)
