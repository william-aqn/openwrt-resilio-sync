#!/usr/bin/env python3
"""Check release inputs, JSON metadata, and accidental sensitive artifacts."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
for path in (ROOT / "luci-app-resilio-sync").rglob("*.json"):
    json.loads(path.read_text(encoding="utf-8"))
inputs = (ROOT / "resilio-sync/files/runtime.conf").read_text()
assert len(re.findall(r"_SHA256='[a-f0-9]{64}'", inputs)) == 1
assert "debian" not in inputs.lower()
for package in ("glibc-compat", "libxcrypt-glibc-compat"):
    recipe = (ROOT / package / "Makefile").read_text()
    assert re.search(r"^PKG_HASH:=[a-f0-9]{64}$", recipe, re.M), package
assert "/stable/" not in inputs and "/latest/" not in inputs
assert "https://download-cdn.resilio.com/3.1.2.1076/" in inputs
for directory in ("resilio-sync", "luci-app-resilio-sync", "glibc-compat", "libxcrypt-glibc-compat", "scripts", "tests", ".github"):
    for path in (ROOT / directory).rglob("*"):
        if not path.is_file() or "__pycache__" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        assert not text.startswith("\ufeff"), path
        assert not re.search(r"[\u0400-\u04ff]", text), path
        assert ("-----BEGIN " + "PRIVATE KEY-----") not in text, path
        assert not re.search(r"\$6\$[^'\s]+\$[./A-Za-z0-9]{86}", text), path
print("JSON metadata, pinned inputs, English-only sources and secret checks passed")
