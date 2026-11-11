"""Check the pinned Horizon client crate with the available Rust toolchain."""
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "vendor" / "horizon"


def cargo_executable() -> str:
    configured = os.environ.get("CARGO")
    if configured:
        return configured
    discovered = shutil.which("cargo")
    if discovered:
        return discovered
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
    if not (VENDOR / "Cargo.toml").is_file():
        raise SystemExit(
            "pinned Horizon source is missing at vendor/horizon; see "
            "reference/horizon-source.json"
        )

    env = os.environ.copy()
    if os.name == "nt":
        flags = env.get("CXXFLAGS", "").split()
        if "/utf-8" not in flags:
            flags.append("/utf-8")
        env["CXXFLAGS"] = " ".join(flags)
    env["CARGO_TARGET_DIR"] = str(ROOT / "target" / "horizon")
    return subprocess.call(
        [
            cargo_executable(),
            "check",
            "--locked",
            "-p",
            "horizon-client",
            "--lib",
        ],
        cwd=VENDOR,
        env=env,
    )


if __name__ == "__main__":
    raise SystemExit(main())
