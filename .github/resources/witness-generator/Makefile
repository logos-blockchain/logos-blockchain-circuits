.PHONY: linux macos windows linux-lib macos-lib windows-lib build clean

# ---- Arguments ----
ifndef PROJECT
$(error PROJECT is not set. Usage: make PROJECT=<name>. E.g.: make PROJECT=pol linux)
endif

# ---- Common ----
CXX             := g++
CXXFLAGS_COMMON := -std=c++11 -O3 -I. -Wno-address-of-packed-member
UNAME_S         := $(shell uname -s)
MACOS_OBJCOPY   := /opt/homebrew/opt/binutils/bin/gobjcopy
ifeq ($(UNAME_S),Darwin)
    # On macOS CI we expect GNU objcopy from Homebrew binutils at this exact path.
    ifeq ($(wildcard $(MACOS_OBJCOPY)),)
        $(error Missing $(MACOS_OBJCOPY). Install binutils with Homebrew or update OBJCOPY for this environment.)
    endif
    OBJCOPY := $(MACOS_OBJCOPY)
else
    # On non-macOS targets we assume objcopy is available on PATH.
    OBJCOPY := objcopy
endif
SRCS            := main.cpp calcwit.cpp fr.cpp $(PROJECT).cpp
OBJS            := $(SRCS:.cpp=.o)
LIB_SRCS        := calcwit.cpp fr.cpp $(PROJECT).cpp
LIB_OBJS        := $(LIB_SRCS:.cpp=.o)
DEPS_HPP        := circom.hpp calcwit.hpp fr.hpp
BIN             := $(PROJECT)
LIB             := libwitness_$(PROJECT).a

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
$(BIN): $(OBJS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(LIB): $(LIB_OBJS)
	ar rcs $@ $^
	$(OBJCOPY) --prefix-symbols=$(PROJECT)_ $@

%.o: %.cpp $(DEPS_HPP)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(LIB_OBJS) $(BIN) $(LIB)
