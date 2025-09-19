# GAMES202 多光源渲染系统架构分析

## 系统概述

这是一个基于WebGL的3D渲染引擎，实现了实时阴影映射的多光源渲染系统。整个系统采用了经典的Shadow Mapping技术，支持动态多光源和实时阴影生成。

## 核心架构

### 渲染管线
```
资源加载 → 材质创建 → 几何体处理 → 多光源渲染循环
    ↓           ↓           ↓              ↓
loadOBJ → Material系统 → MeshRender → WebGLRenderer
```

## 文件功能详解

### 1. 入口文件：`src/engine.js`
**主要功能：**
- 初始化WebGL上下文和画布
- 创建摄像机和控制器
- 配置多个光源（支持动态光源）
- 加载3D模型和场景设置
- 启动渲染循环

**关键函数：**
- `GAMES202Main()`: 主入口函数，初始化整个渲染系统
- `setTransform(t_x, t_y, t_z, r_x, r_y, r_z, s_x, s_y, s_z)`: 创建变换参数对象
- `mainLoop(now)`: 渲染循环，计算deltaTime并调用renderer.render()

**多光源实现：**
```javascript
// 第一个光源
const directionLight = new DirectionalLight(2500, [1, 1, 1], lightPos1, focalPoint, lightUp, true, renderer.gl);
renderer.addLight(directionLight);

// 第二个光源
const directionLight2 = new DirectionalLight(2500, [1, 1, 1], lightPos2, focalPoint, lightUp, true, renderer.gl);
renderer.addLight(directionLight2);
```

**与其他文件的联系：**
- 使用 `WebGLRenderer` 作为核心渲染器
- 调用 `loadOBJ` 加载3D模型
- 创建 `DirectionalLight` 光源对象

---

### 2. 渲染器：`src/renderers/WebGLRenderer.js`
**主要功能：**
- 管理所有的网格渲染器（meshes、shadowMeshes）
- 管理光源列表
- 实现多光源渲染循环
- 处理阴影贴图生成和混合

**关键函数：**
- `addLight(light)`: 添加光源到渲染器
- `addMeshRender(mesh)`: 添加常规网格渲染器
- `addShadowMeshRender(mesh)`: 添加阴影网格渲染器
- `render(time, deltaime)`: 核心渲染函数

**多光源渲染流程：**
```javascript
for (let l = 0; l < this.lights.length; l++) {
    // 1. 切换到当前光源的帧缓冲区
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.lights[l].entity.fbo);

    // 2. 光源旋转动画
    let lightPos = vec3.rotateY(lightPos, lightPos, focalPoint, rotationSpeed * deltaTime);

    // 3. Shadow Pass - 生成阴影贴图
    for (let i = 0; i < this.shadowMeshes.length; i++) {
        if (this.shadowMeshes[i].material.lightIndex != l) continue; // 过滤光源
        this.shadowMeshes[i].draw(this.camera);
    }

    // 4. 多光源混合设置
    if (l != 0) {
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.ONE, gl.ONE); // 叠加混合
    }

    // 5. Camera Pass - 最终渲染
    for (let i = 0; i < this.meshes.length; i++) {
        if (this.meshes[i].material.lightIndex != l) continue; // 过滤光源
        this.meshes[i].draw(this.camera);
    }
}
```

**与其他文件的联系：**
- 管理来自 `loadOBJ` 创建的 `MeshRender` 对象
- 使用 `DirectionalLight` 的阴影贴图和MVP矩阵
- 协调所有材质系统的渲染

---

### 3. 网格渲染器：`src/renderers/MeshRender.js`
**主要功能：**
- 封装单个3D对象的渲染逻辑
- 管理顶点缓冲区（位置、法线、纹理坐标、索引）
- 绑定着色器参数和几何体数据
- 执行具体的绘制调用

**关键函数：**
- `constructor(gl, mesh, material)`: 初始化缓冲区和着色器
- `bindGeometryInfo()`: 绑定几何体属性到着色器
- `bindCameraParameters(camera)`: 计算并绑定MVP矩阵
- `bindMaterialParameters()`: 绑定材质参数（纹理、光照参数等）
- `draw(camera)`: 执行绘制调用

**变换矩阵计算：**
```javascript
// 模型变换矩阵
mat4.translate(modelMatrix, modelMatrix, this.mesh.transform.translate);
mat4.rotateX(modelMatrix, modelMatrix, this.mesh.transform.rotate[0]);
mat4.rotateY(modelMatrix, modelMatrix, this.mesh.transform.rotate[1]);
mat4.rotateZ(modelMatrix, modelMatrix, this.mesh.transform.rotate[2]);
mat4.scale(modelMatrix, modelMatrix, this.mesh.transform.scale);
```

**与其他文件的联系：**
- 使用 `Mesh` 对象的几何体数据
- 使用 `Material` 对象的着色器和参数
- 被 `WebGLRenderer` 调用执行渲染

---

### 4. 模型加载器：`src/loads/loadOBJ.js`
**主要功能：**
- 使用Three.js加载器加载OBJ/MTL格式的3D模型
- 为每个光源创建对应的材质
- 创建MeshRender对象并添加到渲染器

**关键函数：**
- `loadOBJ(renderer, path, name, objMaterial, transform)`: 主加载函数

