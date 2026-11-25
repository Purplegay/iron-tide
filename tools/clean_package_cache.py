"""Reclaim a finished Windows friend-package staging area; dry run unless --apply."""
import argparse
import hashlib
import json
import stat
import zipfile
from pathlib import Path


def digest(stream):
    return hashlib.file_digest(stream, "sha256").hexdigest()


def file_hash(path):
    with path.open("rb") as stream:
        return digest(stream)


def safe(path, root):
    # Never follow any link or junction, including a linked ancestor.
    if not path.is_relative_to(root) or not path.resolve(strict=True).is_relative_to(root):
        raise ValueError(f"Outside staging area: {path}")
    for part in (path, *path.parents):
        if part.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise ValueError(f"Linked path: {part}")
        if part == root:
            return path
    raise ValueError(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    temp = (Path.home() / "Temp").resolve(strict=True)
    stage = args.stage.absolute()
    if stage.parent != temp or not stage.name.startswith("irontide-delivery-"):
        parser.error("Expected a completed irontide-delivery-* directory directly under the user Temp.")
    safe(stage, temp)
    manifest = json.loads(safe(stage / "delivery.json", temp).read_bytes())
    downloads = (Path.home() / "Downloads").resolve(strict=True)
    archives = {}
    for key in ("game", "assets"):
        record = manifest[key]
        archive = Path(record["path"])
        if archive.parent != downloads or archive.suffix != ".zip":
            raise ValueError(f"Unexpected delivery path: {archive}")
        safe(archive, downloads)
        if not archive.is_file() or archive.stat().st_size != record["bytes"] or file_hash(archive) != record["sha256"]:
            raise ValueError(f"Retained backup failed verification: {archive}")
        archives[key] = archive

    removed = size = private = 0
    def discard(path):
        nonlocal removed, size, private
        safe(path, stage)
        st = path.stat()
        if not stat.S_ISREG(st.st_mode):
            raise ValueError(path)
        if args.apply:
            path.unlink()
        removed += 1
        size += st.st_size
        if st.st_nlink == 1:
            private += st.st_size

    for key, archive in archives.items():
        duplicate = stage / archive.name
        if duplicate.exists() and file_hash(safe(duplicate, stage)) == manifest[key]["sha256"]:
            discard(duplicate)
        with zipfile.ZipFile(archive) as z:
            for member in z.infolist():
                parts = Path(member.filename).parts
                if member.is_dir() or not parts or any(p == ".." or ":" in p for p in parts):
                    continue
                if key == "game" and parts[0] == "IronTide":
                    candidates = [stage / sub / Path(*parts) for sub in ("package", "unpacked")]
                elif key == "assets" and parts[0] == "iron_tide":
                    candidates = [stage / "project" / Path(*parts[1:])]
                else:
                    continue
                candidates = [f for f in candidates if f.is_file() and safe(f, stage).stat().st_size == member.file_size]
                if candidates:
                    with z.open(member) as stream:
                        expected = digest(stream)
                    for f in candidates:
                        if file_hash(f) == expected:
                            discard(f)
    # Disposable importer products of this verified export, never the development cache.
    imported = stage / "project/.godot/imported"
    if imported.exists():
        for f in safe(imported, stage).iterdir():
            if f.is_file() and f.suffix in (".ctex", ".sample", ".md5", ".mp3str", ".s3tc", ".res"):
                discard(f)
    print(json.dumps(dict(apply=args.apply, files=removed, logical_bytes=size, single_link_bytes=private)))


if __name__ == "__main__":
    main()
