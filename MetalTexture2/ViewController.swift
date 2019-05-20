//
//  ViewController.swift
//  MetalTexture2
//
//  Created by Mark Lim Pak Mun on 19/04/2019.
//  Copyright © 2019 Incremental Innovation. All rights reserved.
//

import Cocoa
import SceneKit
import MetalKit

class ViewController: NSViewController, SCNSceneRendererDelegate {
    
    var scnView: SCNView {
        return self.view as! SCNView
    }
    
    var device: MTLDevice!
    var outputTexture: MTLTexture!

    override func viewDidLoad() {
        super.viewDidLoad()
        device = MTLCreateSystemDefaultDevice()
        outputTexture = generateTexture(device: device)

        scnView.scene = buildScene()
        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        scnView.delegate = self
        scnView.backgroundColor = NSColor.lightGray
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    // use a compute function to create a MTLTexture
    func generateTexture(device: MTLDevice) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: 256,
                                                                  height: 256,
                                                                  mipmapped: false)
        descriptor.textureType = .type2D
        descriptor.usage = [.shaderRead, .shaderWrite]
        let outputTexture = device.makeTexture(descriptor: descriptor)

        let commandQueue = device.makeCommandQueue()
        let defaultLibrary = device.newDefaultLibrary()!
        
        let kernelFunction = defaultLibrary.makeFunction(name: "kernel_function")!
        var computePipelineState: MTLComputePipelineState!
        do {
            computePipelineState = try! device.makeComputePipelineState(function: kernelFunction)
        }
        let commandBuffer = commandQueue.makeCommandBuffer()
        commandBuffer.addCompletedHandler {
            (commandBuffer) in
            //print("texture is ready")
        }
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setTexture(outputTexture,
                                  at: 0)
        let threadgroupSize = MTLSizeMake(16, 16, 1)
        var threadgroupCount = MTLSizeMake(1, 1, 1)
        threadgroupCount.width  = (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width
        threadgroupCount.height = (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height
        computeEncoder.dispatchThreadgroups(threadgroupCount,
                                            threadsPerThreadgroup: threadgroupSize)
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return outputTexture
    }

    func buildScene() -> SCNScene {

        let geometry = SCNPlane(width: 10, height: 10)
        let geometryNode = SCNNode(geometry: geometry)

        let program = SCNProgram()
        program.vertexFunctionName = "vertex_function"
        program.fragmentFunctionName = "fragment_function"

        let imageProperty = SCNMaterialProperty(contents: outputTexture)
        geometryNode.geometry?.firstMaterial?.isDoubleSided = true
        geometryNode.geometry?.firstMaterial?.program = program
        geometryNode.geometry?.firstMaterial?.setValue(imageProperty,
                                                       forKey: "diffuseTexture")
        geometryNode.geometry?.firstMaterial?.lightingModel = .constant
        let scene = SCNScene()

        scene.rootNode.addChildNode(geometryNode)
        return scene
    }
    
}
