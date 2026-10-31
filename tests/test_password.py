#!/usr/bin/env python3
"""Exercise password rotation with isolated credentials and a mock service."""
import fcntl
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "resilio-sync/files/resilio-sync-password").read_text()
with tempfile.TemporaryDirectory(prefix="resilio-password-test-") as directory:
    root = Path(directory)
    credentials = root / "credentials"
    credentials.mkdir(mode=0o700)
    password_file = credentials / "webui-password.hash"
    password_file.write_text("original-hash\n")
    (credentials / "server.crt").write_text("certificate")
    (credentials / "server.key").write_text("private-key-fixture")
    service = root / "service"
    service.write_text(f'''#!/bin/sh
case "$1" in
running) test -f '{root}/running' ;;
reload) echo reload >> '{root}/reloads'; test ! -f '{root}/reload-fail' ;;
*) exit 1 ;;
esac
''')
    service.chmod(0o700)
    # Only the disposable copy is redirected. No production path is written.
    helper = root / "password"
    source = source.replace("credentials=/etc/resilio-sync", f"credentials='{credentials}'")
    source = source.replace("service=/etc/init.d/resilio-sync", f"service='{service}'")
    source = source.replace("lock=/var/lock/resilio-sync-password.lock", f"lock='{root}/lock'")
    source = source.replace('[ "$(id -u)" = 0 ]', f'[ "$(id -u)" = {os.getuid()} ]')
    helper.write_text(source)
    helper.chmod(0o700)
    count = 0

    def run(password, code, env=None):
        global count
        result = subprocess.run([str(helper), "--password-stdin"], input=password + "\n",
                                text=True, capture_output=True, env=env)
        assert result.returncode == code, (code, result.returncode, result.stderr)
        assert not result.stdout and password not in result.stderr
        assert not list(credentials.glob(".password.*")), "Temporary hash files leaked"
        count += 1

    for value in ("short", "x" * 129, "valid-length\tbad"):
        before = password_file.read_bytes()
        run(value, 2)
        assert password_file.read_bytes() == before

    password = "A complex ' test $() ; & \\ 1234"
    run(password, 10)
    hashed = password_file.read_text().strip()
    calculated = subprocess.check_output(["openssl", "passwd", "-6", "-salt", hashed.split("$")[2], "-stdin"], input=password + "\n", text=True).strip()
    assert calculated == hashed and (password_file.stat().st_mode & 0o777) == 0o600
    assert not (root / "reloads").exists(), "Stopped service was started"

    (root / "running").touch()
    run("Changed password 1234", 0)
    assert (root / "reloads").read_text().count("reload") == 1
    before = password_file.read_bytes()
    (root / "reload-fail").touch()
    run("Rollback password 1234", 6)
    assert password_file.read_bytes() == before
    (root / "reload-fail").unlink()

    with (root / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run("Concurrent password 1234", 4)
        assert password_file.read_bytes() == before

    fake_bin = root / "bin"
    fake_bin.mkdir()
    openssl = fake_bin / "openssl"
    openssl.write_text("#!/bin/sh\nexit 1\n")
    openssl.chmod(0o700)
    run("Failure password 1234", 5, {**os.environ, "PATH": f"{fake_bin}:{os.environ['PATH']}"})
    assert password_file.read_bytes() == before
    (credentials / "server.crt").unlink()
    run("Uninitialized password 1234", 3)
    assert password_file.read_bytes() == before
    print(f"Passed {count} isolated password tests: validation, hashing, stopped/running service, rollback, lock and write failure")
