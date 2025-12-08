CXX = clang++
CXXFLAGS = -std=c++17 -fobjc-arc -Wall -g
LDFLAGS = -framework Cocoa -framework Metal -framework MetalKit -framework CoreGraphics -framework QuartzCore

BUILD_DIR = build
SRC = src/main.mm src/Renderer.mm
OBJ = $(patsubst src/%.mm,$(BUILD_DIR)/%.o,$(SRC))
TARGET = $(BUILD_DIR)/RepelPointer

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CXX) $(LDFLAGS) -o $@ $^

$(BUILD_DIR)/%.o: src/%.mm
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -rf $(BUILD_DIR)
