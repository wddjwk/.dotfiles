#!/usr/bin/env python3
"""Dotfile manager: create symlinks from repo to local paths."""

import argparse
import json
import os
import platform
import shutil
from pathlib import Path

MAPPING_FILE = "dot_conf/mapping.json"
LOCAL_CONF = "dot_conf/local.json"
REPO_ROOT = os.path.dirname(os.path.abspath(__file__))


# ── Color / Style ────────────────────────────────────────────

class Style:
    """ANSI escape wrapper; auto-disabled on Windows."""

    def __init__(self):
        self._on = platform.system() != "Windows"

    def _wrap(self, code, text):
        return f"\033[{code}m{text}\033[0m" if self._on else text

    # foregrounds
    def red(self, t):       return self._wrap("31", t)
    def green(self, t):     return self._wrap("32", t)
    def yellow(self, t):    return self._wrap("33", t)
    def blue(self, t):      return self._wrap("34", t)

    # backgrounds
    def bg_red(self, t):    return self._wrap("41", t)
    def bg_green(self, t):  return self._wrap("42", t)
    def bg_yellow(self, t): return self._wrap("43", t)
    def bg_blue(self, t):   return self._wrap("44", t)

    # styles
    def bold(self, t):      return self._wrap("1", t)
    def underline(self, t): return self._wrap("4", t)

    # composite helpers — match original naming conventions
    def link(self, t):       return self.underline(self.blue(t))
    def bright_link(self, t): return self.bold(self.underline(self.blue(t)))

    # tags used in log lines
    def tag_skip(self, t):    return self.bg_yellow(t)        # [SKIPPED]
    def tag_success(self, t): return self.bg_green(t)         # [SUCCESS]
    def tag_fail(self, t):    return self.bg_red(t)           # [FAILED, BROKEN SYMBOLIC]
    def tag_yellow(self, t):  return self.yellow(t)           # [RemoveDir], [REPO-MISS], etc.
    def tag_green(self, t):   return self.green(t)            # [Link exist], [Rename]
    def tag_red(self, t):     return self.red(t)              # [Exception]


s = Style()


# ── Helpers ──────────────────────────────────────────────────

def os_key() -> str:
    return "win" if platform.system() == "Windows" else "linux"


def load_variables() -> dict:
    """Load template variables from local.json; defaults to ~."""
    defaults = {"bash_home": "~"}
    if os.path.exists(LOCAL_CONF):
        with open(LOCAL_CONF, "r", encoding="utf-8") as f:
            data = json.load(f)
            if "bash-home" in data and "bash_home" not in data:
                data["bash_home"] = data["bash-home"]
            defaults.update(data)
    return defaults


def expand_local(path: str, variables: dict) -> str:
    """Expand ~ and ${var} in a local path."""
    for key, val in variables.items():
        path = path.replace(f"${{{key}}}", val)
    return os.path.normpath(os.path.expanduser(path))


def expand_repo(path: str) -> str:
    """Resolve a repo-relative path to absolute."""
    return os.path.normpath(os.path.join(REPO_ROOT, path))


def _log(msg: str):
    print(f"[LOG] {msg}")


def _warn(msg: str):
    print(f"{s.tag_skip('[SKIPPED]')} {msg}")


# ── Symlink core ─────────────────────────────────────────────

def _remove_path(path: str):
    """Remove a file, directory, or symlink at *path*."""
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path)
        _log(f"{s.tag_yellow('[RemoveDir]')}: Delete {s.link(path)}")
    elif os.path.islink(path):
        os.unlink(path)
        _log(f"{s.tag_yellow('[RemoveLink]')}: Delete {s.link(path)}")
    else:
        os.remove(path)
        _log(f"{s.tag_yellow('[RemoveFile]')}: Delete {s.link(path)}")


