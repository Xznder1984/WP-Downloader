# Live Wallpaper — Makefile
# Builds the livewallpaper daemon for macOS Intel (x86_64)

CC      = swiftc
TARGET  = x86_64-apple-macosx14.0
BUILD   = Build
BINARY  = $(BUILD)/livewallpaper
SOURCES = $(wildcard Sources/*.swift)
FRAMEWORKS = -framework AppKit -framework AVFoundation -framework CoreMedia

OPTIMIZE = -O -whole-module-optimization
WARNINGS = -warnings-as-errors
FLAGS    = -target $(TARGET) $(OPTIMIZE) $(WARNINGS) $(FRAMEWORKS)

.PHONY: all clean install uninstall

all: $(BINARY)

$(BUILD):
	mkdir -p $(BUILD)

$(BINARY): $(SOURCES) | $(BUILD)
	$(CC) $(FLAGS) -o $(BINARY) $(SOURCES)

clean:
	rm -rf $(BUILD)

install: $(BINARY)
	install -d /usr/local/bin
	install -m 755 $(BINARY) /usr/local/bin/livewallpaper
	install -m 755 Scripts/wp /usr/local/bin/wp
	install -m 755 Scripts/purge-memory /usr/local/bin/purge-memory
	mkdir -p ~/Library/LaunchAgents
	install -m 644 Resources/com.xander.purge.plist ~/Library/LaunchAgents/com.xander.purge.plist
	@echo "Installed to /usr/local/bin/"

uninstall:
	rm -f /usr/local/bin/livewallpaper
	rm -f /usr/local/bin/wp
	rm -f /usr/local/bin/purge-memory
	launchctl unload ~/Library/LaunchAgents/com.xander.purge.plist 2>/dev/null || true
	rm -f ~/Library/LaunchAgents/com.xander.purge.plist
	@echo "Uninstalled from /usr/local/bin/"
