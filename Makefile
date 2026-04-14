zzd: main.zig
	zig build-exe --name zzd -O ReleaseFast main.zig

install: zzd
	install zzd ${HOME}/.bin/
