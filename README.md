# zigget

a simple tool for clone and build zig sources,

do `zigget install zigtools/zls` command list:

1. git clone https://github.com/zigtools/zls $HOME/.zigget/source/zigtools/zls
2. zig build -Doptimize=ReleaseFast
3. ln -s $HOME/.zigget/source/zigtools/zls/zig-out/bin/zls $HOME/.zigget/bin/zls

## usage

`zigget command options`

```
install, git clone repo, build, and create symlink
update, git pull repo and build
remove, remove installed repo
list, for list all install repo
```
