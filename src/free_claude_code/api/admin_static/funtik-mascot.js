// Warp only the illustrated head and pupils; the plaque and ring remain still.
(() => {
 const host=document.querySelector('.mascot'), img=host?.querySelector('img');
 if(!img)return;
 const reduced=matchMedia('(prefers-reduced-motion: reduce)');
 const fine=matchMedia('(hover: hover) and (pointer: fine)');
 let start;
 start=()=>{
  if(reduced.matches||!fine.matches)return;
  const canvas=document.createElement('canvas');canvas.setAttribute('aria-hidden','true');
  const gl=canvas.getContext('webgl',{alpha:false,antialias:false,preserveDrawingBuffer:false});
  if(!gl)return;
  const shader=(kind,source)=>{const s=gl.createShader(kind);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s};
  try{
   const program=gl.createProgram();
   gl.attachShader(program,shader(gl.VERTEX_SHADER,`attribute vec2 a;varying vec2 uv;void main(){uv=vec2((a.x+1.)*.5,(1.-a.y)*.5);gl_Position=vec4(a,0.,1.);}`));
   gl.attachShader(program,shader(gl.FRAGMENT_SHADER,`
    precision mediump float;varying vec2 uv;uniform sampler2D picture;uniform vec2 eyes;uniform float angle;
    float ellipse(vec2 p,vec2 c,vec2 r){return 1.-smoothstep(.66,1.,length((p-c)/r));}
    void main(){
     float face=ellipse(uv,vec2(.535,.38),vec2(.204,.192));
     float earL=ellipse(uv,vec2(.322,.178),vec2(.085,.145));
     float earR=ellipse(uv,vec2(.748,.202),vec2(.069,.128));
     float weight=max(face,max(earL,earR));
     vec2 origin=vec2(.535,.47),d=uv-origin;
     float a=-angle*weight;float c=cos(a),s=sin(a);
     vec2 p=origin+vec2(c*d.x-s*d.y,s*d.x+c*d.y);
     float pupil=max(ellipse(p,vec2(.422,.333),vec2(.032,.027)),ellipse(p,vec2(.666,.373),vec2(.025,.023)));
     p-=eyes*pupil;
     gl_FragColor=texture2D(picture,p);
    }`));
   gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error('Logo shader link failed');
   gl.useProgram(program);
   const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);
   const attrib=gl.getAttribLocation(program,'a');gl.enableVertexAttribArray(attrib);gl.vertexAttribPointer(attrib,2,gl.FLOAT,false,0,0);
   const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,img);
   const eyeUniform=gl.getUniformLocation(program,'eyes'),angleUniform=gl.getUniformLocation(program,'angle');
   let targetX=0,targetY=0,eyeX=0,eyeY=0,head=0,headTarget=0,frame=0,last=0,headTimer=0,visible=true;
   const enabled=()=>!reduced.matches&&fine.matches&&visible&&!document.hidden;
   const draw=()=>{gl.uniform2f(eyeUniform,eyeX*.006,eyeY*.004);gl.uniform1f(angleUniform,head*5*Math.PI/180);gl.drawArrays(gl.TRIANGLES,0,6)};
   const tick=now=>{frame=0;const dt=Math.min(now-last||16,50);last=now;
    eyeX+=(targetX-eyeX)*(1-Math.exp(-dt/65));eyeY+=(targetY-eyeY)*(1-Math.exp(-dt/65));head+=(headTarget-head)*(1-Math.exp(-dt/280));
    draw();host.dataset.headDegrees=(head*5).toFixed(2);
    if(Math.abs(targetX-eyeX)+Math.abs(targetY-eyeY)+Math.abs(headTarget-head)>.0005&&enabled())frame=requestAnimationFrame(tick);
   };
   const wake=()=>{if(!frame&&enabled()){last=performance.now();frame=requestAnimationFrame(tick)}};
   const reset=()=>{clearTimeout(headTimer);targetX=targetY=headTarget=0;if(enabled())wake();else{cancelAnimationFrame(frame);frame=0;eyeX=eyeY=head=0;draw()}canvas.hidden=reduced.matches||!fine.matches};
   const resize=()=>{const size=Math.min(1000,Math.round(host.clientWidth*Math.min(devicePixelRatio||1,2)));canvas.width=canvas.height=Math.max(1,size);gl.viewport(0,0,canvas.width,canvas.height);draw()};
   host.append(canvas);resize();host.dataset.motion='ready';
   new ResizeObserver(resize).observe(host);
   new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;if(!visible)reset()}).observe(host);
   document.addEventListener('pointermove',e=>{
    if(e.pointerType!=='mouse'||!enabled())return;
    const r=host.getBoundingClientRect();targetX=Math.max(-1,Math.min(1,(e.clientX-r.left-r.width*.53)/Math.max(r.width,innerWidth*.3)));targetY=Math.max(-1,Math.min(1,(e.clientY-r.top-r.height*.35)/Math.max(r.height,innerHeight*.35)));
    if(!headTimer)headTimer=setTimeout(()=>{headTimer=0;headTarget=targetX;wake()},140);
    wake();
   },{passive:true});
   document.documentElement.addEventListener('pointerleave',reset);window.addEventListener('blur',reset);document.addEventListener('visibilitychange',reset);reduced.addEventListener('change',reset);fine.addEventListener('change',reset);
   canvas.addEventListener('webglcontextlost',()=>{cancelAnimationFrame(frame);clearTimeout(headTimer);canvas.hidden=true;host.dataset.motion='fallback'});
  }catch(error){canvas.remove();host.dataset.motion='fallback';console.warn('Logo motion unavailable; using static logo',error)}
 };
 if(img.complete&&img.naturalWidth)start();else img.addEventListener('load',start,{once:true});
})();
