"""Map original Mirage WAVs to SDK AudioEvents; no demo input."""
from pathlib import Path
from xml.etree import ElementTree as ET
import json, shutil, wave, hashlib
NS={'s':'uri:ea.com:eala:asset'}
def integrate(repo, audio, sdk):
 destination=repo/'iron_tide/assets/ra3/mirage/native/audio'; destination.mkdir(parents=True,exist_ok=True)
 lookup={p.stem.lower():p for p in audio.glob('*.wav')}
 events=ET.parse(sdk/'SAGEXML/Sounds/Voice.xml').getroot()
 mapping={'select':'Select','move':'Move','attack':'Attack','created':'Create','move_attack':'MoveAttack','move_special':'MoveSpecial','select_mirage':'SelectMirage','select_battle':'SelectBattle','select_under_fire':'SelectUnderFire','retreat':'Retreat'}
 specs={}; entries={}; voices={}; sources={}
 def add(name,sounds,volume=100):
  ids=[]
  for sound in sounds:
   p=lookup[sound.lower()]; key='ra3_'+p.stem.lower(); ids.append(key)
   shutil.copyfile(p,destination/p.name)
   with wave.open(str(p),'rb') as w:
    assert w.getcomptype()=='NONE' and w.getnframes()>0
    entries[key]={'file':'res://assets/ra3/mirage/native/audio/'+p.name,'sampleRate':w.getframerate(),'channels':w.getnchannels(),'durMs':round(w.getnframes()/w.getframerate()*1000)}
   sources[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
  specs[name]={'sounds':ids,'volume':volume,'range':20,'loop':False,'priority':10}
 for kind,suffix in mapping.items():
  event=events.find('.//s:AudioEvent[@id="ALL_MirageTank_Voice'+suffix+'"]',NS); assert event is not None
  name='RA3_Mirage_'+kind; voices[kind]=name
  add(name,[n.text.strip() for n in event.findall('s:Sound',NS)],float(event.get('Volume')))
 add('RA3_MirageFire',['AUMirag_wea1FireA','AUMirag_wea1FireB','AUMirag_wea1FireC'])
 data_path=repo/'iron_tide/data/ra3_mirage.json'; data=json.loads(data_path.read_text(encoding='utf-8'))
 data['units'][0]['voice'].update(voices); data['sounds']={'specs':specs,'entries':entries}
 data_path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 manifest={'source_url':'https://sounds.spriters-resource.com/pc_computer/commandconquerredalert3uprising/asset/440577/','credit':'EA assets, Allied Vehicles pack uploaded by CoffeeMaus','sdk_voice_sha256':hashlib.sha256((sdk/'SAGEXML/Sounds/Voice.xml').read_bytes()).hexdigest(),'clips':sources,'events':list(specs),'not_integrated':['Shared weapon layer 1 and shared field start/loop/stop samples are not in the Mirage folder','Retreat event imported; IronTide has no retreat-to-castle command','SDK-commented selection machinery and Create c remain disabled']}
 (destination.parent/'audio_provenance.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 return len(entries)
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser(); p.add_argument('--repo',type=Path,required=True); p.add_argument('--audio',type=Path,required=True); p.add_argument('--sdk',type=Path,required=True); a=p.parse_args()
 print('IMPORTED',integrate(a.repo,a.audio,a.sdk),'native audio clips')
