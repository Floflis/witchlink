# Witchlink r1

Witchlink composes a virtual byte stream from multiple source files and exposes it through a persistent named pipe (FIFO). r1 uses a JSON .wlref manifest and an optional per-user systemd service. FUSE is deferred to r2.

## Requirements

- Bash 4.3+
- jq
- mkfifo and base64 (GNU coreutils or equivalent)
- systemd user session for automatic service management (optional)

## Quick start

```bash
./wl create joined.txt file1.txt file2.txt
./wl render .joined.txt.wlref > joined-copy.txt
./wl serve .joined.txt.wlref
```

In another terminal, read the stream:

```bash
cat joined.txt.wl
```

The FIFO is OUTPUT.wl; the hidden manifest is .OUTPUT.wlref beside it. create does not start a daemon. serve keeps the FIFO node present and serves readers sequentially. Stop it with Ctrl-C; the FIFO is retained.

## Add sources

```bash
./wl add joined.txt file3.txt
```

Sources beside the manifest are stored as relative paths, preserving references when the containing directory tree moves. Sources elsewhere are stored as absolute paths.

## Persistent user service

```bash
./wl install-user-service
wl enable /absolute/path/to/.joined.txt.wlref
wl status /absolute/path/to/.joined.txt.wlref
wl disable /absolute/path/to/.joined.txt.wlref
```

The service starts with the user's systemd session. To start it at boot without an interactive login, user lingering may be enabled with loginctl enable-linger.

## Manifest

```json
{
  "version": 1,
  "output": "joined.txt",
  "segments": [
    { "type": "file", "source": "file1.txt" },
    { "type": "file", "source": "file2.txt" }
  ]
}
```

File segments are streamed with cat, not command substitution or echo. No separators or newlines are inserted, preserving exact bytes including NUL. Git blob segments are also supported:

```json
{ "type": "git-blob", "repo": "/absolute/path/to/repo", "oid": "FULL_GIT_OBJECT_ID" }
```

Git blob repo paths are interpreted relative to the service process working directory, so use absolute paths for service-managed manifests.

## FIFO semantics and limitations

- A FIFO is a byte stream, not a seekable regular file. Applications requiring seeking, reliable file size, or random access will not work.
- Each reader receives a complete stream sequentially. Concurrent readers are not broadcast subscribers; they wait their turn.
- A reader closing early can break the writer. The server retries for the next reader; systemd restarts it if it exits.
- Sources are read when each reader opens the FIFO. Changes between reads appear in later reads; changes during a read may produce a mixed snapshot.
- The FIFO node persists on disk, but the serving process does not survive reboot. systemd starts it again with the user's session. User lingering enables the user manager without login.
- Manifests describe file and Git-object sources only. They are never evaluated as shell commands.
- The FIFO is created owner-only (mode 0600). Use deliberate permission/ACL changes if cross-user access is required.

FUSE mounting, seekable file semantics and kernel integration are outside r1 and reserved for r2.
