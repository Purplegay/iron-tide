"""Independent audit failure cases; no installed SDK or game needed."""
import unittest
from pathlib import Path
from xml.etree import ElementTree as ET

from audit_sdk import audio_graph, media_presence, record, resolve_audio


def definitions(body):
    root = ET.fromstring('<AssetDeclaration xmlns="uri:ea.com:eala:asset">' + body + '</AssetDeclaration>')
    return {node.get("id"): node for node in root}


class AuditTests(unittest.TestCase):
    def test_nested_audio_excludes_comments_and_deduplicates(self):
        nodes = definitions('''<Multisound id="select"><Subsound>voice</Subsound><Subsound>voice</Subsound></Multisound>
            <AudioEvent id="voice"><Sound>present</Sound><!-- <Sound>not_shipped</Sound> --></AudioEvent>''')
        self.assertEqual(resolve_audio("select", nodes), {"clips": ["present"], "unresolved_events": []})

    def test_missing_event_is_not_success(self):
        nodes = definitions('<Multisound id="select"><Subsound>absent</Subsound></Multisound>')
        self.assertEqual(resolve_audio("select", nodes)["unresolved_events"], ["absent"])

    def test_cycle_is_explicit_failure(self):
        nodes = definitions('<Multisound id="a"><Subsound>b</Subsound></Multisound><Multisound id="b"><Subsound>a</Subsound></Multisound>')
        with self.assertRaisesRegex(ValueError, "a -> b -> a"):
            resolve_audio("a", nodes)

    def test_reference_and_cache_do_not_count_as_media(self):
        files = [Path("Art/AUMirag.xml"), Path("BuiltMods/AUMirag.asset"), Path("Audio/Other.wav")]
        self.assertFalse(media_presence(["AUMirag"], files, {".wav"})["AUMirag"]["present"])

    def test_media_matching_is_exact_case_insensitive(self):
        files = [Path("Audio/aumirag.WAV"), Path("Audio/AUMirag_extra.wav")]
        self.assertEqual(media_presence(["AUMirag"], files, {".wav"})["AUMirag"]["paths"], [str(files[0])])

    def test_audio_base_metadata_preserved(self):
        nodes = definitions('<AudioEvent id="base" Volume="100"/><AudioEvent id="voice" inheritFrom="AudioEvent:base" Control="LOOP"><Sound>clip</Sound><Delay Low="200" High="250"/></AudioEvent>')
        graph = audio_graph(["voice"], nodes)
        self.assertEqual(graph["base"]["attributes"]["Volume"], "100")
        self.assertEqual(graph["voice"]["children"][1]["attributes"], {"Low": "200", "High": "250"})

    def test_death_timelines_remain_independent(self):
        node = ET.fromstring('<Object><Lifetime Delay="5s" FadeTime="4s"/><LifetimeUpdate MinLifetime="4s" MaxLifetime="5s"/><SlowDeath SinkDelay="1s" DestructionDelay="8s"/></Object>')
        rows = record(node)["children"]
        self.assertEqual([r["type"] for r in rows], ["Lifetime", "LifetimeUpdate", "SlowDeath"])
        self.assertEqual(rows[2]["attributes"]["DestructionDelay"], "8s")


if __name__ == "__main__":
    unittest.main()
