"""Freeze an explicit project, export and smoke-test a Windows portable zip."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['source', 'stage', 'output', 'godot', 'template', 'licenses', 'save']:
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--validation-report', type=Path, help='Include the measured performance report in the portable package')
    parser.add_argument('--release-notes', type=Path, help='Append task-specific release notes to the portable readme')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('Windows export runner requires CREATE_NO_WINDOW.')
    source, root = args.source.resolve(), args.stage.resolve()
    root.mkdir(parents=True, exist_ok=False)
    project = root / 'project'
    package = root / 'package/IronTide'
    package.mkdir(parents=True)
    project.mkdir()
    repository = Path(__file__).resolve().parents[1]
    asset_paths = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '-z', '--', 'iron_tide/assets'], cwd=repository).decode('utf8').split('\0')
    paths = [Path(p).relative_to('iron_tide') for p in asset_paths if p]
    for folder in ['scripts', 'data', 'scenes', 'shaders']:
        paths.extend(p.relative_to(source) for p in (source / folder).rglob('*') if p.is_file())
    paths.extend(Path(p) for p in ['project.godot', 'icon.svg', 'icon.svg.import', 'icon.ico'])
    hashes = {}
    for relative in sorted(set(paths)):
        target = project / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / relative, target)
        hashes[relative.as_posix()] = digest(target)
    assert all(digest(source / p) == h for p, h in hashes.items()), 'Source changed during snapshot'
    (root / 'source-sha256.json').write_text(json.dumps(hashes, indent=2), 'utf8')
    config = (project / 'project.godot').read_text('utf8')
    version = re.search(r'^config/version="([^"]+)"', config, re.M)[1]
    # Validation projects may already have an isolated profile override.
    config = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', config, flags=re.M)
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="IronTideFriends"')
    (project / 'project.godot').write_text(config, 'utf8')
    preset = f'''[preset.0]
name="Windows Friends"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.csv,*.txt"
exclude_filter="tests/*,*.md"
script_export_mode=2
[preset.0.options]
custom_template/release="{args.template.resolve().as_posix()}"
debug/export_console_wrapper=0
binary_format/architecture="x86_64"
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
codesign/enable=false
application/modify_resources=true
application/icon="res://icon.ico"
'''
    (project / 'export_presets.cfg').write_text(preset, 'utf8')
    env = dict(os.environ, APPDATA=str(root / 'profile'), LOCALAPPDATA=str(root / 'profile'),
               IRON_OUT=str(root), IRON_SAVE=str(args.save.resolve()), IRON_PACKAGE_VERSION=version)
    env.pop('IRON_TIDE_CALL_LOG', None)

    def run(executable, arguments, cwd, name, timeout):
        log = root / (name + '.log')
        with log.open('wb') as stream:
            result = subprocess.run([str(executable), '--headless', *map(str, arguments)], cwd=cwd, env=env,
                                    stdout=stream, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW, timeout=timeout)
        text = log.read_text('utf8', errors='replace')
        errors = [line for line in text.splitlines() if line.startswith(('SCRIPT ERROR:', 'ERROR:', 'FAIL '))]
        print(name, 'exit', result.returncode, 'errors', len(errors), flush=True)
        if result.returncode or errors:
            raise RuntimeError(name + ': ' + str(errors[:4]))
        return text

    print('SNAPSHOT', version, len(hashes), flush=True)
    try:
        run(args.godot, ['--path', project, '--import'], project, 'import', 1800)
    except RuntimeError:
        if not (project / '.godot/imported').exists():
            raise
        run(args.godot, ['--path', project, '--import'], project, 'import-verified', 1800)
    run(args.godot, ['--path', project, '--export-release', 'Windows Friends', package / 'IronTide.exe'], project, 'export', 1200)
    assert (package / 'IronTide.pck').stat().st_size > 100_000_000
    for name in ['Godot-LICENSE.txt', 'Godot-THIRD-PARTY.txt']:
        shutil.copy2(args.licenses / name, package / name)
    if args.validation_report:
        shutil.copy2(args.validation_report, package / 'performance-validation.json')
    (package / '开始试玩.txt').write_text(f'''Iron Tide v{version} · Windows x64

完整解压后双击 IronTide.exe；IronTide.pck 须与 EXE 同目录，无需安装 Godot。
存档与设置：%APPDATA%\\IronTideFriends

''', 'utf-8-sig')
    if args.validation_report:
        with (package / '开始试玩.txt').open('a', encoding='utf8') as stream:
            stream.write('本次性能测量报告见 performance-validation.json。\n')
    if args.release_notes:
        with (package / '开始试玩.txt').open('a', encoding='utf8') as stream:
            stream.write('\n'+args.release_notes.read_text('utf8')+'\n')
    run(package / 'IronTide.exe', ['--quit-after', '120'], package, 'menu', 180)
    smoke_source = Path(__file__).with_name('package_smoke.gd').read_text('utf8')
    probe = root / 'probe.tscn'
    probe.write_text('[gd_scene load_steps=2 format=3]\n[sub_resource type="GDScript" id="1"]\nscript/source = ' + json.dumps(smoke_source, ensure_ascii=False) + '\n[node name="PackageSmoke" type="Node"]\nscript=SubResource("1")\n', 'utf8')
    override = package / 'override.cfg'
    override.write_text('[application]\nrun/main_scene="' + probe.as_posix() + '"\n', 'utf8')
    try:
        env['IRON_TIDE_CALL_LOG'] = '1'
        run(package / 'IronTide.exe', ['--fixed-fps', '60'], package, 'battle', 360)
        smoke = json.loads((root / 'smoke.json').read_text('utf8'))
        assert smoke['failed'] == 0
    finally:
        override.unlink(missing_ok=True)
    assert all(digest(source / p) == h for p, h in hashes.items()), 'Source drift before archive'
    manifest = {'version': version, 'platform': 'Windows x64', 'source': str(source),
                'source_files': len(hashes), 'source_manifest_sha256': digest(root / 'source-sha256.json'),
                'checkpoint_sha256': digest(args.save), 'includes_uncommitted_worktree': True,
                'verification': smoke, 'files': {p.name: digest(p) for p in package.iterdir()}}
    (package / 'build-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), 'utf8')
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    assert not output.exists()
    partial = output.with_suffix('.zip.partial')
    with zipfile.ZipFile(partial, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=4) as archive:
        for path in sorted(package.iterdir()):
            archive.write(path, 'IronTide/' + path.name)
    with zipfile.ZipFile(partial) as archive:
        assert archive.testzip() is None
        for path in package.iterdir():
            with archive.open('IronTide/' + path.name) as stream:
                assert hashlib.file_digest(stream, 'sha256').hexdigest() == digest(path)
    partial.rename(output)
    delivery = {'path': str(output), 'bytes': output.stat().st_size, 'sha256': digest(output), 'manifest': manifest}
    (root / 'delivery.json').write_text(json.dumps(delivery, ensure_ascii=False, indent=2), 'utf8')
    print('DELIVERED', output, delivery['bytes'], delivery['sha256'], flush=True)


if __name__ == '__main__':
    main()
