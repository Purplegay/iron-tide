# RA3 Mirage SDK closeout

Current source boundary: official SDK XML/XSD defines the reference behavior;
the user explicitly selected installed RA3 Uprising for missing native media.
Do not run historical demo extraction commands for new work. Previously shipped
resources retain their original provenance; extraction is not runtime integration.

```
python tools/ra3_mirage/audit_sdk.py --sdk refs/ra3-sdk/installed --output refs/ra3-mirage/integration-test/sdk-closeout/sdk-audit.json
python -m unittest discover -s tools/ra3_mirage -p test_audit_sdk.py -v
```

The audit does not extract archives or access the network. It captures source
hashes, audio bindings and nested events, animation conditions, independent wreck
modules, weapon/scatter rules and disguise terrain mappings. It regenerates the
SDK-only visual data for semantic comparison and verifies existing runtime FX/UI
hashes and literal resource references. Runtime observations still require the
Godot regression scenes and player visual acceptance; this is not an all-engine
asset dependency resolver or a substitute for game testing.

Exit 0 means the audit ran successfully, not that native media is complete.
Read `status`; `native_media_incomplete` is expected for this SDK. With
`--require-native-media`, that status exits 2. Runtime validation errors exit 1.
The JSON is an audit report, not a new runtime voice/animation configuration.

The SDK-only audit still lacks loose media. Community voice, bone playback and
COL debris were integrated earlier; Uprising extraction below supplements the
remaining gaps. See `docs/RA3_MIRAGE_MODEL.md` for current runtime boundaries.

## Installed Uprising extraction (2026-10-27)

Run from the IronTide root. Requires Python 3 + Pillow, the installed Uprising
1.1 game, and the official vgmstream CLI. Local originals and decoder stay under
ignored `refs/`; no game installation files or runtime assets are changed.

```powershell
python -B tools/ra3_mirage/extract_uprising.py --game "C:/Program Files (x86)/Steam/steamapps/common/Command and Conquer Red Alert 3 Uprising" --output refs/ra3-mirage/uprising
python -B tools/ra3_mirage/convert_uprising_media.py --source refs/ra3-mirage/uprising --audio-decoder refs/ra3-mirage/vgmstream/vgmstream-cli.exe
python -B tools/ra3_mirage/verify_uprising_media.py
```

The extractor reads BIG/RefPack and manifest v7, follows the selected presentation
and audio references, and preserves bin/relo/imp/cdata plus compiled shader files.
It never expands the full game into copies. The converter writes native DDS/PNG,
cropped icons, WAV, mesh/material/bone JSON, animation channels and audio mappings.
Delta channels are preserved, not guessed into curves; Timecoded keys are decoded.
Meshes retain source coordinates and bone-local attributes, not baked Godot poses.
FXO is compiled D3D shader bytecode, not portable shader source.

The verification entry targets this scoped extraction and the locally installed
SDK. It also expects `refs/ra3-mirage/vgmstream/release-asset.json` from the official
[vgmstream GitHub release](https://github.com/vgmstream/vgmstream/releases/tag/r2168)
and `package.zip`; it verifies the archive against that release asset digest.
`verification.json` records source hashes and limitations. Output thumbnails are
in `converted/icon-contact-sheet.png`; all converted file hashes are in
`converted/conversion.json`. Do not present these checks as game visual acceptance.

## Historical model conversion (not the current Uprising workflow)

Requires Python 3 + Pillow and original extracted RA3 demo blocks, listed in `iron_tide/assets/ra3/mirage/provenance.json`. The input is not an invented model or reconstructed MAX source.

```
python tools/ra3_mirage/convert_model.py --source refs/ra3-mirage/original --output refs/ra3-mirage/rebuilt
```

This validates original bounds, reconstructs the weighted bind pose, keeps all chassis and track triangles in one vehicle transform, and decodes the original six diffuse/normal/SPM textures. Geometry retains 4889 original vertices and 3552 triangles across two material meshes. rig.json resolves the SDK FX_Weapon name hash to SKL pivot 6 and composes its ancestor translations. The former 2..11 bone range was not a turret and must never be rotated independently.

Runtime uses `Ra3UnitModel` and the converted geometry/textures. No discrete facing frames are used by the normal graphical renderer. Camera projection, muzzle and hit testing use the same model canvas. Materials are a Godot adaptation of the original texture channels; This paragraph describes the historical static conversion; native IDLA/MOVA
playback was subsequently added via the community importer. SAGE shader parity
remains pending; consult the current handoff document.

For the headless fallback only, run Godot with graphical rendering against a temporary empty project:

```
godot --path <temporary-project> --script <absolute-path>/render_fallback.gd -- <converted-source-directory> <output-directory>
```

The fallback produces one whole-vehicle atlas and `unitweapon_R3MIRAGE.json`; the existing atlas metadata declares 32 facings, 96px frames, 2px padding, ground anchor (48,60). Runtime resources are included in the project; the original demo download, SDK and extraction workspace remain ignored.
