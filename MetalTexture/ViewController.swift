//
//  ViewController.swift
//  MetalTexture2
//
//  Created by mark lim pak mun on 20/04/2019.
//  Copyright © 2019 mark lim pak mun. All rights reserved.
//

import Cocoa
import SceneKit

class ViewController: NSViewController, SCNSceneRendererDelegate  {
    var sceneView: SCNView {
        return self.view as! SCNView
    }
    var mtlDevice: MTLDevice!
    var commandQueue: MTLCommandQueue!

    var renderPipelineState: MTLRenderPipelineState!
    var offscreenTexture: MTLTexture!
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let textureSizeX = 256
    let textureSizeY = 256
    let bytesPerPixel = Int(4)
    let bitsPerComponent = Int(8)
    let bitsPerPixel: Int = 32

    var offScreenRenderer: SCNRenderer!
    var offScreenScene: SCNScene!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupForMetalRenderer()
        setupTexture()

        offScreenScene = SCNScene()
        offScreenRenderer.scene = offScreenScene
        offScreenRenderer.delegate = self

        // Rendering to a MTLTexture, so the viewport is the size of this texture
        let viewport = CGRect(x: 0, y: 0,
                              width: CGFloat(textureSizeX), height: CGFloat(textureSizeY))

        // Write to offscreenTexture, clear the texture before rendering
        // using green, store the result.
        // Metal colorAttachments is the equivalent of OpenGL framebuffer objects.
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 1.0, 0.0, 1.0); //green
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        let commandBuffer = commandQueue.makeCommandBuffer()
        offScreenRenderer.render(atTime: 0,
                                 viewport: viewport,
                                 commandBuffer: commandBuffer,
                                 passDescriptor: renderPassDescriptor)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func setupForMetalRenderer() {
        if self.sceneView.renderingAPI == SCNRenderingAPI.metal {
            mtlDevice = sceneView.device
            commandQueue = mtlDevice.makeCommandQueue()
            offScreenRenderer = SCNRenderer(device: mtlDevice, options: nil)
            guard let library = mtlDevice.newDefaultLibrary()
            else {
                fatalError("Default library?")
            }
            let vertexFunction = library.makeFunction(name: "vertex_function")
            let fragmentFunction = library.makeFunction(name: "fragment_function")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm    // SceneKit wants this value.
            pipelineDescriptor.depthAttachmentPixelFormat = .invalid
           do {
                renderPipelineState = try mtlDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
            }
            catch {
                fatalError("Could not create render pipeline state object: \(error)")
            }
        }
        else {
            fatalError("Sorry, Metal only")
        }
    }

    // Since we are using Metal, the scene renderer's currentRenderCommandEncoder
    // and commandQueue properties are available.
    // However, SceneKit uses the currentRenderCommandEncoder for its own purposes.
    // Using it here does not work.
    // Other properties of the scene renderer (an instance of SCNSceneRenderer)
    // can also be accessed.
    // Bear in mind that we will be rendering to a texture.
    func renderer(_ renderer: SCNSceneRenderer,
                  willRenderScene scene: SCNScene,
                  atTime time: TimeInterval) {
        // Do we instantiate a new instance of MTLCommandBuffer & MTLRenderCommandEncoder?
        // An instance of MTLRenderPipelineState is required if a pair of vertex-fragment functions are used.
        // An instance of MTLComputePipelineState & MTLComputeCommandEncoder are required
        // if a kernel function is used.
        let commandBuffer = renderer.commandQueue?.makeCommandBuffer()
        // First and foremost we need an instance of MTLRenderPassDescriptor.
        // We are duplicating what was passed by the SCNRenderer call
        //      renderAtTime:viewport:commandBuffer:passDescriptor:
        // Alternatively, declare renderPassDescriptor as a property of the view controller class.
        // since we couldn't access the MTLRenderPassDescriptor object used by the call.
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 1, 0, 1)
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        // We have to instantiate our own MTLRenderCommandEncoder object
        // since we cannot use the provided SCNSceneRenderer property "currentRenderCommandEncoder".
        let renderCommandEncoder = commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

        renderCommandEncoder.setRenderPipelineState(renderPipelineState)
        var resolution = float2(Float(textureSizeX), Float(textureSizeY))
        renderCommandEncoder.setFragmentBytes(&resolution,
                                              length: MemoryLayout<float2>.stride,
                                              at: 0)
        renderCommandEncoder.drawPrimitives(type: .triangleStrip,
                                            vertexStart: 0,
                                            vertexCount: 4)
        renderCommandEncoder.endEncoding()
        commandBuffer!.commit()
    }

    // Only returning the MTKTexture object is necessary.
    // This texture object will be used as an attachment that acts as a rendering target.
    func setupTexture() {
        // Just fill it with a color although it's unnecessary.
        var rawData0 = [UInt8](repeating: 0,
                               count: Int(textureSizeX) * Int(textureSizeY) * 4)

        let bytesPerRow = 4 * Int(textureSizeX)
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        let context = CGContext(data: &rawData0,
                                width: Int(textureSizeX), height: Int(textureSizeY),
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: rgbColorSpace,
                                bitmapInfo: bitmapInfo)!
        context.setFillColor(NSColor.purple.cgColor)
        context.fill(CGRect(x: 0, y: 0,
                            width: CGFloat(textureSizeX), height: CGFloat(textureSizeY)))

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm,
                                                                         width: Int(textureSizeX),
                                                                         height: Int(textureSizeY),
                                                                         mipmapped: false)

        textureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)

        let textureA = mtlDevice.makeTexture(descriptor: textureDescriptor)

        let region = MTLRegionMake2D(0, 0,
                                     Int(textureSizeX), Int(textureSizeY))
        textureA.replace(region: region,
                         mipmapLevel: 0,
                         withBytes: &rawData0,
                         bytesPerRow: Int(bytesPerRow))
        offscreenTexture = textureA
    }

    // Assign the generated MTLTexture object to the "contents" property of
    // the plane's diffuse SCNMaterialProperty.
    override func viewWillAppear() {
        let plane = SCNPlane(width: 1, height: 1)
        let planeNode = SCNNode(geometry: plane)
        plane.firstMaterial?.diffuse.contents = offscreenTexture
        plane.firstMaterial?.isDoubleSided = true
        let scene = SCNScene()
        scene.rootNode.addChildNode(planeNode)
        sceneView.scene = scene
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = true
        scene.background.contents = NSColor.gray
    }
}

