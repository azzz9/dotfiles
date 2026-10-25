#!/usr/bin/env python3
"""Moves the npm tarballs modules/pi.nix pins to their registry latest.

A row pins the published tarball of a pi extension, and the runtime
dependencies vendored under node_modules are rows too. A vendored dependency
follows the version its parent's package.json names when that is an exact
version, and its own latest when the parent only names a range. Every hash is
measured with `nix store prefetch-file`, so a row is never half-moved.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

REGISTRY = "https://registry.npmjs.org"
NAME = re.compile(r'name = "([^"]+)";')
FIELD = {
    "version": re.compile(r'version = "([^"]+)";'),
    "url": re.compile(r'url = "([^"]+)";'),
    "hash": re.compile(r'hash = "([^"]+)";'),
}
EXACT = re.compile(r"\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?")


class Entry:
    def __init__(self, name: str, fields: dict[str, str], spans: dict[str, tuple[int, int]]):
        self.name = name
        self.version = fields["version"]
        self.url = fields["url"]
        self.hash = fields["hash"]
        self.spans = spans


def parse(text: str) -> dict[str, Entry]:
    names = list(NAME.finditer(text))
    if not names:
        raise SystemExit("bump-pins: no npm tarball row found in the pi module")
    entries = {}
    for index, match in enumerate(names):
        end = names[index + 1].start() if index + 1 < len(names) else len(text)
        block = text[match.end():end]
        fields = {}
        spans = {}
        for key, pattern in FIELD.items():
            found = pattern.search(block)
            if found is None:
                raise SystemExit(
                    f'bump-pins: no {key} after name = "{match.group(1)}" in the pi rows'
                )
            fields[key] = found.group(1)
            spans[key] = (match.end() + found.start(1), match.end() + found.end(1))
        entries[match.group(1)] = Entry(match.group(1), fields, spans)
    return entries


def version_key(version: str):
    core, _, prerelease = version.split("+", 1)[0].partition("-")
    numbers = tuple(int(part) for part in re.findall(r"\d+", core))
    identifiers = []
    if prerelease:
        for part in prerelease.split("."):
            if part.isdigit():
                identifiers.append((0, int(part), ""))
            else:
                identifiers.append((1, 0, part))
    return (numbers, 0 if prerelease else 1, identifiers)


def _numbers(text: str) -> tuple[int, ...]:
    return tuple(int(n) for n in re.findall(r"\d+", text.split("+")[0].partition("-")[0]))


def _floor(numbers: tuple[int, ...]):
    return version_key(".".join(str(n) for n in numbers) + ".0" * max(0, 3 - len(numbers)))


def _ceiling(numbers: tuple[int, ...], operator: str):
    if operator == "~" and len(numbers) > 1:
        return version_key(f"{numbers[0]}.{numbers[1] + 1}.0")
    if operator == "^" and numbers[0] == 0 and len(numbers) > 1:
        if numbers[1]:
            return version_key(f"0.{numbers[1] + 1}.0")
        return version_key(f"0.0.{numbers[2] + 1}") if len(numbers) > 2 else version_key("0.1.0")
    return version_key(f"{numbers[0] + 1}.0.0")


def _comparator(version: str, part: str) -> bool:
    operator = ""
    for prefix in (">=", "<=", ">", "<", "^", "~"):
        if part.startswith(prefix):
            operator, part = prefix, part[len(prefix):]
            break
    if part in ("", "*", "x", "X", "latest"):
        return True
    numbers = _numbers(part)
    if not numbers:
        return True
    current = version_key(version)
    floor = _floor(numbers)
    if operator in ("^", "~"):
        return floor <= current < _ceiling(numbers, operator)
    if operator == ">=":
        return floor <= current
    if operator == ">":
        return floor < current
    if operator == "<=":
        return current <= floor
    if operator == "<":
        return current < floor
    if len(numbers) < 3:
        return floor <= current < _ceiling(numbers, "^")
    return current == floor


def satisfies(version: str, spec: str) -> bool:
    for alternative in spec.split("||"):
        parts = [part for part in alternative.split() if part]
        if parts and all(_comparator(version, part) for part in parts):
            return True
    return False


def fetch_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": "dotfiles-bump-pins"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


class Registry:
    def __init__(self):
        self.documents = {}

    def document(self, name: str):
        if name not in self.documents:
            encoded = urllib.parse.quote(name, safe="@")
            self.documents[name] = fetch_json(f"{REGISTRY}/{encoded}")
        return self.documents[name]

    def latest(self, name: str) -> str:
        return self.document(name)["dist-tags"]["latest"]

    def versions(self, name: str) -> list[str]:
        return list(self.document(name)["versions"])

    def release(self, name: str, version: str):
        versions = self.document(name)["versions"]
        if version in versions:
            return versions[version]
        encoded = urllib.parse.quote(name, safe="@")
        return fetch_json(f"{REGISTRY}/{encoded}/{urllib.parse.quote(version, safe='')}")


def dependencies(meta) -> dict[str, str]:
    declared = dict(meta.get("dependencies") or {})
    declared.update(meta.get("optionalDependencies") or {})
    return declared


def parents(entries: dict[str, Entry], effective: dict[str, str], registry: Registry) -> dict[str, set[str]]:
    found: dict[str, set[str]] = {}
    for name in entries:
        for dependency in dependencies(registry.release(name, effective[name])):
            if dependency in entries:
                found.setdefault(dependency, set()).add(name)
    return found


def effective_versions(entries: dict[str, Entry], registry: Registry) -> dict[str, str]:
    effective = {}
    for name, entry in entries.items():
        latest = registry.latest(name)
        effective[name] = latest if version_key(latest) > version_key(entry.version) else entry.version
    return effective


class PlanError(Exception):
    pass


def resolve(name: str, specs: list[str], entries: dict[str, Entry], registry: Registry) -> str:
    exact = sorted({spec for spec in specs if EXACT.fullmatch(spec)})
    if len(exact) > 1:
        raise PlanError(f"{name} is pinned to {', '.join(exact)} by different parents")
    if exact:
        for spec in specs:
            if not satisfies(exact[0], spec):
                raise PlanError(f"{name} {exact[0]} does not satisfy {spec}")
        return exact[0]
    published = [
        version
        for version in registry.versions(name)
        if all(satisfies(version, spec) for spec in specs)
    ]
    if published:
        return max(published, key=version_key)
    if all(satisfies(entries[name].version, spec) for spec in specs):
        return entries[name].version
    raise PlanError(
        f"{name} has no version satisfying {', '.join(sorted(set(specs)))}"
    )


def plan(entries: dict[str, Entry], registry: Registry):
    """Every row that moves, as name -> (old version, new version, tarball)."""
    effective = effective_versions(entries, registry)
    owned = parents(entries, effective, registry)
    roots = [name for name in entries if not owned.get(name)]
    chosen = dict(effective)
    for _ in range(len(entries) + 1):
        wanted: dict[str, list[str]] = {}
        updates = {}
        seen = set()
        queue = [(name, chosen[name]) for name in roots]
        while queue:
            name, version = queue.pop(0)
            if (name, version) in seen or name not in entries:
                continue
            seen.add((name, version))
            meta = registry.release(name, version)
            if version != entries[name].version:
                updates[name] = (entries[name].version, version, meta["dist"]["tarball"])
            for dependency, spec in dependencies(meta).items():
                if dependency not in entries:
                    continue
                wanted.setdefault(dependency, []).append(spec)
                queue.append((dependency, chosen[dependency]))
        resolved = {
            name: resolve(name, specs, entries, registry) for name, specs in wanted.items()
        }
        if all(chosen[name] == version for name, version in resolved.items()):
            return updates
        chosen.update(resolved)
    raise PlanError("the dependency requirements do not settle")


def prefetch(url: str) -> str:
    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)["hash"]


def render(text: str, entries: dict[str, Entry], updates) -> str:
    edits = []
    for name, (_, version, url, hash_value) in updates.items():
        for key, value in (("version", version), ("url", url), ("hash", hash_value)):
            start, end = entries[name].spans[key]
            edits.append((start, end, value))
    for start, end, value in sorted(edits, reverse=True):
        text = text[:start] + value + text[end:]
    return text


def write_atomically(path: str, text: str) -> None:
    directory = os.path.dirname(os.path.abspath(path))
    with tempfile.NamedTemporaryFile("w", dir=directory, delete=False) as handle:
        handle.write(text)
        temporary = handle.name
    os.replace(temporary, path)


FIXTURE = """  rows = [
    { tarball = {
        name = "parent";
        version = "1.0.0";
        url = "https://registry.npmjs.org/parent/-/parent-1.0.0.tgz";
        hash = "sha256-parent";
        deps = [{
          name = "child";
          version = "1.0.0";
          url = "https://registry.npmjs.org/child/-/child-1.0.0.tgz";
          hash = "sha256-child";
        }];
      };
    }
  ];
