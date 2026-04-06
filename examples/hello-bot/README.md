# examples/hello-bot/README.md
# HelloBot — AIOS-Lite Reference Plugin

A minimal working example of an AIOS-Lite plugin.

## Files

| File | Purpose |
|------|---------|
| `plugin.json` | Plugin manifest (name, version, entry point) |
| `hello_bot.py` | Python module containing the `HelloBot` class |

## How to install

```bash
# Copy to the plugin directory
cp -r examples/hello-bot/ OS/var/pkg/plugins/hello-bot/

# Hot-reload without restarting aios (send SIGUSR1 to the aios process)
kill -USR1 $(pgrep -f 'bin/aios')

# Or restart aios
./run.sh
```

## How it works

1. `plugin_loader.py` scans `OS/var/pkg/plugins/` on startup (and on SIGUSR1).
2. It reads `plugin.json` to find the entry point module and bot class.
3. It imports `hello_bot.py` and instantiates `HelloBot`.
4. `HelloBot` is registered with the `Router` at highest priority.
5. When the user types "hello" or "hi", `HelloBot.can_handle()` returns `True`
   and `HelloBot.handle()` returns the greeting response.

## Implementing your own plugin

1. Create a directory under `OS/var/pkg/plugins/<your-plugin>/`.
2. Write a `plugin.json` manifest (see schema in `docs/PLUGIN-API.md`).
3. Write a Python module with a `BaseBot` subclass.
4. Optionally sign the manifest: `bash scripts/plugin-sign.sh OS/var/pkg/plugins/<your-plugin>/`

See [docs/PLUGIN-API.md](../../docs/PLUGIN-API.md) for the full API reference.
