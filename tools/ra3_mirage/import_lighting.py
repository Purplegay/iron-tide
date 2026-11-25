"""Preserve official default afternoon lighting and source fingerprints."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
NS = {'s': 'uri:ea.com:eala:asset'}


def main():
    sources = {}

    def read(relative):
        path = ROOT / relative
        sources[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        return ET.parse(path).getroot()

    sdk = read('refs/ra3-sdk/installed/SAGEXML/System/LightingSettings.xml')
    uprising = read('refs/ea-modding-support/Uprising/Xml/System/LightingSettings.xml')
    schema = read('refs/ra3-sdk/installed/Schemas/xsd/System/LightingSettings.xsd')
    def rows(root):
        current = root.find('s:LightingSettings/s:CurrentLightingSettings', NS)
        return [{name: [float(light.find('s:' + name, NS).get(c)) for c in axes]
                 for name, axes in [('Ambient', 'RGB'), ('Diffuse', 'RGB'), ('LightPos', 'xyz')]}
                for light in current.findall('s:Lighting', NS)]
    lights = rows(uprising)
    assert rows(sdk) == lights and len(lights) == 3
    occluded = next(float(e.get('default')) for e in schema.iter() if e.get('name') == 'OccludedLuminanceScale')
    shadow = 'refs/ea-modding-support/Uprising/Shaders/Shadow.fx'
    sources[shadow] = hashlib.sha256((ROOT / shadow).read_bytes()).hexdigest()
    data = {'time_of_day': 'AFTERNOON', 'lights': lights, 'occluded_luminance_scale': occluded,
            'sources': sources, 'boundary': 'Default map lighting only. Godot material response, planar mesh shadows, blur and flight-height opacity are adaptations, not SAGE shadow-map parity.'}
    (ROOT / 'iron_tide/assets/ra3/lighting.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    print('Imported matching SDK/Uprising afternoon lights:', len(lights))


if __name__ == '__main__':
    main()
