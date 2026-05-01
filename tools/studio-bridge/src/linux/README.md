# Linux/Wine Support for studio-bridge

Run Roblox Studio headlessly on Linux via Wine 11, Xvfb, and Mesa llvmpipe. This enables AI agents and CI pipelines to launch Studio in devcontainers and GitHub Actions without a physical display or GPU.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Wine | 11.0+ | Windows compatibility layer |
| Xvfb | any | Virtual X11 framebuffer |
| openbox | any | Window manager (required for modal dialogs) |
| x86_64-w64-mingw32-gcc | any | Cross-compiler for write-cred.exe |
| unzip | any | Extract Studio packages |

All can be installed via `studio-bridge linux setup --install-deps` on Debian/Ubuntu.

## Quick Start

```bash
# One-time setup: install deps, download Studio, patch shaders, write FFlags
studio-bridge linux setup --install-deps

# Inject authentication (reads $ROBLOSECURITY env var)
studio-bridge linux inject-credentials

# Verify everything is ready
studio-bridge linux status

# Launch Studio and execute code through the bridge
studio-bridge exec 'print("Hello from Linux!")'
```

## Architecture

```
linux-config.ts             Path resolution + constants (STUDIO_DIR, WINEPREFIX, DISPLAY)
linux-wine-env.ts           Wine env vars (DISPLAY, Mesa overrides, WINEDEBUG)
linux-prerequisites.ts      Check/install system deps
linux-display-manager.ts    Start/stop Xvfb + openbox
linux-version-resolver.ts   Fetch Studio version from CDN
linux-studio-installer.ts   Download 34 zip packages, extract, write AppSettings.xml
linux-shader-patcher.ts     Binary-patch #version 150 → #version 420
linux-fflags.ts             Write ClientAppSettings.json (D3D11 renderer flags)
linux-credential-writer.ts  Compile write-cred.c, inject 3 credentials via Wine
write-cred.c                Bundled C source for Windows Credential Manager writes
```

The process manager (`src/process/studio-process-manager.ts`) uses lazy `import()` for all Linux modules — zero overhead on Windows/macOS.

## How It Works

### Rendering: D3D11 via WineD3D

Studio must use the D3D11 renderer, not OpenGL. Wine's OpenGL/EGL backend has a bug where `wglSwapBuffers` always targets the same EGL surface regardless of HWND, which breaks DockWidget rendering (Explorer, Properties, Toolbox all stay black).

WineD3D translates D3D11 calls to OpenGL internally but manages per-window swapchains correctly. The FFlags force this path:

```json
{
  "FFlagDebugGraphicsPreferD3D11": true,
  "FFlagDebugGraphicsDisableVulkan": true,
  "FFlagDebugGraphicsDisableD3D11FL10": true,
  "FFlagDebugGraphicsDisableOpenGL": true
}
```

### Shader Patching

Studio's GLSL shader pack declares `#version 150` but uses `unpackHalf2x16()`, which requires GLSL 4.20+. NVIDIA/AMD drivers are lenient about this; Mesa's llvmpipe is strict and rejects the shaders.

The fix is a binary patch: replace all `#version 150` with `#version 420` in `shaders/shaders_glsl3.pack`. Both strings are exactly 12 bytes, so the patch is safe and in-place.

### Authentication

Studio expects three entries in Windows Credential Manager:

1. `https://www.roblox.com:RobloxStudioAuthuserid` → numeric user ID
2. `https://www.roblox.com:RobloxStudioAuthCookies` → `.ROBLOSECURITY` (cookie name)
3. `https://www.roblox.com:RobloxStudioAuth.ROBLOSECURITY{userId}` → the cookie value

The `linux inject-credentials` command:
1. Resolves the cookie via `getRobloxCookieAsync()` (env var → Wine cred store → interactive prompt)
2. Fetches the user ID from `users.roblox.com/v1/users/authenticated`
3. Compiles `write-cred.c` with MinGW (one-time)
4. Runs `wine write-cred.exe` three times to inject all entries

On first launch, Studio exchanges the cookie for OAuth2 tokens. Subsequent launches use the refresh token, so the original cookie can expire.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STUDIO_DIR` | `~/roblox-studio` | Studio installation directory |
| `WINEPREFIX` | `~/.wine` | Wine prefix directory |
| `DISPLAY` | `:99` | X11 display number |
| `ROBLOSECURITY` | — | .ROBLOSECURITY cookie for auth |

## CLI Commands

### `studio-bridge linux setup`

Install Wine dependencies and Roblox Studio.

| Flag | Description |
|------|-------------|
| `--install-deps` | Install system deps via apt-get (requires sudo) |
| `--version <hash>` | Studio version hash (default: latest from CDN) |
| `--studio-dir <path>` | Override installation directory |
| `--skip-shaders` | Skip shader patching |
| `--force` | Force reinstall even if same version exists |

### `studio-bridge linux inject-credentials`

Inject .ROBLOSECURITY cookie into Wine Credential Manager.

| Flag | Description |
|------|-------------|
| `--cookie <value>` | Explicit cookie value |
| `--cookie -` | Read cookie from stdin |
| _(none)_ | Falls back to `$ROBLOSECURITY` or interactive prompt |

### `studio-bridge linux status`

Read-only health check. Reports on prerequisites, display, Studio installation, FFlags, shaders, and authentication. Exits with code 1 if any issues found.

## Resource Requirements

- **Disk**: ~813MB for Studio installation + ~450MB download cache
- **RAM**: ~450MB–800MB at runtime. 16GB recommended for the host; 8GB may OOM.
- **CPU**: No GPU required — Mesa llvmpipe does software rendering.
