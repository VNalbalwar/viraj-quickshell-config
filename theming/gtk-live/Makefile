# builds the GIO module (one file serves GTK3 and GTK4) into ./build; install.sh copies it to ~/.local/lib/qs-gtk-live
CFLAGS ?= -O2 -Wall
build/libqs-gtk-live.so: qs-gtk-live.c
	@mkdir -p build
	$(CC) $(CFLAGS) -shared -fPIC -o $@ $< $(shell pkg-config --cflags --libs gio-2.0) -ldl

clean:
	rm -rf build
