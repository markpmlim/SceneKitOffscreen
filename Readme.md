This set of simple programs demonstrates how to write a texture  or image object which can be assigned to the contents of an instance of SCNMaterialProperty. The first 3 programs instantiate an SCNRenderer object which will be used to render an SCNScene offscreen and output its contents to a texture or CGImage object. The last program uses a compute kernel function to generate a texture object.


OGLTexture: The default OpenGL version running on macOS is v2.1. The "pixelFormat" property of an instance of SCNView can be set to use modern OpenGL core profile. To render the SCNScene to a texture, an offscreen OpenGL frame buffer object must be created. The demo uses two pairs of OpenGL vertex-fragment shaders. One pair named "renderTexture" is loaded and compiled to create an OpenGL shader program. 

This OpenGL shader program is called by the offscreen SCNRenderer object to create a 2D texture. For the procedure to work properly, the demo sets the offscreen renderer's "delegate" property to self (an instance of NSViewController) and implements the SCNSceneRendererDelegate method

renderer:willRenderScene:atTime:.

Calling the SCNRenderer method renderAtTime: will transfer control to the SCNSceneRendererDelegate method renderer:willRenderScene:atTime: which does the heavy lifting.

The generated texture must be passed to the second pair of shaders named "passthru". Instead of creating an OpenGL shader program, the demo loads the source codes of the shaders and instantiate an SCNProgram object. The idea is to apply the generated texture to a SCNPlane instance. The source codes of "passtrhu.vs" and "passthru.fs" are read in as Swift strings. They are compiled by assigning the strings to the "vertexShader" and "fragmentShader" properties of an instance of SCNProgram. Then the instance of SCNProgram is assigned to the "program" property of the plane's material (or geometry) property.

The shader "passthru.fs" has an OpenGL uniform variable named "colorTexture" which is a sampler2D variable. The data represented by this texture object (created by the "renderTexture" set of shaders) is accessed using the appropriate texture lookup function. It is passed to the "passthru.fs" shader using the method handleBindingOfSymbol:usingBlock:.

KIV. Could the OpenGL texture object "textureColorbuffer" be used to instantiate an object which could be assigned to the "contents" property of the scene's background?
Ans: See the demo "OGLImage".


OGLImage: Instead of rendering an OpenGL texture object, this demo renders the scene to an OpenGL render buffer which is attached to the offscreen framebuffer object. It reads the data from the render buffer using the OpenGL call "glReadPixels" to instantiate an CGImage object.
This CGImage object can be assigned to the "contents" property of the firstMaterial property of an SCNGeometry instance.


MetalTexture: Using the same idea, if the renderingAPI is Metal, the offscreen renderer can write the contents of an SCNScene to a rendering destination by calling the method 

renderAtTime:viewport:commandBuffer:passDescriptor:.

However, as noted in the source code, the scene renderer's "currentRenderCommandEncoder" property can not be used to set up buffers, textures and other parameters needed by a Metal vertex or fragment function.



MetalTexture2: Creating an instance of MTLTexture to be assigned to the material (or geometry) property of an SCNNode can be relatively easy if a compute kernel function is called to do the needful.  After the compute kernel function has created the texture, it can be assigned straightaway to the plane's material via its setValue:forKey: method. Once again a pair of vertex/fragment functions must be written. However, the parameters to be passed to these 2 functions are very different from an ordinary pair of Metal vertex-fragment functions. Refer to Apple's SCNProgram documentation.


Requirements:

IDE: XCode 8.x running on macOS 10.12.x or later

It should run on macOS 10.11.x

Note: OpenGL is deprecated as of macOS 10.14.x (Mojave)


Links:

https://stackoverflow.com/questions/50667318/how-to-render-mtltexture-generated-by-scnrenderer

https://stackoverflow.com/questions/34616369/how-can-i-render-a-scnscene-to-a-texture

https://stackoverflow.com/questions/50371498/metal-2-metalkit-mtkview-and-scenekit-interoperability

https://github.com/lachlanhurst/SceneKitOffscreenRendering

https://stackoverflow.com/questions/29060465/rendering-a-scenekit-scene-to-video-output

