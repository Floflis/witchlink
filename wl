#!/usr/bin/env bash
# Witchlink r1: manifest-backed, multi-source FIFO links.
set -Eeuo pipefail
VERSION='1.0.0-r1'
SELF_DIR=$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")" && pwd -P)
log(){ printf 'witchlink: %s\n' "$*" >&2; }
die(){ log "error: $*"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
usage(){
cat <<'HELP'
Witchlink r1
  wl create OUTPUT SOURCE [SOURCE ...]  Create hidden .wlref manifest
  wl add OUTPUT SOURCE [SOURCE ...]     Append source files
  wl render MANIFEST                    Stream composed bytes to stdout
  wl serve MANIFEST                     Keep OUTPUT.wl alive as a FIFO
  wl enable|disable|status MANIFEST     Manage/show per-user systemd service
  wl install-user-service               Install user service and ~/.local/bin/wl
  wl version | help
Sources are concatenated byte-for-byte. No separator or newline is inserted.
FUSE is deferred to r2.
HELP
}
absolute_path(){
 local p=$1 d b
 if [[ $p == */* ]]; then d=\${p%/*}; b=\${p##*/}; [[ -n $d ]] || d=/; else d=.; b=$p; fi
 [[ -n $b && $b != . && $b != .. ]] || die "invalid path: $p"
 [[ -d $d ]] || die "directory does not exist: $d"
 d=$(cd -- "$d" && pwd -P) || die "cannot resolve directory: $d"
 printf '%s/%s\n' "\${d%/}" "$b"
}
manifest_for(){ printf '%s/.%s.wlref\n' "\${1%/*}" "\${1##*/}"; }
manifest_output(){
 local v d
 v=$(jq -er '.output | select(type=="string" and length>0)' "$1") || die 'invalid manifest output'
 if [[ $v == /* ]]; then printf '%s\n' "$v"; else d=$(cd -- "$(dirname -- "$1")" && pwd -P); printf '%s/%s\n' "$d" "$v"; fi
}
validate(){
 [[ -f $1 ]] || die "manifest not found: $1"
 jq -e '(.version==1) and (.output|type=="string" and length>0) and (.segments|type=="array" and length>0) and all(.segments[]; (.type=="file" and (.source|type=="string" and length>0)) or (.type=="git-blob" and (.repo|type=="string" and length>0) and (.oid|type=="string" and test("^[0-9a-fA-F]{40,64}$"))))' "$1" >/dev/null || die "invalid manifest: $1"
}
resolve_source(){
 if [[ $2 == /* ]]; then printf '%s\n' "$2"; else printf '%s/%s\n' "$(cd -- "$(dirname -- "$1")" && pwd -P)" "$2"; fi
}
atomic_manifest(){
 local f=$1 data=$2 tmp
 tmp=$(mktemp "\${f}.tmp.XXXXXX") || die 'cannot create temporary manifest'
 printf '%s\n' "$data" > "$tmp" || { rm -f -- "$tmp"; die 'cannot write manifest'; }
 chmod 0644 "$tmp"; mv -f -- "$tmp" "$f"
}
cmd_create(){
 (($#>=2)) || die 'usage: wl create OUTPUT SOURCE [SOURCE ...]'
 need jq
 local out manifest dir src stored data
 out=$(absolute_path "$1"); shift; manifest=$(manifest_for "$out"); dir=\${out%/*}
 [[ ! -e $manifest ]] || die "manifest exists: $manifest"
 [[ ! -e $out && ! -p $out ]] || die "output exists: $out"
 data=$(jq -n --arg output "\${out##*/}" '{version:1,output:$output,segments:[]}')
 for src in "$@"; do
  [[ -f $src ]] || die "source is not a regular file: $src"
  src=$(absolute_path "$src")
  if [[ \${src%/*} == "$dir" ]]; then stored=\${src##*/}; else stored=$src; fi
  data=$(jq --arg source "$stored" '.segments += [{type:"file",source:$source}]' <<<"$data")
 done
 atomic_manifest "$manifest" "$data"
 log "created $manifest"; log "FIFO path: $out.wl"
}
cmd_add(){
 (($#>=2)) || die 'usage: wl add OUTPUT SOURCE [SOURCE ...]'
 need jq
 local out manifest dir src stored data
 out=$(absolute_path "$1"); shift; manifest=$(manifest_for "$out"); validate "$manifest"; dir=\${manifest%/*}; data=$(cat -- "$manifest")
 for src in "$@"; do
  [[ -f $src ]] || die "source is not a regular file: $src"
  src=$(absolute_path "$src")
  if [[ \${src%/*} == "$dir" ]]; then stored=\${src##*/}; else stored=$src; fi
  data=$(jq --arg source "$stored" '.segments += [{type:"file",source:$source}]' <<<"$data")
 done
 atomic_manifest "$manifest" "$data"; log "updated $manifest"
}
stream_manifest(){
 local m=$1 row type src repo oid path
 # Base64-encoded JSON records safely preserve tabs, newlines and backslashes in paths.
 while IFS= read -r row; do
  local record
  record=$(printf '%s' "$row" | base64 -d) || return 1
  type=$(jq -r '.type' <<<"$record")
  case $type in
   file)
    src=$(jq -r '.source' <<<"$record"); path=$(resolve_source "$m" "$src")
    [[ -f $path && -r $path ]] || { log "missing/unreadable source: $path"; return 1; }
    cat -- "$path" || return 1 ;;
   git-blob)
    need git; repo=$(jq -r '.repo' <<<"$record"); oid=$(jq -r '.oid' <<<"$record")
    git -C "$repo" cat-file blob "$oid" || return 1 ;;
   *) log "unsupported segment: $type"; return 1 ;;
  esac
 done < <(jq -r '.segments[] | @base64' "$m")
}
cmd_render(){ (($#==1)) || die 'usage: wl render MANIFEST'; need jq; validate "$1"; stream_manifest "$1"; }
cmd_serve(){
 (($#==1)) || die 'usage: wl serve MANIFEST'
 need jq; need mkfifo
 local m out fifo stopping=0
 m=$(absolute_path "$1"); validate "$m"; out=$(manifest_output "$m"); fifo="$out.wl"
 [[ ! -e $out || -p $out ]] || die "refusing to replace non-FIFO output: $out"
 [[ ! -e $fifo || -p $fifo ]] || die "refusing to replace non-FIFO path: $fifo"
 [[ -p $fifo ]] || mkfifo -m 0600 -- "$fifo" || die "cannot create FIFO: $fifo"
 log "serving $fifo from $m"; log 'FIFO node is retained; readers are served sequentially.'
 trap 'stopping=1' INT TERM HUP
 while (( ! stopping )); do
  if ! stream_manifest "$m" > "$fifo"; then
   (( stopping )) && break
   log 'stream failed (possibly a disconnected reader); retrying'; sleep 1
  else
   # Let the current reader observe EOF and close before opening the next stream.
   sleep 0.1
  fi
 done
 log 'server stopped; FIFO retained'
}
unit_for(){ need systemd-escape; systemd-escape --path --template=witchlink@.service "$1"; }
cmd_enable(){ (($#==1)) || die 'usage: wl enable MANIFEST'; local m u; m=$(absolute_path "$1"); validate "$m"; u=$(unit_for "$m"); systemctl --user enable --now "$u"; }
cmd_disable(){ (($#==1)) || die 'usage: wl disable MANIFEST'; local m u; m=$(absolute_path "$1"); u=$(unit_for "$m"); systemctl --user disable --now "$u" || true; }
cmd_status(){
 (($#==1)) || die 'usage: wl status MANIFEST'
 local m out fifo u
 m=$(absolute_path "$1"); validate "$m"; out=$(manifest_output "$m"); fifo="$out.wl"; u=$(unit_for "$m")
 printf 'Manifest: %s\nFIFO: %s\n' "$m" "$fifo"
 [[ -p $fifo ]] && echo 'FIFO: present' || echo 'FIFO: absent'
 systemctl --user --no-pager --full status "$u" 2>&1 || true
}
cmd_install(){
 (($#==0)) || die 'usage: wl install-user-service'
 local bindir unitdir self
 bindir="$HOME/.local/bin"; unitdir="$HOME/.config/systemd/user"
 mkdir -p -- "$bindir" "$unitdir"
 self=$(readlink -f -- "\${BASH_SOURCE[0]}")
 if [[ $self != "$bindir/wl" ]]; then install -m 0755 -- "$self" "$bindir/wl"; fi
 cat > "$unitdir/witchlink@.service" <<'UNIT'
[Unit]
Description=Witchlink FIFO server for %f
After=default.target
[Service]
Type=simple
ExecStart=%h/.local/bin/wl serve %f
Restart=on-failure
RestartSec=2
[Install]
WantedBy=default.target
UNIT
 systemctl --user daemon-reload
 log "installed $bindir/wl and $unitdir/witchlink@.service"
 log "run: wl enable /absolute/path/to/.output.wlref"
 log 'For service startup without login, enable user lingering with loginctl enable-linger.'
}
main(){
 (($#)) || { usage; exit 2; }
 local cmd=$1; shift
 case $cmd in
  create) cmd_create "$@";; add) cmd_add "$@";; render|_stream) cmd_render "$@";; serve) cmd_serve "$@";;
  enable) cmd_enable "$@";; disable) cmd_disable "$@";; status) cmd_status "$@";; install-user-service) cmd_install "$@";;
  version|-V|--version) echo "Witchlink $VERSION";; help|-h|--help) usage;; *) die "unknown command: $cmd";;
 esac
}
main "$@"
