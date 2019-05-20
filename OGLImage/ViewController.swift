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
import Accelerate

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
    let textureWidth: GLsizei = 256
    let textureHeight: GLsizei = 256
    var cgImage: CGImage!

    //SCNDisableLinearSpaceRendering info.plist
    override func viewDidLoad() {
        super.viewDidLoad()
        initGL()

        sharedContext = sceneView.openGLContext!
        sharedContext.makeCurrentContext()
        loadShaders()
        glGenVertexArrays(1, &quadVAO)

        // setup up the SCNRenderer object which will render the contents of 
        // a scene offscreen. The output is to a render buffer bind to a frame buffer object.
        offScreenRenderer = SCNRenderer(context: sharedContext.cglContextObj)
        offScreenScene = SCNScene()
        offScreenRenderer.scene = offScreenScene
        offScreenRenderer.delegate = self
        let size = CGSize(width: CGFloat(textureWidth), height: CGFloat(textureHeight))
        cgImage = offScreenRenderer.renderToImageSize(size,
                                                      useFloatComponents: true,
                                                      atTime: 0)
    /*
        // Check that the cgImage was successfully created
        // by writing it out as a tiff picture.
        let nsImage = NSImage(cgImage: cgImage!, size: size)
        let picData = nsImage.tiffRepresentation
        let path = "~/Desktop/image.tiff" as NSString
        let fileURL = URL(fileURLWithPath: path.expandingTildeInPath)
        do {
            try picData?.write(to: fileURL)
        }
        catch let error {
            Swift.print(error)
        }
    */
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

    // This pair of shaders are used by the offscreen renderer.
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

    // Render to the offscreen frame buffer.
    // The renderer parameter is "offScreenRenderer"
    // Note: the CGLContextObj instance have been set by caller;
    // the CGLContextObj instance must be the same as that which was responsible
    // for creating the OpenGL shader program.
    func renderer(_ renderer: SCNSceneRenderer,
                  willRenderScene scene: SCNScene,
                  atTime time: TimeInterval) {

        // Set the background to gray to indicate the render method had been
        // called in case the shaders are not working properly.
        glClearColor(0.5, 0.5, 0.5, 1.0)

        shader.use()
        glUniform2f(resolutionLoc,
                    GLfloat(textureWidth), GLfloat(textureHeight))
        glBindVertexArray(quadVAO)
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        checkGLErrors()
        glBindVertexArray(0)
        glUseProgram(0)
    }

    // The offscreen renderer should have done its work.
    // Instantiate a plane and texture it with the output of the offscreen renderer.
    // There is a problem here; getting a white screen!
    override func viewWillAppear() {
        sharedContext.makeCurrentContext()
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
        plane.firstMaterial?.diffuse.contents = cgImage
     }
}

public extension SCNRenderer {

    // The instance of SCNRenderer was created with our sharedContext's cglContextObj.
    public func renderToImageSize(_ size: CGSize,
                                  useFloatComponents: Bool,
                                  atTime time: TimeInterval) -> CGImage? {

        var thumbnailCGImage: CGImage?

        let width = GLsizei(size.width), height = GLsizei(size.height)
        let samplesPerPixel = 4

        #if os(iOS)
            let oldGLContext = EAGLContext.currentContext()
            let glContext = unsafeBitCast(context, EAGLContext.self)

            EAGLContext.setCurrentContext(glContext)
            objc_sync_enter(glContext)
        #elseif os(OSX)
            // The old and current context must be the same because
            // the shader program is called indirectly by this method.
            let oldGLContext = CGLGetCurrentContext()
            //Swift.print("old context:", oldGLContext)
            let glContext = unsafeBitCast(context, to: CGLContextObj.self)
            //Swift.print("renderer's context:", glContext)
            CGLSetCurrentContext(glContext)
            CGLLockContext(glContext)
        #endif

        // set up the OpenGL buffers
        var fboID: GLuint = 0                   // framebuffer object name
        glGenFramebuffers(1, &fboID)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fboID)
        checkGLErrors()

