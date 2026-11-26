// Build PCM tracks with a sample-accurate RIFF sustain loop following the attack.
import fs from 'node:fs';
const dir = 'assets/ra2/sfx/hollywood';
const {specs,entries} = JSON.parse(fs.readFileSync('data/ra2/hollywood_audio.json'));
for (let stage = 1; stage <= 3; stage++) {
  const ids = specs[`GattlingGunAttackLoop${stage}`].sounds.slice(0,-1);
  const clips = ids.map(id => fs.readFileSync('assets/ra2/sfx/'+entries[id].file));
  for (const clip of clips) {
    if (clip.toString('ascii',36,40)!=='data' || clip.readUInt32LE(24)!==22050 || clip.readUInt32LE(20)!==65537 || clip.readUInt16LE(34)!==16) throw Error('Expected exported mono 16-bit PCM');
  }
  const pcm = Buffer.concat(clips.map(c=>c.subarray(44)));
  const header = Buffer.from(clips[0].subarray(0,44));
  const sampler = Buffer.alloc(68);
  sampler.write('smpl'); sampler.writeUInt32LE(60,4); sampler.writeUInt32LE(1,36);
  sampler.writeUInt32LE((clips[0].length-44)/2,52); sampler.writeUInt32LE(pcm.length/2-1,56);
  header.writeUInt32LE(36+pcm.length+sampler.length,4); header.writeUInt32LE(pcm.length,40);
  fs.writeFileSync(`${dir}/gatling_sustain_${stage}.wav`,Buffer.concat([header,pcm,sampler]));
}
