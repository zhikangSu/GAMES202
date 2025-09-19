# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a GAMES202 (Real-Time High-Quality Rendering) homework project implementing a WebGL-based 3D rendering engine with shadow mapping. The project is a browser-based graphics application that renders 3D scenes with real-time shadows.

## Development Commands

### Running the Application
```bash
# For Visual Studio Code users with Live Server extension
# Right-click on index.html and select "Open with Live Server"

# For Node.js users
npm install http-server -g
http-server . -p 8000
```

No build process, linting, or test commands exist - this is a pure client-side WebGL application.

## Architecture Overview

### Rendering Pipeline
The application follows a two-pass shadow mapping approach:
1. **Shadow Pass**: Renders scene from light's perspective to generate shadow map
2. **Render Pass**: Renders scene from camera's perspective using shadow map for shadow calculations

### Core Components

**WebGLRenderer** (`src/renderers/WebGLRenderer.js`):
- Central rendering system managing render loop
- Handles both shadow and regular mesh rendering
- Manages frame buffer switching between shadow map generation and final render
- Supports single light source with automatic mesh rotation

**Material System**:
- `ShadowMaterial`: Renders depth information for shadow map generation
- `PhongMaterial`: Implements Phong shading with shadow map sampling
- Materials are built asynchronously and require light MVP matrix calculations

**Lighting System**:
- `DirectionalLight`: Orthographic projection for shadow mapping
- Light MVP matrix calculation for shadow map coordinate transformation
- FBO (Frame Buffer Object) management for shadow map storage

**Shader Architecture**:
- Shaders organized in pairs (vertex/fragment) under `src/shaders/`
- `shadowShader/`: Depth-only rendering for shadow maps  
- `phongShader/`: Phong lighting with shadow mapping
- `lightShader/`: Light cube visualization

### Key Technical Details

**Shadow Mapping Implementation**:
- 2048x2048 shadow map resolution (configurable via `resolution` variable)
- Uses orthographic projection with 200-unit ortho size
- White background clear color prevents edge shadow artifacts
- Shadow bias and filtering handled in fragment shaders

**Asset Loading**:
- OBJ/MTL model loading via Three.js loaders
- Assets include floor, character model ("mary"), and test objects
- Texture loading with preload hints in HTML

**Camera Controls**:
- Three.js OrbitControls for user interaction
- Configurable rotate/zoom/pan speeds
- Initial camera position at [30, 30, 30]

### Development Notes

- All 3D models should be placed in `assets/` with corresponding .obj/.mtl/.png files
- Shader modifications require both vertex and fragment shader files
- Light position and properties are configured in `engine.js`
- Mesh transformation animations are handled in the render loop
- The project uses Chinese comments in some files, indicating Chinese language development context

### File Organization Patterns
- Shaders: Organized by functionality (shadow, phong, light) with separate vertex/fragment files
- Materials: Each material type has its own class and async builder function
- Assets: Grouped by object type (floor, mary, testObj) with complete material files