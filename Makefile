zzd: src/main.zig src/root.zig build.zig build.zig.zon
	zig build -Doptimize=ReleaseSafe
	cp zig-out/bin/zzd zzd

install: zzd
	install zzd ${HOME}/.bin/

clean:
	rm -rf zig-out .zig-cache zzd

.PHONY: install clean