"""

TWO_PARENTS = """  rows = [
    { tarball = {
        name = "parent-a";
        version = "1.0.0";
        url = "https://registry.npmjs.org/parent-a/-/parent-a-1.0.0.tgz";
        hash = "sha256-pa";
      };
    }
    { tarball = {
        name = "parent-b";
        version = "1.0.0";
        url = "https://registry.npmjs.org/parent-b/-/parent-b-1.0.0.tgz";
        hash = "sha256-pb";
      };
    }
    { tarball = {
        name = "child";
        version = "1.0.0";
        url = "https://registry.npmjs.org/child/-/child-1.0.0.tgz";
        hash = "sha256-child";
      };
    }
  ];
"""


def selftest() -> int:
    entries = parse(FIXTURE)
    assert set(entries) == {"parent", "child"}, entries
    assert entries["parent"].version == "1.0.0"
    assert entries["child"].hash == "sha256-child"
    assert version_key("1.3.1-pre.1") < version_key("1.3.1")
    assert version_key("1.3.1-pre.1") < version_key("1.3.1-pre.2")
    assert version_key("1.0.0-rc.2") < version_key("1.0.0-rc.10")
    assert version_key("1.0.0+build") == version_key("1.0.0")
    assert version_key("2.13.10") > version_key("2.12.0")

    class Fake:
        def __init__(self, latest, releases):
            self._latest, self._releases = latest, releases
        def latest(self, name):
            return self._latest[name]
        def release(self, name, version):
            return self._releases[(name, version)]
        def versions(self, name):
            return [version for (package, version) in self._releases if package == name]

    def meta(deps=None):
        return {"dist": {"tarball": "https://example.invalid/row.tgz"}, "dependencies": deps or {}}

    exact = plan(entries, Fake(
        {"parent": "1.1.0", "child": "1.2.0"},
        {("parent", "1.0.0"): meta({"child": "1.0.0"}), ("child", "1.0.0"): meta(),
         ("parent", "1.1.0"): meta({"child": "1.1.0"}), ("child", "1.1.0"): meta(),
         ("child", "1.2.0"): meta()}))
    assert exact["child"][1] == "1.1.0", exact

    ranged = plan(entries, Fake(
        {"parent": "1.1.0", "child": "1.2.0"},
        {("parent", "1.0.0"): meta({"child": "1.0.0"}), ("child", "1.0.0"): meta(),
         ("parent", "1.1.0"): meta({"child": "^1.0.0"}), ("child", "1.2.0"): meta()}))
    assert ranged["child"][1] == "1.2.0", ranged

    current_parent = plan(entries, Fake(
        {"parent": "1.0.0", "child": "1.2.0"},
        {("parent", "1.0.0"): meta({"child": "^1.0.0"}), ("child", "1.0.0"): meta(),
         ("child", "1.2.0"): meta()}))
    assert set(current_parent) == {"child"}, current_parent
    assert current_parent["child"][1] == "1.2.0", current_parent
    assert EXACT.fullmatch("0.11.0") and not EXACT.fullmatch("^1.0.0")
    updates = {
        "parent": ("1.0.0", "1.1.0", "https://example.invalid/parent-1.1.0.tgz", "sha256-new"),
        "child": ("1.0.0", "1.0.1", "https://example.invalid/child-1.0.1.tgz", "sha256-child-new"),
    }
    rendered = render(FIXTURE, entries, updates)
    assert 'version = "1.1.0";' in rendered, rendered
    assert 'hash = "sha256-child-new";' in rendered, rendered
    assert "sha256-parent" not in rendered, rendered
    assert rendered.count("name = ") == 2, rendered
    both = parse(TWO_PARENTS)
    exact_wins = plan(both, Fake(
        {"parent-a": "1.0.0", "parent-b": "1.0.0", "child": "1.2.0"},
        {("parent-a", "1.0.0"): meta({"child": "1.1.0"}),
         ("parent-b", "1.0.0"): meta({"child": "^1.0.0"}),
         ("child", "1.0.0"): meta(), ("child", "1.1.0"): meta(),
         ("child", "1.2.0"): meta()}))
    assert exact_wins["child"][1] == "1.1.0", exact_wins

    major_bound = plan(entries, Fake(
        {"parent": "1.0.0", "child": "2.0.0"},
        {("parent", "1.0.0"): meta({"child": "^1.0.0"}), ("child", "1.0.0"): meta(),
         ("child", "2.0.0"): meta()}))
    assert "child" not in major_bound, major_bound

    assert satisfies("1.5.0", "^1.0.0")
    assert not satisfies("2.0.0", "^1.0.0")
    assert satisfies("0.1.9", "^0.1.0")
    assert not satisfies("0.2.0", "^0.1.0")
    assert satisfies("1.0.9", "~1.0.0")
    assert not satisfies("1.1.0", "~1.0.0")
    assert satisfies("3.0.0", "*")
    assert satisfies("1.4.0", ">=1.0.0 <2.0.0")
    assert not satisfies("2.1.0", ">=1.0.0 <2.0.0")

    print("bump-pi-tarballs: selftest passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", default="modules/pi.nix")
    parser.add_argument("--check", action="store_true", help="report the moves and write nothing")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        return selftest()

    with open(args.file, encoding="utf-8") as handle:
        text = handle.read()
    entries = parse(text)
    registry = Registry()
    updates = plan(entries, registry)
    if not updates:
        print("bump-pins: the pi tarballs are at the registry's latest")
        return 0

    resolved = {}
    for name in sorted(updates):
        old, version, url = updates[name]
        hash_value = entries[name].hash if args.check else prefetch(url)
        resolved[name] = (old, version, url, hash_value)
        print(f"bump-pins: bumped {name} {old} -> {version}")
    if not args.check:
        write_atomically(args.file, render(text, entries, resolved))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (
        urllib.error.URLError,
        KeyError,
        ValueError,
        OSError,
        subprocess.CalledProcessError,
        PlanError,
    ) as error:
        print(f"bump-pins: the pi tarball bump stopped: {error}", file=sys.stderr)
        sys.exit(1)
