//
//  ViewController.swift
//  OGLTexture
//
//  Created by mark lim pak mun on 19/04/2019.
//  Copyright © 2019 Incremental Innovation. All rights reserved.
//

import Cocoa
import SceneKit
import OpenGL.GL3

class ViewController: NSViewController, SCNSceneRendererDelegate {
    var sceneView: SCNView {
        return self.view as! SCNView
    }
    var scene: SCNScene!

    // For the OpenGL program
    var offScreenRenderer: SCNRenderer!
    var offScreenScene: SCNScene!
    var sharedContext: NSOpenGLContext!
    var quadVAO: GLuint = 0
    let shader = GLShader()
    var resolutionLoc: GLint = 0
    var fboID: GLuint = 0                   // framebuffer object name (or id)
    var textureColorbuffer: GLuint = 0      // color attachment texture
    var depthRenderBufferObject: GLuint = 0
    let textureWidth: GLsizei = 256
    let textureHeight: GLsizei = 256

    override func viewDidLoad() {
        super.viewDidLoad()
        initGL()

        sharedContext = sceneView.openGLContext!
        sharedContext.makeCurrentContext()
        loadShaders()
        setupFrameBuffer()

        // setup up the SCNRenderer object which will render the contents of 
        // a scene offscreen. The output is to a texture bound to a frame buffer object.
        offScreenRenderer = SCNRenderer(context: sharedContext.cglContextObj)
        offScreenScene = SCNScene()
        offScreenRenderer.scene = offScreenScene
        offScreenRenderer.delegate = self
        // The statement below will call the SCNSceneRendererDelegate method
        //      renderer:willRenderScene:atTime:
        offScreenRenderer.render(atTime: 0)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // Use Core Profile shaders.
    func initGL() {
        let pixelFormatAttrsBestCase: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFABackingStore), UInt32(1),
            UInt32(NSOpenGLPFADepthSize), UInt32(24),
            UInt32(NSOpenGLPFAOpenGLProfile),
            UInt32(NSOpenGLProfileVersion3_2Core),
            UInt32(0)
        ]

        let pf = NSOpenGLPixelFormat(attributes: pixelFormatAttrsBestCase)
        if (pf == nil) {
            Swift.print("Couldn't init opengl at all, sorry :(")
            abort()
        }

