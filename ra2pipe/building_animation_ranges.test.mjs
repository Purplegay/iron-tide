import assert from 'node:assert/strict';
import {buildingAnimationRange, separateBuildingHealthRanges} from './building_animation_ranges.mjs';
const prism = {image:'GAPRIS_A', ...buildingAnimationRange('GAPRIS_A', {start:'0',end:'9'},20),
  dmg:{image:'GAPRIS_A', ...buildingAnimationRange('GAPRIS_A',{start:'10',end:'19'},20)}};
separateBuildingHealthRanges(prism);
assert.deepEqual([prism.loopStart,prism.loopEnd,prism.dmg.loopStart,prism.dmg.loopEnd], [0,9,10,19]);
const power = {image:'GAPOWR_A', ...buildingAnimationRange('GAPOWR_A',{loopstart:'0',loopend:'8'},32),
  dmg:{image:'GAPOWR_A', ...buildingAnimationRange('GAPOWR_A',{start:'8',loopstart:'8',loopend:'16'},32)}};
separateBuildingHealthRanges(power);
assert.deepEqual([power.loopStart,power.loopEnd,power.dmg.loopStart,power.dmg.loopEnd,power.frames], [0,7,8,15,16]);
assert.deepEqual(buildingAnimationRange('GAPRIS_B',{loopstart:'9',loopend:'17'},18), {loopStart:9,loopEnd:17,frames:18});
assert.deepEqual(buildingAnimationRange('OTHER',{start:'2',end:'5',loopstart:'3',loopend:'4'},8), {loopStart:3,loopEnd:4,frames:8});
assert.deepEqual(buildingAnimationRange('OTHER',{start:'2',end:'-1'},8), {loopStart:2,loopEnd:7,frames:8});
assert.deepEqual(buildingAnimationRange('OTHER',{},1), {loopStart:0,loopEnd:0,frames:1});
console.log('PASS: building animation intervals, health separation and shadow boundary');
for (const image of ['GADEPT_A', 'GADEPT_C']) {
  for (const start of [0, 10]) {
    assert.deepEqual(buildingAnimationRange(image, {start:String(start),end:'10'},20),
      {loopStart:start,loopEnd:start+9,frames:20});
  }
}
console.log('PASS: original repair arm End count preserves healthy/damaged ten-frame segments');
for (const frames of [30, 60]) {
  assert.deepEqual(buildingAnimationRange('GAWEAP_A', {loopstart:'0',loopend:'15'},frames),
    {loopStart:0,loopEnd:14,frames:30});
  assert.deepEqual(buildingAnimationRange('GAWEAP_A', {loopstart:'16',loopend:'29'},frames),
    {loopStart:15,loopEnd:29,frames:30});
}
for (const [image, frames, half, damagedStart] of [
  ['GACNST_A',12,3,3], ['NACNST_B',42,21,22], ['GAYARD_C',60,15,15], ['GAYARD_D',84,42,41],
  ...[1,2,3,4].map(n => ['NAREFNL'+n,12,3,3])
]) {
  assert.deepEqual(buildingAnimationRange(image,{loopstart:'0'},frames),
    {loopStart:0,loopEnd:half-1,frames:half*2});
  assert.deepEqual(buildingAnimationRange(image,{loopstart:String(damagedStart)},frames),
    {loopStart:half,loopEnd:half*2-1,frames:half*2});
}
console.log('PASS: construction and shipyard crane/light health and shadow boundaries');
console.log('PASS: original factory flag keeps fifteen frames in each health segment');
