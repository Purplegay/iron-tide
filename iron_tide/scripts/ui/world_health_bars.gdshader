shader_type canvas_item;
render_mode unshaded;
varying flat vec4 state;
varying flat vec4 ink;
uniform float clock_ms;
vec4 over(vec4 under, vec4 top) {
 float alpha=top.a+under.a*(1.0-top.a);
 return vec4((top.rgb*top.a+under.rgb*under.a*(1.0-top.a))/max(alpha,0.00001),alpha);
}
void vertex(){state=INSTANCE_CUSTOM;ink=COLOR;}
void fragment(){
 vec2 size=state.xy;
 // QuadMesh UV has an upward Y axis; world bars read from their top edge.
 vec2 p=vec2(UV.x,1.0-UV.y)*(size+vec2(4.0))-vec2(2.0);
 bool edge=p.x<0.0||p.y<0.0||p.x>=size.x||p.y>=size.y;
 vec4 col=vec4(0.012,0.018,0.028,0.95);
 if(!edge){
  col=over(col,vec4(0.055,0.068,0.088,0.82));
  if(size.y>=4.0){
   if(p.y<1.0) col=over(col,vec4(0.0,0.0,0.0,0.42));
   if(p.y>=size.y-1.0) col=over(col,vec4(0.36,0.44,0.56,0.20));
  }
  float iw=size.x-2.0; float ih=size.y-2.0;
  float ghost=mod(state.w,2.0);
  if(p.x>=1.0 && p.x<size.x-1.0 && p.y>=1.0 && p.y<size.y-1.0){
   if(ghost>state.z+0.004 && p.x<1.0+iw*ghost) col=over(col,vec4(1.0,1.0,1.0,0.4));
   float fw=iw*state.z;
   if(fw>0.5 && p.x<1.0+fw){
    vec4 fill=ink;
    if(state.z<0.18) fill.a*=0.60+0.40*sin(clock_ms*0.012);
    col=over(col,fill);
    if(p.y<1.0+max(1.0,ih*0.34)) col=over(col,vec4(mix(fill.rgb,vec3(1.0),0.16),fill.a));
    if(ih>=5.0 && p.y>=size.y-1.0-max(1.0,ih*0.24)) col=over(col,vec4(fill.rgb*0.84,fill.a));
   }
   float n=clamp(round(iw/9.0),2.0,16.0);
   float step_size=iw/n;
   float tick=round((p.x-1.0)/step_size);
   if(tick>=1.0 && tick<n && abs(p.x-1.0-tick*step_size)<0.5) col=over(col,vec4(0.0,0.0,0.0,0.34));
  }
 }
 // Original outline is centred on the outside rectangle, including its outer half pixel.
 if(p.x< -1.0||p.y< -1.0||p.x>=size.x+1.0||p.y>=size.y+1.0) col=vec4(0.0);
 if(state.w>=2.0 && p.x<size.x+1.0 && p.y<size.y+1.0 && (p.x< -1.0||p.y< -1.0||p.x>=size.x||p.y>=size.y)) col=over(col,vec4(1.0,1.0,1.0,0.62));
 COLOR=col;
}
