.PHONY: linux macos windows build clean

# ---- Arguments ----
ifndef PROJECT
$(error PROJECT is not set. Usage: make PROJECT=<name>. E.g.: make PROJECT=pol linux)
endif

# ---- Common ----
CXX             := g++
CXXFLAGS_COMMON := -std=c++11 -O3 -I. -Wno-address-of-packed-member
SRCS            := main.cpp calcwit.cpp fr.cpp $(PROJECT).cpp
OBJS            := $(SRCS:.cpp=.o)
DEPS_HPP        := circom.hpp calcwit.hpp fr.hpp
BIN             := $(PROJECT)

# ---- Linux x86_64 ----
linux: CXXFLAGS=$(CXXFLAGS_COMMON)
linux: LDFLAGS=-static
linux: LDLIBS=-lgmp
linux: $(BIN)

# ---- Linux aarch64 (cross-compile) ----
linux_aarch64: CXX=aarch64-linux-gnu-g++
linux_aarch64: CXXFLAGS=$(CXXFLAGS_COMMON)
linux_aarch64: LDFLAGS=-static
linux_aarch64: LDLIBS=-lgmp
linux_aarch64: $(BIN)

# ---- macOS ----
macos: CXXFLAGS=$(CXXFLAGS_COMMON) -I/opt/homebrew/include -include gmp_patch.hpp
macos: LDFLAGS=-Wl,-search_paths_first -Wl,-dead_strip
macos: LDLIBS=/opt/homebrew/lib/libgmp.a
macos: $(BIN)

# ---- Windows (MinGW) ----
windows: CXXFLAGS=$(CXXFLAGS_COMMON) -I/include -Duint="unsigned int"
windows: LDFLAGS=-static
windows: LDLIBS=-L/lib -lgmp -lmman
windows: $(BIN)

# ---- Rules ----
$(BIN): $(OBJS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

%.o: %.cpp $(DEPS_HPP)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(BIN)

