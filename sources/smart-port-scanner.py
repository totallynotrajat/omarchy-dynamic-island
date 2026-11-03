import subprocess, re, os, json

# Prints one listener per line: port|app|pid|dir|kind
#   app  - human name: the project (package.json, Cargo.toml, go.mod, pyproject)
#          for dev runtimes, or a known app name for everything else
#   kind - framework when recognisable (Next.js, Vite...), else the process name

out = subprocess.run(["ss", "-tlpn"], capture_output=True, text=True).stdout
home = os.path.expanduser("~")

MANIFESTS = ("package.json", "Cargo.toml", "go.mod", "pyproject.toml")

SYSTEM_PORTS = {"53", "631", "111", "22", "5355", "5353", "22000"}

RUNTIMES = {"node", "bun", "deno", "python", "python3", "ruby", "php", "java",
            "uvicorn", "gunicorn", "hypercorn", "dotnet", "beam.smp", "elixir",
            "cargo", "go", "air", "npm", "pnpm", "yarn", "npx", "bunx", "perl"}

KNOWN_APPS = {
    "kdeconnectd": "KDE Connect", "wayvnc": "WayVNC", "adb": "Android Debug Bridge",
    "cloudflared": "Cloudflare Tunnel", "helium": "Helium", "chrome": "Chrome",
    "chromium": "Chromium", "firefox": "Firefox", "t3code": "T3 Code",
    "antigravity": "Antigravity", "code": "VS Code", "cursor": "Cursor",
    "postgres": "PostgreSQL", "mysqld": "MySQL", "mariadbd": "MariaDB",
    "redis-server": "Redis", "valkey-server": "Valkey", "mongod": "MongoDB",
    "docker-proxy": "Docker", "ollama": "Ollama", "nginx": "nginx", "caddy": "Caddy",
    "syncthing": "Syncthing", "spotify": "Spotify", "steam": "Steam",
    "tailscaled": "Tailscale", "obs": "OBS", "jupyter-lab": "JupyterLab",
}

FRAMEWORKS = [
    (r"\bnext(\s|$|/dist)", "Next.js"), (r"\bvite\b", "Vite"), (r"\bastro\b", "Astro"),
    (r"\bnuxt", "Nuxt"), (r"\bremix\b", "Remix"), (r"\bsvelte-kit\b", "SvelteKit"),
    (r"webpack", "webpack"), (r"storybook", "Storybook"), (r"\bexpo\b", "Expo"),
    (r"\bvitepress\b", "VitePress"), (r"docusaurus", "Docusaurus"), (r"\bwrangler\b", "Wrangler"),
    (r"\buvicorn\b", "Uvicorn"), (r"\bgunicorn\b", "Gunicorn"), (r"\bflask\b", "Flask"),
    (r"manage\.py\s+runserver", "Django"), (r"\bjupyter", "Jupyter"), (r"http\.server", "http.server"),
    (r"\brails\b", "Rails"), (r"\bhugo\b", "Hugo"), (r"\bphoenix\b|phx\.server", "Phoenix"),
]


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return ""


def project_name(cwd):
    pkg = os.path.join(cwd, "package.json")
    if os.path.exists(pkg):
        try:
            name = json.loads(read(pkg)).get("name") or ""
            if name:
                return name.split("/")[-1]  # drop npm scope
        except Exception:
            pass
    for manifest, pattern in (("Cargo.toml", r'^\s*name\s*=\s*"([^"]+)"'),
                              ("pyproject.toml", r'^\s*name\s*=\s*"([^"]+)"'),
                              ("go.mod", r'^\s*module\s+(\S+)')):
        m = re.search(pattern, read(os.path.join(cwd, manifest)), re.M)
        if m:
            return os.path.basename(m.group(1))
    return os.path.basename(cwd)


seen = set()
res = []

for line in out.splitlines():
    if "LISTEN" not in line:
        continue
    parts = line.split()
    if len(parts) < 4:
        continue
    local = parts[3]
    port = local.rsplit(":", 1)[-1]
    if not port.isdigit() or port in SYSTEM_PORTS or port in seen:
        continue
    if "%tailscale" in local:  # tailnet-only listeners (tailscale serve etc.)
        continue

    m = re.search(r'users:\(\("([^"]+)",pid=(\d+)', line)
    proc = m.group(1) if m else ""
    pid = m.group(2) if m else "-"

    # Listeners we can't see the owner of are system daemons; skip unless they
    # sit on a typical dev port (a root-owned docker-proxy, say).
    if pid == "-" and int(port) >= 10000:
        continue

    cmdline = read(f"/proc/{pid}/cmdline").replace("\0", " ").strip() if pid != "-" else ""
    exe = ""
    cwd = ""
    if pid != "-":
        try:
            exe = os.readlink(f"/proc/{pid}/exe")
        except Exception:
            pass
        try:
            cwd = os.readlink(f"/proc/{pid}/cwd")
        except Exception:
            pass

    # A compiled binary launched from its own project (cargo run, go build)
    # counts as a dev server too, but only when the folder is a project.
    in_project = cwd not in ("", "/", home) and exe.startswith(cwd + "/") \
        and any(os.path.exists(os.path.join(cwd, f)) for f in MANIFESTS)
    is_runtime = proc in RUNTIMES or os.path.basename(exe) in RUNTIMES or in_project

    # Ephemeral ports belong to language servers, debuggers and IPC sockets,
    # not to things you'd open in a browser.
    if int(port) >= 32768 and not is_runtime:
        continue

    framework = ""
    if is_runtime:
        for pattern, label in FRAMEWORKS:
            if re.search(pattern, cmdline):
                framework = label
                break

    dir_name = ""
    if is_runtime and cwd not in ("", "/", home):
        app = project_name(cwd)
        dir_name = "~" + cwd[len(home):] if cwd.startswith(home + "/") else cwd
    else:
        app = KNOWN_APPS.get(proc) or KNOWN_APPS.get(os.path.basename(exe)) or proc or "Unknown"

    kind = framework or proc or "system"
    if kind == app:
        kind = ""

    seen.add(port)
    res.append(f"{port}|{app}|{pid}|{dir_name}|{kind}")

res.sort(key=lambda x: int(x.split("|")[0]))
print("\n".join(res))
