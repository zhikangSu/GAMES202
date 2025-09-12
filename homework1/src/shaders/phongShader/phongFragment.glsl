#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 50
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10

//phongFragment.glsl

#define NEAR_PLANE.01
#define LIGHT_WORLD_SIZE 5.
#define LIGHT_SIZE_UV LIGHT_WORLD_SIZE/FRUSTUM_SIZE

#define EPS 5e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586
#define SHADOW_MAP_SIZE 2048.
#define FRUSTUM_SIZE 400.
#define FILTER_RADIUS 10.

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x){
  // -1 -1
  return fract(sin(x)*10000.);
}

highp float rand_2to1(vec2 uv){
  // 0 - 1
  const highp float a=12.9898,b=78.233,c=43758.5453;
  highp float dt=dot(uv.xy,vec2(a,b)),sn=mod(dt,PI);
  return fract(sin(sn)*c);
}

float unpack(vec4 rgbaDepth){
  const vec4 bitShift=vec4(1.,1./256.,1./(256.*256.),1./(256.*256.*256.));
  return dot(rgbaDepth,bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples(const in vec2 randomSeed){
  
  float ANGLE_STEP=PI2*float(NUM_RINGS)/float(NUM_SAMPLES);
  float INV_NUM_SAMPLES=1./float(NUM_SAMPLES);
  
  float angle=rand_2to1(randomSeed)*PI2;
  float radius=INV_NUM_SAMPLES;
  float radiusStep=radius;
  
  for(int i=0;i<NUM_SAMPLES;i++){
    poissonDisk[i]=vec2(cos(angle),sin(angle))*pow(radius,.75);
    radius+=radiusStep;
    angle+=ANGLE_STEP;
  }
}

void uniformDiskSamples(const in vec2 randomSeed){
  
  float randNum=rand_2to1(randomSeed);
  float sampleX=rand_1to1(randNum);
  float sampleY=rand_1to1(sampleX);
  
  float angle=sampleX*PI2;
  float radius=sqrt(sampleY);
  
  for(int i=0;i<NUM_SAMPLES;i++){
    poissonDisk[i]=vec2(radius*cos(angle),radius*sin(angle));
    
    sampleX=rand_1to1(sampleY);
    sampleY=rand_1to1(sampleX);
    
    angle=sampleX*PI2;
    radius=sqrt(sampleY);
  }
}

//phongFragment.glsl

float findBlocker(sampler2D shadowMap,vec2 uv,float zReceiver){
  int blockerNum=0;
  float blockDepth=0.;
  
  float posZFromLight=vPositionFromLight.z;
  
  float searchRadius=LIGHT_SIZE_UV*(posZFromLight-NEAR_PLANE)/posZFromLight;
  
  poissonDiskSamples(uv);
  for(int i=0;i<NUM_SAMPLES;i++){
    float shadowDepth=unpack(texture2D(shadowMap,uv+poissonDisk[i]*searchRadius));
    if(zReceiver>shadowDepth){
      blockerNum++;
      blockDepth+=shadowDepth;
    }
  }
  
  if(blockerNum==0)
  return-1.;
  else
  return blockDepth/float(blockerNum);
  
}

//phongFragment.glsl
float getShadowBias(float c,float filterRadiusUV){
  vec3 normal=normalize(vNormal);
  vec3 lightDir=normalize(uLightPos-vFragPos);
  float fragSize=(1.+ceil(filterRadiusUV))*(FRUSTUM_SIZE/SHADOW_MAP_SIZE/2.);
  return max(fragSize,fragSize*(1.-dot(normal,lightDir)))*c;
}

float useShadowMap(sampler2D shadowMap,vec4 shadowCoord,float biasC,float filterRadiusUV){
  
  // 4. 从Shadow Map中采样深度值
  vec4 rgbaDepth=texture2D(shadowMap,shadowCoord.xy);
  float shadowMapDepth=unpack(rgbaDepth);
  
  // 5. 获取当前片元在光源空间的深度
  float currentDepth=shadowCoord.z;
  
  // 6. 深度比较，添加偏移来避免阴影痤疮(shadow acne)
  // EPS=.001;// 可以根据场景调整这个值
  float bias=getShadowBias(biasC,filterRadiusUV);
  // 如果当前深度大于Shadow Map中的深度（加上偏移），说明在阴影中
  if(currentDepth-bias>shadowMapDepth+EPS){
    return 0.;// 在阴影中
  }else{
    return 1.;// 不在阴影中
  }
}

float PCF(sampler2D shadowMap,vec4 coords,float biasC,float filterRadiusUV){
  //uniformDiskSamples(coords.xy);
  poissonDiskSamples(coords.xy);//使用xy坐标作为随机种子生成
  float visibility=0.;
  for(int i=0;i<NUM_SAMPLES;i++){
    vec2 offset=poissonDisk[i]*filterRadiusUV;
    float shadowDepth=useShadowMap(shadowMap,coords+vec4(offset,0.,0.),biasC,filterRadiusUV);
    if(coords.z>shadowDepth+EPS){
      visibility++;
    }
  }
  return 1.-visibility/float(NUM_SAMPLES);
}

float PCSS(sampler2D shadowMap,vec4 coords,float biasC){
  float zReceiver=coords.z;
  
  // STEP 1: avgblocker depth
  float avgBlockerDepth=findBlocker(shadowMap,coords.xy,zReceiver);
  
  if(avgBlockerDepth<-EPS)
  return 1.;
  
  // STEP 2: penumbra size
  float penumbra=(zReceiver-avgBlockerDepth)*LIGHT_SIZE_UV/avgBlockerDepth;
  float filterRadiusUV=penumbra;
  
  // STEP 3: filtering
  return PCF(shadowMap,coords,biasC,filterRadiusUV);
}

vec3 blinnPhong(){
  vec3 color=texture2D(uSampler,vTextureCoord).rgb;
  color=pow(color,vec3(2.2));
  
  vec3 ambient=.05*color;
  
  vec3 lightDir=normalize(uLightPos);
  vec3 normal=normalize(vNormal);
  float diff=max(dot(lightDir,normal),0.);
  vec3 light_atten_coff=
  uLightIntensity/pow(length(uLightPos-vFragPos),2.);
  vec3 diffuse=diff*light_atten_coff*color;
  
  vec3 viewDir=normalize(uCameraPos-vFragPos);
  vec3 halfDir=normalize((lightDir+viewDir));
  float spec=pow(max(dot(halfDir,normal),0.),32.);
  vec3 specular=uKs*light_atten_coff*spec;
  
  vec3 radiance=(ambient+diffuse+specular);
  vec3 phongColor=pow(radiance,vec3(1./2.2));
  return phongColor;
}

void main(void){
  //vPositionFromLight为光源空间下投影的裁剪坐标，除以w结果为NDC坐标
  vec3 shadowCoord=vPositionFromLight.xyz/vPositionFromLight.w;
  //把[-1,1]的NDC坐标转换为[0,1]的坐标
  shadowCoord.xyz=(shadowCoord.xyz+1.)/2.;
  
  float visibility=1.;
  float bias=.4;
  
  // 无PCF时的Shadow Bias
  float nonePCFBiasC=.4;
  // 有PCF时的Shadow Bias
  float pcfBiasC=.2;
  // PCF的采样范围，因为是在Shadow Map上采样，需要除以Shadow Map大小，得到uv坐标上的范围
  float filterRadiusUV=FILTER_RADIUS/SHADOW_MAP_SIZE;
  
  // visibility=useShadowMap(uShadowMap,vec4(shadowCoord,1.),bias,0.);
  // visibility=PCF(uShadowMap,vec4(shadowCoord,1.));
  // visibility=PCF(uShadowMap,vec4(shadowCoord,1.),pcfBiasC,filterRadiusUV);
  //visibility = PCSS(uShadowMap, vec4(shadowCoord, 1.0));
  visibility=PCSS(uShadowMap,vec4(shadowCoord,1.),pcfBiasC);
  
  vec3 phongColor=blinnPhong();
  
  gl_FragColor=vec4(phongColor*visibility,1.);
  
  //gl_FragColor=vec4(phongColor,1.);
  
}

