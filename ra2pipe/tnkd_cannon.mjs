import fs from 'node:fs';
import {decodePng} from './shp_detail_lib.mjs';

// Draw in local muzzle coordinates: X=0 is the imported firing point.
export const cannonSkin=decodePng(fs.readFileSync(new URL('./materials/tnkd-cannon.png',import.meta.url)));
export function drawCannon(project,quad){
  const tau=2*Math.PI;
  const bodyRadius=x=>3.35+1.65*Math.max(0,Math.min(1,(-x-14)/10));
  const point=(x,r,a,u,v)=>project(x,r*Math.cos(a),r*Math.sin(a),u,v);
  function jacket(stations){
    for(let j=1;j<stations.length;j++)for(let i=0;i<32;i++){
      const a=tau*i/32,b=tau*(i+1)/32;
      const ring=([x,r],angle)=>point(x,r,angle,(x+31)/31,angle/tau);
      quad(ring(stations[j-1],a),ring(stations[j],a),ring(stations[j],b),ring(stations[j-1],b),
           .69+.31*Math.max(0,Math.sin((a+b)/2+.2)),5);
    }
  }
  jacket([-31,-24,-14,-7,-1,0.55].map(x=>[x,bodyRadius(x)]));
  // Opposed feeds spiral in opposite directions. Radial relief alternates at
  // each crossover, so one pipe lifts over the other without a fused joint.
  for(let feed=0;feed<4;feed++){
    const bank=feed%2, winding=bank===0?1:-1;
    const path=(t,theta)=>{
      const x=-30+29*t;
      const twist=7.25*t;
      const a=(feed>>1)*Math.PI+(bank===0?.33:1.97)+winding*twist;
      const collarGap=Math.min(...[-29.5,-16,-2].map(station=>Math.abs(station-x)));
      const lift=Math.min(1,Math.max(0,(collarGap-.6)/1.2));
      const relief=.74*winding*Math.cos(2*twist-1.64)*lift;
      const radius=bodyRadius(x)+.76+.39*lift+relief;
      const wire=t<.045||t>.955?.82:.57;
      const radial=radius+wire*Math.cos(theta);
      const circum=wire*Math.sin(theta);
      return project(x,radial*Math.cos(a)-circum*Math.sin(a),radial*Math.sin(a)+circum*Math.cos(a),t,theta/tau);
    };
    for(let step=0;step<56;step++)for(let k=0;k<12;k++){
      const t0=step/56,t1=(step+1)/56,a=tau*k/12,b=tau*(k+1)/12;
      if(t0<.045||t1>.955){
        const plug=(t,theta)=>({...path(t,theta),u:.935+.04*Math.cos(theta),v:.24+.06*Math.sin(theta)});
        quad(plug(t0,a),plug(t1,a),plug(t1,b),plug(t0,b),1.12,5);
      }else quad(path(t0,a),path(t1,a),path(t1,b),path(t0,b),1,10+feed);
    }
  }
  // Short locking collars interrupt the light where the lines pass under steel.
  for(const x of [-29.5,-16.0,-2.0]){
    const r=bodyRadius(x)+1.62;
    jacket([[x-.66,r-.65],[x-.46,r],[x+.46,r],[x+.66,r-.65]]);
  }
  // Machined muzzle lip and recessed dark bore cover the native flat voxel cap.
  const lipX=.61;
  for(let i=0;i<32;i++){
    const a=tau*i/32,b=tau*(i+1)/32;
    const face=(r,angle)=>point(lipX,r,angle,.50+.33*r/3.36*Math.cos(angle),.5+.33*r/3.36*Math.sin(angle));
    quad(face(3.36,a),face(3.36,b),face(2.05,b),face(2.05,a),1.12,5);
    quad(face(2.05,a),face(2.05,b),face(0,b),face(0,a),.15,5);
  }
}
