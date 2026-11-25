"""Import retail English Yuriko unit responses, weapon events and their attack/body/decay banks."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import wave

ROOT = Path(__file__).resolve().parents[2] / "iron_tide"
DEST = ROOT / "assets/ra3/yuriko/audio"
VOICE = {
    "created":"VoiceCreate", "select":"VoiceSelectMS", "select_battle":"VoiceSelectBattleMS",
    "select_under_fire":"VoiceSelectUnderFireMS", "move":"VoiceMove", "move_attack":"VoiceMoveAttack",
    "attack":"VoiceAttack", "enter":"VoiceGarrison", "die":"VoiceDie", "crush":"VoiceDie",
    "die_fire":"VoiceDieFire", "die_shock":"VoiceDieShock", "burst_yell":"VoicePsyonicBlastMS",
}
POWERS = ["JAP_Yuriko_PsychicDominationMS","JAP_Yuriko_PsychokineticBurstMS","JAP_YurikoOmega_PsychoKineticBurst",
          "JAP_Yuriko_PsychicShieldRepel_Impact","JAP_Yuriko_PsychicShieldLoop","JAP_Yuriko_PsychicSlamLoop",
          "JAP_Yuriko_PsychicSlamLiftStart","JAP_Yuriko_PsychicSlamImpactCursor","JAP_YurikoOmega_PsyonicLoop",
          "JAP_YurikoOmega_PsyonicVehicleLiftStart","JAP_YurikoOmega_PsyonicEndExplodeMS","JAP_YurikoOmega_PsyonicInfantryBurst"]


def main(folder):
    manifest=json.loads((folder/"extraction.json").read_text(encoding="utf-8"))
    by_id={(r["type"],r["instance"]):r["name"] for r in manifest["assets"]}
    rows={r["name"].split(":",1)[1]:r for r in manifest["assets"]}
    voice={key:"JAP_Yuriko_"+value for key,value in VOICE.items()}
    for chapter in [1,2]:
        for event in ["HurtInitial","HurtLarge"]:
            voice[f"hurt_{chapter}_{event}"]=f"JAP_Yuriko{chapter}EP1_Voice{event}"
    voice["healed"]="JAP_Yuriko1EP1_VoiceHealed"
    DEST.mkdir(parents=True,exist_ok=True)
    specs,entries={},{}
    records={r["file"]:r["sha256"] for r in json.loads((folder/"converted/conversion.json").read_text(encoding="utf-8"))["records"]}

    def install(name):
        if name in entries:return
        src=folder/"converted/audio"/("AudioFile_"+name+".wav")
        assert hashlib.sha256(src.read_bytes()).hexdigest()==records[src.relative_to(folder).as_posix()]
        dst=DEST/(name+".wav")
        shutil.copyfile(src,dst)
        with wave.open(str(dst)) as audio:
            assert audio.getsampwidth()==2 and audio.getnframes()>0
            entries[name]=dict(file="res://"+dst.relative_to(ROOT).as_posix(),sampleRate=audio.getframerate(),
                channels=audio.getnchannels(),durMs=round(audio.getnframes()*1000/audio.getframerate()))

    def export(name):
        if name in specs:return
        row=rows[name]
        refs=[by_id[tuple(ref)].split(":",1)[1] for ref in row["references"]]
        if row["name"].startswith("Multisound:"):
            for ref in refs:export(ref)
            specs[name]={**specs[refs[0]],"layers":refs[1:]}
            return
        raw=(folder/"raw"/("AudioEvent_"+name+".bin")).read_bytes()
        volume=round(struct.unpack_from("<f",raw,4)[0]*100,2)
        radius=struct.unpack_from("<f",raw,52)[0]*1.5/55
        for offset,suffix in [(128,"_attack"),(136,""),(144,"_decay")]:
            count,ptr=struct.unpack_from("<II",raw,offset)
            if not count:continue
            clips=[refs[struct.unpack_from("<I",raw,ptr+12*i)[0]-1] for i in range(count)]
            for clip in clips:install(clip)
            specs[name+suffix]=dict(sounds=clips,volume=volume,range=round(radius,3))
        assert name in specs,name

    for name in [*voice.values(),*POWERS]:export(name)
    pack=dict(sounds=dict(specs=specs,entries=entries),voice=voice)
    (ROOT/"data/ra3_yuriko_sounds.json").write_text(json.dumps(pack,indent=2)+"\n",encoding="utf-8")
    print(len(specs),"events/phases",len(entries),"distinct WAVs",sum(f.stat().st_size for f in DEST.glob("*.wav")),"bytes")


if __name__=="__main__":
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("converted_extraction",type=Path)
    main(ap.parse_args().converted_extraction)