        // Note: "colorRenderbuffer" is a render buffer name not a texture object name.
        var colorRenderbuffer: GLuint = 0
        glGenRenderbuffers(1, &colorRenderbuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderbuffer)
        if useFloatComponents {
            glRenderbufferStorage(GLenum(GL_RENDERBUFFER),
                                  GLenum(GL_RGBA16F),
                                  width, height)
        }
        else {
            glRenderbufferStorage(GLenum(GL_RENDERBUFFER),
                                  GLenum(GL_RGBA8),
                                  width, height)
        }
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER),
                                  GLenum(GL_COLOR_ATTACHMENT0),
                                  GLenum(GL_RENDERBUFFER),
                                  colorRenderbuffer)
        checkGLErrors()

        var depthRenderbuffer: GLuint = 0
        glGenRenderbuffers(1, &depthRenderbuffer)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), depthRenderbuffer)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER),
                              GLenum(GL_DEPTH_COMPONENT24),
                              width, height)
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER),
                                  GLenum(GL_DEPTH_ATTACHMENT),
                                  GLenum(GL_RENDERBUFFER),
                                  depthRenderbuffer)
        checkGLErrors()

        let framebufferStatus = Int32(glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)))
        assert(framebufferStatus == GL_FRAMEBUFFER_COMPLETE)
        if framebufferStatus != GL_FRAMEBUFFER_COMPLETE {
            return nil
        }

        // For offscreen rendering the rectangular drawing region must set.
        // Or it will be 1 pixel x 1 pixel by default.
        glViewport(0, 0, width, height)
        // Clear the color & depth buffers to their current clearing values.
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        checkGLErrors()
        // The statement below will call the SCNSceneRendererDelegate method
        //      renderer:willRenderScene:atTime:
        render(atTime: time)
        checkGLErrors()

        // create the image
        if useFloatComponents {
            // float components (16-bits of actual precision)
            // slurp bytes out of OpenGL
            typealias ComponentType = Float

            var imageRawBuffer = [ComponentType](repeating: 0.0,
                                                 count: Int(width * height) * samplesPerPixel * MemoryLayout<ComponentType>.stride)
            glReadPixels(GLint(0), GLint(0),
                         width, height,
                         GLenum(GL_RGBA),
                         GLenum(GL_FLOAT),
                         &imageRawBuffer)
            checkGLErrors()
            // flip image vertically — OpenGL has a different 'up' than CoreGraphics
            let rowLength = Int(width) * samplesPerPixel
            for rowIndex in 0..<(Int(height) / 2) {
                let baseIndex = rowIndex * rowLength
                let destinationIndex = (Int(height) - 1 - rowIndex) * rowLength

                swap(&imageRawBuffer[baseIndex..<(baseIndex + rowLength)],
                     &imageRawBuffer[destinationIndex..<(destinationIndex + rowLength)])
            }

            // make the CGImage
            let rawPointer = UnsafeMutableRawPointer(&imageRawBuffer)
            var imageBuffer = vImage_Buffer(
                data: rawPointer.assumingMemoryBound(to: ComponentType.self),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: Int(width) * MemoryLayout<ComponentType>.stride * samplesPerPixel)

            var format = vImage_CGImageFormat(
                bitsPerComponent: UInt32(MemoryLayout<ComponentType>.stride * 8),
                bitsPerPixel: UInt32(MemoryLayout<ComponentType>.stride * samplesPerPixel * 8),
                colorSpace: nil, // defaults to sRGB
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue | CGBitmapInfo.floatComponents.rawValue),
                version: UInt32(0),
                decode: nil,
                renderingIntent: .defaultIntent)
 
            var error: vImage_Error = 0
            thumbnailCGImage = vImageCreateCGImageFromBuffer(&imageBuffer,
                                                             &format,
                                                             nil, nil,
                                                             vImage_Flags(kvImagePrintDiagnosticsToConsole),
                                                             &error)!.takeRetainedValue()
        }
        else {
            // byte components
            // slurp bytes out of OpenGL
            typealias ComponentType = UInt8

            var imageRawBuffer = [ComponentType](repeating: 0,
                                                 count: Int(width * height) * samplesPerPixel * MemoryLayout<ComponentType>.stride)
            glReadPixels(GLint(0), GLint(0),
                         width, height,
                         GLenum(GL_RGBA),
                         GLenum(GL_UNSIGNED_BYTE),
                         &imageRawBuffer)
            checkGLErrors()
            // flip image vertically — OpenGL has a different 'up' than CoreGraphics
            let rowLength = Int(width) * samplesPerPixel
            for rowIndex in 0..<(Int(height) / 2) {
                let baseIndex = rowIndex * rowLength
                let destinationIndex = (Int(height) - 1 - rowIndex) * rowLength

                swap(&imageRawBuffer[baseIndex..<(baseIndex + rowLength)],
                     &imageRawBuffer[destinationIndex..<(destinationIndex + rowLength)])
            }

            // make the CGImage
            let rawPointer = UnsafeMutableRawPointer(&imageRawBuffer)
            var imageBuffer = vImage_Buffer(
                data: rawPointer.assumingMemoryBound(to: ComponentType.self),
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: Int(width) * MemoryLayout<ComponentType>.stride * samplesPerPixel)

            var format = vImage_CGImageFormat(
                bitsPerComponent: UInt32(MemoryLayout<ComponentType>.stride * 8),
                bitsPerPixel: UInt32(MemoryLayout<ComponentType>.stride * samplesPerPixel * 8),
                colorSpace: nil, // defaults to sRGB
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                version: UInt32(0),
                decode: nil,
                renderingIntent: .defaultIntent)

            var error: vImage_Error = 0
            thumbnailCGImage = vImageCreateCGImageFromBuffer(&imageBuffer,
                                                             &format,
                                                             nil, nil,
                                                             vImage_Flags(kvImagePrintDiagnosticsToConsole),
                                                             &error)!.takeRetainedValue()
        }

        #if os(iOS)
            objc_sync_exit(glContext)
            if oldGLContext != nil {
                EAGLContext.setCurrentContext(oldGLContext)
            }
        #elseif os(OSX)

            CGLUnlockContext(glContext)
            if oldGLContext != nil {
                CGLSetCurrentContext(oldGLContext)
            }
        #endif
        // Must unbind or SceneKit will not display correctly.
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        return thumbnailCGImage
    }
}


func checkGLErrors() {
    var glError: GLenum
    var hadError = false
    repeat {
        glError = glGetError()
        if glError != 0 {
            Swift.print(String(format: "OpenGL error %#x", glError))
            hadError = true
        }
    } while glError != 0
    assert(!hadError)
}