**多光源材质创建：**
```javascript
// 为每个光源创建材质
for(let i = 0; i < renderer.lights.length; i++){
    let light = renderer.lights[i].entity;

    // 创建Phong材质和Shadow材质
    material = buildPhongMaterial(colorMap, specular, light, Translation, Rotation, Scale, i, ...);
    shadowMaterial = buildShadowMaterial(light, Translation, Rotation, Scale, i, ...);

    // 异步创建MeshRender并添加到渲染器
    material.then((data) => {
        let meshRender = new MeshRender(renderer.gl, mesh, data);
        renderer.addMeshRender(meshRender);
    });
}
```

**与其他文件的联系：**
- 使用 `buildPhongMaterial` 和 `buildShadowMaterial` 创建材质
- 创建 `MeshRender` 对象
- 将渲染器添加到 `WebGLRenderer`

---

### 5. 材质系统

#### 5.1 基础材质：`src/materials/Material.js`
**主要功能：**
- 材质系统的基类
- 管理着色器uniform和attribute
- 编译着色器程序
- **新增：lightIndex字段用于多光源过滤**

**关键函数：**
- `constructor(uniforms, attribs, vsSrc, fsSrc, frameBuffer, lightIndex)`: 构造函数，新增lightIndex参数
- `setMeshAttribs(extraAttribs)`: 设置网格的额外属性
- `compile(gl)`: 编译着色器程序

#### 5.2 Phong材质：`src/materials/PhongMaterial.js`
**主要功能：**
- 实现Phong光照模型
- 处理阴影贴图采样
- 计算光源的MVP矩阵

**关键参数：**
- `uSampler`: 漫反射纹理
- `uKs`: 镜面反射系数
- `uLightIntensity`: 光源强度
- `uShadowMap`: 阴影贴图
- `uLightMVP`: 光源MVP矩阵

#### 5.3 阴影材质：`src/materials/ShadowMaterial.js`
**主要功能：**
- 专门用于阴影贴图生成
- 只输出深度信息
- 使用光源视角的MVP矩阵

---

### 6. 光源系统

#### 6.1 方向光：`src/lights/DirectionalLight.js`
**主要功能：**
- 实现方向光源
- 管理阴影贴图的帧缓冲区
- 计算光源空间的MVP矩阵

**关键函数：**
- `CalcLightMVP(translate, rotate, scale)`: 计算光源MVP矩阵
  ```javascript
  // 使用正交投影矩阵
  mat4.ortho(projectionMatrix, -orthoSize, orthoSize, -orthoSize, orthoSize, 0.01, 200);
  // 光源视图矩阵
  mat4.lookAt(viewMatrix, this.lightPos, this.focalPoint, this.lightUp);
  ```

**与其他文件的联系：**
- 被 `engine.js` 创建和配置
- 为 `Material` 系统提供MVP矩阵
- FBO用于 `MeshRender` 的阴影渲染

#### 6.2 发光材质：`src/lights/Light.js`
**主要功能：**
- 光源的可视化显示
- 计算光源强度

---

### 7. 几何体系统：`src/objects/Mesh.js`
**主要功能：**
- 封装3D几何体数据（顶点、法线、纹理坐标、索引）
- 管理变换信息（平移、旋转、缩放）
- 提供内置几何体（立方体）

**关键类：**
- `TRSTransform`: 变换类，包含translate、rotate、scale
- `Mesh`: 几何体类，包含顶点数据和变换信息

---

## 多光源渲染流程

### 1. 初始化阶段
```
engine.js创建多个DirectionalLight →
loadOBJ为每个光源创建材质 →
MeshRender绑定几何体和材质 →
WebGLRenderer管理所有渲染器
```

### 2. 渲染循环
```
WebGLRenderer.render()开始 →
for(每个光源) {
    切换到光源FBO →
    Shadow Pass: 渲染阴影贴图 →
    设置混合模式(如果不是第一个光源) →
    Camera Pass: 渲染最终图像 →
}
```

### 3. 光源过滤机制
通过 `material.lightIndex` 确保每个光源只渲染属于自己的材质：
```javascript
if (this.meshes[i].material.lightIndex != l) continue;
```

## 关键技术点

### 1. 阴影映射
- 使用2048x2048分辨率的深度纹理
- 正交投影避免透视失真
- 白色背景防止边缘阴影

### 2. 多光源混合
- 第一个光源：基础渲染
- 后续光源：使用 `gl.ONE + gl.ONE` 混合模式叠加

### 3. 动态光源旋转
- 使用 `vec3.rotateY()` 实现Y轴旋转
- 不同光源有不同的旋转速度

### 4. 性能优化
- lightIndex过滤避免重复渲染
- 异步材质加载
- 帧缓冲区复用

## 文件依赖关系图

```
engine.js (入口)
    ├── WebGLRenderer.js (核心渲染器)
    │   ├── MeshRender.js (单个对象渲染)
    │   │   ├── Mesh.js (几何体)
    │   │   └── Material.js (材质基类)
    │   │       ├── PhongMaterial.js (Phong光照)
    │   │       └── ShadowMaterial.js (阴影材质)
    │   └── DirectionalLight.js (方向光)
    │       └── Light.js (发光材质)
    └── loadOBJ.js (模型加载)
        └── [连接Material系统和MeshRender]
```

## 总结

这个多光源渲染系统通过精心设计的架构实现了：
- **模块化设计**: 每个文件职责单一，接口清晰
- **可扩展性**: 轻松添加新的光源和材质类型
- **性能优化**: 通过lightIndex过滤和异步加载提升性能
- **实时渲染**: 支持动态光源和实时阴影
- **多光源支持**: 通过混合模式实现多光源叠加效果

整个系统展现了现代3D渲染引擎的典型架构模式，是学习实时渲染技术的优秀案例。