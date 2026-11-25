# Damage profiles and compiled field effect audit

```powershell
python -B tools/ra3_mirage/extract_target_profiles.py --sdk refs/ra3-sdk/installed --output iron_tide/data/ra3_mirage_targets.json
python -B tools/ra3_mirage/audit_field_effect.py --game "C:/Program Files (x86)/Steam/steamapps/common/Command and Conquer Red Alert 3 Uprising" --dll refs/ra3-mirage/code-audit/native-effect/d3dx9_43.dll --material iron_tide/assets/ra3/mirage/uprising/field.json --output refs/ra3-mirage/code-audit/native-effect/final.json
```

The effect audit is Windows-only; supply Microsoft's local x64 D3DX9 DLL (for
example from the installed Steam DirectX redistributable). It creates an invisible
D3D9 device and reads the actual FXO pass states and preshader constants. No
desktop drawing, DLL installation, or game execution occurs. This does not recover
the RA3 engine's CPU geometry generation or establish final visual parity.
