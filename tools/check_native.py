"""Check or test the native adapter against the pinned local Horizon checkout."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def cargo_executable() -> str:
    configured = os.environ.get("CARGO")
    if configured:
        return configured
    discovered = shutil.which("cargo")
    if discovered:
        return discovered
    # Keep the original Windows development-machine fallback, but do not make
    # it the only way to run the check.
    if os.name == "nt":
        candidate = Path(
            r"K:\Rust\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin\cargo.exe"
        )
        if candidate.is_file():
            return str(candidate)
    raise SystemExit(
        "cargo was not found; install the toolchain in rust-toolchain.toml or set CARGO"
    )


def main() -> int:
    vendor = ROOT / "vendor" / "horizon"
    if not (vendor / "Cargo.toml").is_file():
        raise SystemExit(
            "pinned Horizon source is missing at vendor/horizon; see "
            "reference/horizon-source.json and reference/native-development.md"
        )

    env = os.environ.copy()
    if os.name == "nt":
        flags = env.get("CXXFLAGS", "").split()
        if "/utf-8" not in flags:
            flags.append("/utf-8")
        env["CXXFLAGS"] = " ".join(flags)
    env["CARGO_TARGET_DIR"] = str(ROOT / "target" / "native")

    if "--test" in sys.argv[1:]:
        command = ["test", "--tests", "--locked"]
    else:
        command = ["check", "--locked"]
    command.extend(["--manifest-path", str(ROOT / "native" / "Cargo.toml")])
    return subprocess.call([cargo_executable(), *command], cwd=ROOT, env=env)


if __name__ == "__main__":
    raise SystemExit(main())
