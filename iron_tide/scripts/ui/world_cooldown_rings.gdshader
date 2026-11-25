shader_type canvas_item;
render_mode unshaded;
varying flat vec4 state;
varying flat vec4 ink;
void vertex(){state=INSTANCE_CUSTOM;ink=COLOR;}
void fragment(){
 vec2 p=(vec2(UV.x,1.0-UV.y)-vec2(0.5))*2.0*(state.x+2.5);
 float d=length(p);
 vec4 bg=vec4(0.015,0.025,0.04,0.92*clamp(state.x+2.5-d,0.0,1.0));
 float width=state.z>0.5?1.0:0.75;
 float band=clamp(width+0.5-abs(d-state.x),0.0,1.0);
 vec4 color=state.z>0.5?ink:vec4(0.25,0.32,0.39,1.0);
 if(state.z>0.5 && state.w<0.5) band=max(band,clamp(1.75-d,0.0,1.0));
 if(state.z<0.5 && state.y>0.001){
  float angle=mod(atan(p.y,p.x)+1.57079632679+6.28318530718,6.28318530718);
  if(angle<6.28318530718*state.y){color=ink;band=clamp(1.5-abs(d-state.x),0.0,1.0);}
 }
 float alpha=band*color.a;
 float result_alpha=alpha+bg.a*(1.0-alpha);
 COLOR=vec4((color.rgb*alpha+bg.rgb*bg.a*(1.0-alpha))/max(0.00001,result_alpha),result_alpha);
}
