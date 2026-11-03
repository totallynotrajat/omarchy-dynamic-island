import subprocess, re, os, json

out = subprocess.run(["ss", "-tlpn"], capture_output=True, text=True).stdout
seen = set()
res = []

for line in out.splitlines():
    if "LISTEN" not in line: continue
    parts = line.split()
    if len(parts) < 4: continue
    port = parts[3].rsplit(":", 1)[-1]
    if not port.isdigit() or port in ["53", "631"]: continue
    if port in seen: continue
    
    m = re.search(r'users:\(\("([^"]+)",pid=(\d+)', line)
    proc_name = m.group(1) if m else "process"
    pid = m.group(2) if m else "-"
    app_name = proc_name
    
    if pid != "-":
        try:
            cwd = os.readlink(f"/proc/{pid}/cwd")
            pkg = os.path.join(cwd, "package.json")
            cargo = os.path.join(cwd, "Cargo.toml")
            gomod = os.path.join(cwd, "go.mod")
            if os.path.exists(pkg):
                try:
                    with open(pkg) as f:
                        data = json.load(f)
                        app_name = data.get("name", os.path.basename(cwd))
                except Exception:
                    app_name = os.path.basename(cwd)
            elif os.path.exists(cargo):
                try:
                    with open(cargo) as f:
                        cm = re.search(r'name\s*=\s*"([^"]+)"', f.read())
                        if cm: app_name = cm.group(1)
                except Exception:
                    app_name = os.path.basename(cwd)
            elif os.path.exists(gomod):
                try:
                    with open(gomod) as f:
                        gm = re.search(r'module\s+([^\s]+)', f.read())
                        if gm: app_name = os.path.basename(gm.group(1))
                except Exception:
                    app_name = os.path.basename(cwd)
            else:
                base = os.path.basename(cwd)
                if base: app_name = base
        except Exception:
            pass
            
    seen.add(port)
    res.append(f"{port}|{app_name}|{pid}")

# Sort by port number numerically
res.sort(key=lambda x: int(x.split("|")[0]))
print("\n".join(res))
