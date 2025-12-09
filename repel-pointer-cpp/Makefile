CXX = clang++
CXXFLAGS = -std=c++17 -Wall -g -I./metal-cpp
OBJCXXFLAGS = -std=c++17 -fobjc-arc -Wall -g
LDFLAGS = -framework Cocoa -framework Metal -framework MetalKit -framework CoreGraphics -framework QuartzCore -framework CoreVideo

BUILD_DIR = build
SRC_CPP = src/Renderer.cpp src/metal_impl.cpp
SRC_MM = src/AppDelegate.mm
OBJ_CPP = $(patsubst src/%.cpp,$(BUILD_DIR)/%.o,$(SRC_CPP))
OBJ_MM = $(patsubst src/%.mm,$(BUILD_DIR)/%.o,$(SRC_MM))
OBJ = $(OBJ_CPP) $(OBJ_MM)
TARGET = $(BUILD_DIR)/RepelPointer

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^

# Compile C++ files (with metal-cpp headers)
$(BUILD_DIR)/%.o: src/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile Objective-C++ files (without metal-cpp headers to avoid conflicts)
$(BUILD_DIR)/%.o: src/%.mm
	@mkdir -p $(dir $@)
	$(CXX) $(OBJCXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
