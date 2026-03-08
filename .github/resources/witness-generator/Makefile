.PHONY: linux macos windows linux-lib macos-lib windows-lib build clean

# ---- Arguments ----
ifndef PROJECT
$(error PROJECT is not set. Usage: make PROJECT=<name>. E.g.: make PROJECT=pol linux)
endif

# ---- Common ----
CXX             := g++
AR              := ar
CXXFLAGS_COMMON := -std=c++11 -O3 -I. -Wno-address-of-packed-member
SRCS            := main.cpp calcwit.cpp fr.cpp $(PROJECT).cpp
LIB_SRCS        := calcwit.cpp fr.cpp $(PROJECT).cpp
OBJS            := $(SRCS:.cpp=.o)
LIB_OBJS        := $(LIB_SRCS:.cpp=.o)
DEPS_HPP        := circom.hpp calcwit.hpp fr.hpp
BIN             := $(PROJECT)
LIB             := lib$(PROJECT).a

# ---- Linux (x86_64 and aarch64) ----
linux: CXXFLAGS=$(CXXFLAGS_COMMON)
linux: LDFLAGS=-static
linux: LDLIBS=-lgmp
linux: $(BIN)

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

# ---- Linux static library ----
linux-lib: CXXFLAGS=$(CXXFLAGS_COMMON) -fPIC
linux-lib: $(LIB)

# ---- macOS static library ----
macos-lib: CXXFLAGS=$(CXXFLAGS_COMMON) -I/opt/homebrew/include -include gmp_patch.hpp -fPIC
macos-lib: $(LIB)

# ---- Windows static library (MinGW) ----
windows-lib: CXXFLAGS=$(CXXFLAGS_COMMON) -I/include -Duint="unsigned int" -fPIC
windows-lib: $(LIB)

# ---- Rules ----
$(BIN): $(OBJS)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(LIB): $(LIB_OBJS)
	$(AR) rcs $@ $^

%.o: %.cpp $(DEPS_HPP)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(LIB_OBJS) $(BIN) $(LIB)