        // This should be sufficient to create a 3.2 OpenGL core profile
        sceneView.pixelFormat = pf
        // The 2 statements below may not be necessary.
        //let glContext = NSOpenGLContext(format: pf!, share: nil)!
        //sceneView.openGLContext = glContext
    }

    // This pair of shaders is used by the offscreen renderer.
    func loadShaders() {
        var shaderIDs = [GLuint]()
        var shaderID = shader.compileShader(filename: "renderTexture.vs",
                                            shaderType: GLenum(GL_VERTEX_SHADER))
        shaderIDs.append(shaderID)
        shaderID = shader.compileShader(filename: "renderTexture.fs",
                                        shaderType: GLenum(GL_FRAGMENT_SHADER))
        shaderIDs.append(shaderID)
        shader.createAndLinkProgram(shaders: shaderIDs)
        resolutionLoc = glGetUniformLocation(shader.program, "resolution")
    }

    // Setup the environment for an offscreen render.
    func setupFrameBuffer() {
        // The geometry of the quad is embedded in the vertex shader.
        glGenVertexArrays(1, &quadVAO)
        // Setup our offscreen framebuffer object (FBO)
        glGenFramebuffers(1, &fboID)
        // Make it the active framebuffer
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fboID)
        // Now instantiate a texture object ...
        glActiveTexture(GLenum(GL_TEXTURE0))
        glGenTextures(1, &textureColorbuffer)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureColorbuffer)
        glTexImage2D(GLenum(GL_TEXTURE_2D),
                     0,
                     GL_RGBA8,
                     textureWidth, textureHeight,
                     0,
                     GLenum(GL_RGBA),
                     GLenum(GL_UNSIGNED_BYTE),
                     nil)               // nil means allocate memory for the texture object.

        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLfloat(GL_LINEAR))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLfloat(GL_LINEAR))

        // ... and attach it to the FBO so we can write to the texture
        // as if it were a normal color/depth/stencil buffer.
        glFramebufferTexture2D(GLenum(GL_FRAMEBUFFER),
                               GLenum(GL_COLOR_ATTACHMENT0),
                               GLenum(GL_TEXTURE_2D),
                               textureColorbuffer,
                               0)           // mipmap level

        // Create the render buffer for depth
        // We will not be sampling its data.
        glGenRenderbuffers(1, &depthRenderBufferObject);
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), depthRenderBufferObject)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER),
                              GLenum(GL_DEPTH_COMPONENT),
                              textureWidth, textureHeight)
        
        // Attach the depth render buffer object to the FBO as a depth attachment.
        // This might not be necessary.
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER),
                                  GLenum(GL_DEPTH_ATTACHMENT),
                                  GLenum(GL_RENDERBUFFER),
                                  depthRenderBufferObject)

        let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        if status != GLenum(GL_FRAMEBUFFER_COMPLETE) {
            exit(1)
        }

        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)    // Unbind the FBO for now
    }

    // Render to the offscreen frame buffer.
    // The renderer parameter is "offScreenRenderer"
    func renderer(_ renderer: SCNSceneRenderer,
                  willRenderScene scene: SCNScene,
                  atTime time: TimeInterval) {

        sharedContext.makeCurrentContext()
        CGLLockContext(sharedContext.cglContextObj!)

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fboID)
        glClear(GLenum(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        // For offscreen rendering the rectangular drawing region must set.
        // Or it will be 1 pixel x 1 pixel by default.
        glViewport(0, 0, textureWidth, textureHeight)
        // Set the background to gray to indicate the render method had been
        // called in case the shaders are not working properly.
        glClearColor(0.5, 0.5, 0.5, 1.0)

        shader.use()
        glUniform2f(resolutionLoc,
                    GLfloat(textureWidth), GLfloat(textureHeight))
        glBindVertexArray(quadVAO)
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        glBindVertexArray(0)
        glUseProgram(0)
        // Make the system default active
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)

        sharedContext.update()
        sharedContext.flushBuffer()
        CGLUnlockContext(sharedContext.cglContextObj!)
    }

    // The offscreen renderer should have done its work.
    // Instantiate a plane and texture it with the output of the offscreen renderer.
    override func viewWillAppear() {
        scene = SCNScene()
        sceneView.scene = scene
        let plane = SCNPlane(width: 1.0, height: 1.0)
        plane.widthSegmentCount = 10
        plane.heightSegmentCount = 10
        SCNTransaction.flush()

        plane.firstMaterial?.isDoubleSided = true
        let planeNode = SCNNode(geometry: plane)
        scene.rootNode.addChildNode(planeNode)
        sceneView.isPlaying = true
        sceneView.loops = true
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = true
        scene.background.contents = NSColor.gray

        // Instantiate an SCNProgram object.
        let shaderName = "passthru"
        let vertexShaderURL = Bundle.main.url(forResource: shaderName,
                                              withExtension: "vs")
        let fragmentShaderURL = Bundle.main.url(forResource: shaderName,
                                                withExtension: "fs")
        var vertexShader: String!
        do {
            vertexShader = try String(contentsOf: vertexShaderURL!)
        }
        catch let error {
            print("Can't load vertex shader:", error)
        }
        var fragmentShader: String!
        do {
            fragmentShader = try String(contentsOf: fragmentShaderURL!)
        }
        catch let error {
            print("Can't load fragment shader:", error)
        }

        let program = SCNProgram()
        program.vertexShader = vertexShader
        program.fragmentShader = fragmentShader
        program.setSemantic(SCNGeometrySource.Semantic.vertex.rawValue,
                            forSymbol: "aVertex",
                            options: nil)
        program.setSemantic(SCNGeometrySource.Semantic.texcoord.rawValue,
                            forSymbol: "aTexCoord0",
                            options: nil)

        program.setSemantic(SCNModelViewProjectionTransform,
                            forSymbol: "uModelViewProjectionMatrix",
                            options: nil)

        plane.firstMaterial?.program = program
        plane.firstMaterial?.handleBinding(ofSymbol: "colorTexture",
                                           handler: {
            (programId: UInt32, location: UInt32, node: SCNNode?, renderer: SCNRenderer) -> Void in
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_2D), self.textureColorbuffer)
        })
    }
}