def _make_link(repo: str, local: str):
    """Create symlink *local* → *repo*. Remove existing path first."""

    # repo source missing
    if not os.path.exists(repo):
        _warn(
            f"{s.tag_yellow('[CONF-MAPPED,REPO-MISS]')}: {s.link(repo)}"
            f" unexists, skip create this file's symbolink to {s.link(local)}"
        )
        return

    # already correctly linked?
    if os.path.islink(local):
        old_target = os.readlink(local)
        if os.path.exists(old_target) and os.path.samefile(old_target, repo):
            _log(
                f"{s.tag_green('[Link exist]')} "
                f"{s.bright_link(local)} => {s.bright_link(old_target)}"
            )
            return
        _remove_path(local)
    elif os.path.exists(local):
        _remove_path(local)
    else:
        parent = Path(local).parent
        if not parent.exists():
            parent.mkdir(parents=True)

    # create symlink
    try:
        target_is_dir = os.path.isdir(repo)
        os.symlink(repo, local, target_is_directory=target_is_dir)
        # verify
        if os.path.exists(os.readlink(local)) and os.path.samefile(
            os.readlink(local), repo
        ):
            _log(
                f"{s.tag_success('[SUCCESS]')} "
                f"{s.bright_link(local)} => {s.bright_link(repo)} DONE!"
            )
        else:
            _warn(
                f"{s.tag_fail('[FAILED, BROKEN SYMBOLIC]')} "
                f"{s.link(local)} => {s.bg_yellow(os.readlink(local))}, "
                f"should be =>> {s.link(repo)}"
            )
    except OSError as e:
        _warn(
            f"{s.tag_red('[Exception]')}: Please check if you have {s.bold('sudo mode')}"
            f" to create symbollink.\n"
            f"\t {type(e).__name__} Occurrs when create link at {s.link(local)}\n"
            f"\tDetail:{e}"
        )
    except Exception as e:
        _warn(
            f"{s.tag_red('[Exception]')}: {type(e).__name__} while link "
            f"{s.link(local)} to {s.link(repo)}"
        )


# ── Main entry ───────────────────────────────────────────────

def link_configs(names: list[str] | None, dry_run: bool = False):
    """Link dotfiles. *names* is None → all configs."""
    key = os_key()
    with open(MAPPING_FILE, "r", encoding="utf-8") as f:
        all_entries = json.load(f).get(key, {})
    variables = load_variables()

    if names is None:
        names = list(all_entries.keys())

    for name in names:
        entry = all_entries.get(name)
        if entry is None:
            _warn(
                f"There is no item about {s.link(chr(34) + name + chr(34))} in "
                f"{s.yellow('mapping')}{s.bg_blue(s.bold(key))}{s.yellow('.json')}"
                f" file, please check it."
            )
            continue

        local_raw = entry.get("local", "")
        if not local_raw:
            repo_abs = expand_repo(entry["repo"])
            _warn(
                f"{s.tag_yellow('[REPO-HAS,LOCAL-UNMAPPED]')}: "
                f"{s.link(repo_abs)} don't have mapped path in your os"
            )
            continue

        repo = expand_repo(entry["repo"])
        local = expand_local(local_raw, variables)

        if dry_run:
            _log(f"{s.tag_yellow('[DRY-RUN]')} Would link {s.link(local)} => {s.link(repo)}")
        else:
            _make_link(repo, local)


def cmd_list():
    key = os_key()
    with open(MAPPING_FILE, "r", encoding="utf-8") as f:
        entries = json.load(f).get(key, {})
    max_len = max(len(n) for n in entries) if entries else 20
    for name, entry in entries.items():
        local = entry.get("local", "(unmapped)")
        print(f"  {s.bright_link(name):{max_len+10}}  →  {local}")


# ── CLI ──────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Dotfile manager — symlink dotfiles from this repo to your system"
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--all", "-a", action="store_true", help="Link all configs (default)")
    group.add_argument("--config", "-c", type=str, metavar="CFG",
                       help="Comma-separated config names to link")
    group.add_argument("--list", "-l", action="store_true", help="List available configs")
    parser.add_argument("--dry-run", "-n", action="store_true",
                        help="Preview only, don't make changes")

    args = parser.parse_args()

    if args.list:
        cmd_list()
        return

    names = None
    if args.config:
        names = [n.strip() for n in args.config.split(",") if n.strip()]

    link_configs(names, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
