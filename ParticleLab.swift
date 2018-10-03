//
//  ParticleLab.swift
//  MetalParticles
//
//  Created by Simon Gladman on 04/04/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import UIKit

// Workaround to allow this project to build on Simulators
protocol ParticleLabService {
    var isPaused: Bool { get set }
}

#if arch(i386) || arch(x86_64)

class MTKView: UIView, ParticleLabService {
    var isPaused: Bool = true

}

#else

import Metal
import MetalPerformanceShaders
import MetalKit

#endif

class ParticleLab: MTKView {

    let imageWidth: UInt
    let imageHeight: UInt
    
    private var imageWidthFloatBuffer: MTLBuffer!
    private var imageHeightFloatBuffer: MTLBuffer!

    private var kernelFunction: MTLFunction!
    private var pipelineState: MTLComputePipelineState!
    private var defaultLibrary: MTLLibrary! = nil
    private var commandQueue: MTLCommandQueue! = nil
    
    private var threadsPerThreadgroup: MTLSize!
    private var threadgroupsPerGrid: MTLSize!

    private var particlePositions: [CGPoint]
    
    let particleCount: Int

    private var gravityWellParticle = Particle(A: Vector4(x: 0, y: 0, z: 0, w: 0),
        B: Vector4(x: 0, y: 0, z: 0, w: 0),
        C: Vector4(x: 0, y: 0, z: 0, w: 0),
        D: Vector4(x: 0, y: 0, z: 0, w: 0))
    
    private var frameStartTime: CFAbsoluteTime!
    private var frameNumber = 0

    let particleSize = MemoryLayout<Particle>.size

    var particleBehaviorType: BehaviorType = .none

    weak var particleLabDelegate: ParticleLabDelegate?
    
    var particleColor = ParticleColor(R: 0.066666, G: 0.8, B: 0.6, A: 1)
    var dragFactor: Float = 0.97
    var respawnOutOfBoundsParticles = true
    
    var clearOnStep = false
    var particlesShouldMove = true

    // MARK: Metal specific properties that won't run on Simulator
    #if arch(i386) || arch(x86_64)
    #else
    
    private var particlesMemory:UnsafeMutableRawPointer? = nil
    private var particlesVoidPtr: OpaquePointer!
    private var particlesParticlePtr: UnsafeMutablePointer<Particle>!
    private var particlesParticleBufferPtr: UnsafeMutableBufferPointer<Particle>!

    let alignment:Int = 0x4000
    let particlesMemoryByteSize:Int

    let bytesPerRow: UInt
    let region: MTLRegion
    let blankBitmapRawData : [UInt8]
    
    lazy var blur: MPSImageGaussianBlur = { [unowned self] in
        return MPSImageGaussianBlur(device: self.device!, sigma: 3)
    }()
    
    lazy var erode: MPSImageAreaMin = { [unowned self] in
        return MPSImageAreaMin(device: self.device!, kernelWidth: 5, kernelHeight: 5)
    }()
    
    #endif
    
    init(width: UInt, height: UInt, numParticles: ParticleCount, hiDPI: Bool) {
        imageWidth = width
        imageHeight = height
        
        particleCount = numParticles.rawValue
        particlePositions = CGRect(x: 0,
                                   y: 0,
                                   width: Double(width),
                                   height: Double(width)).generatePointsInside(count: numParticles.rawValue)


        #if arch(i386) || arch(x86_64)
        
        super.init(frame: .zero)
        
        #else

        bytesPerRow = 4 * imageWidth
        region = MTLRegionMake2D(0, 0, Int(imageWidth), Int(imageHeight))
        blankBitmapRawData = [UInt8](repeating: 0, count: Int(imageWidth * imageHeight * 4))
        particlesMemoryByteSize = particleCount * MemoryLayout<Particle>.size
    
        let frameWidth = hiDPI ? width / UInt(UIScreen.main.scale) : width
        let frameHeight = hiDPI ? height / UInt(UIScreen.main.scale) : height
        
        super.init(frame: CGRect(x: 0, y: 0, width: Int(frameWidth), height: Int(frameHeight)),
                   device:  MTLCreateSystemDefaultDevice())
        
        framebufferOnly = false
        drawableSize = CGSize(width: CGFloat(imageWidth), height: CGFloat(imageHeight));
        
        setUpParticles()
        setUpMetal()
        
        isMultipleTouchEnabled = true
        
        #endif
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    deinit {
        #if arch(i386) || arch(x86_64)
        #else
        free(particlesMemory)
        #endif
    }

    fileprivate func setUpParticles() {
        #if arch(i386) || arch(x86_64)
        #else
        posix_memalign(&particlesMemory, alignment, particlesMemoryByteSize)
        
        particlesVoidPtr = OpaquePointer(particlesMemory)
        particlesParticlePtr = UnsafeMutablePointer<Particle>(particlesVoidPtr)
        particlesParticleBufferPtr = UnsafeMutableBufferPointer(start: particlesParticlePtr, count: particleCount)
        
        resetParticles(regeneratePositions: true)
        #endif
    }

    func resetGravityWells() {
        setGravityWellProperties(gravityWell: .one, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
        setGravityWellProperties(gravityWell: .two, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
        setGravityWellProperties(gravityWell: .three, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
        setGravityWellProperties(gravityWell: .four, normalisedPositionX: 0.5, normalisedPositionY: 0.5, mass: 0, spin: 0)
    }
    
    private func generatePositions() {
        particlePositions = particleLabDelegate?.positionsForReset(count: particleCount) ?? []
    }
    
    func resetParticles(regeneratePositions: Bool = true) {
        #if arch(i386) || arch(x86_64)
        #else

        func rand() -> Float32 {
            return Float(drand48() - 0.5) * 0.005
        }
        
        if regeneratePositions {
            generatePositions()
        }
        
        let imageWidthDouble = Double(imageWidth)
        let imageHeightDouble = Double(imageHeight)
        
        for index in particlesParticleBufferPtr.startIndex ..< particlesParticleBufferPtr.endIndex {
            
            guard index < particlePositions.count else {
                return
            }
            
            let positionAX = Float(particlePositions[index].x) + Float(imageWidthDouble / 8)
            let positionAY = Float(1 - particlePositions[index].y) + Float(imageHeightDouble / 2)

            let positionBX = Float(particlePositions[index].x) + Float(imageWidthDouble / 8) + 1
            let positionBY = Float(1 - particlePositions[index].y) + Float(imageHeightDouble / 2) + 1

            let positionCX = Float(particlePositions[index].x) + Float(imageWidthDouble / 8) - 1
            let positionCY = Float(1 - particlePositions[index].y) + Float(imageHeightDouble / 2) - 1

            let positionDX = Float(particlePositions[index].x) + Float(imageWidthDouble / 8) + 1
            let positionDY = Float(1 - particlePositions[index].y) + Float(imageHeightDouble / 2) - 1

            let particle = Particle(A: Vector4(x: positionAX, y: positionAY, z: rand(), w: rand()),
                                    B: Vector4(x: positionBX, y: positionBY, z: rand(), w: rand()),
                                    C: Vector4(x: positionCX, y: positionCY, z: rand(), w: rand()),
                                    D: Vector4(x: positionDX, y: positionDY, z: rand(), w: rand()))
            
            particlesParticleBufferPtr[index] = particle
        }

        #endif
    }
    
    fileprivate func setUpMetal() {
        #if arch(i386) || arch(x86_64)
        #else

        
        device = MTLCreateSystemDefaultDevice()
        
        guard let device = device else {
            particleLabDelegate?.particleLabMetalUnavailable()
            return
        }
        
        defaultLibrary = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
        
        kernelFunction = defaultLibrary.makeFunction(name: "particleRendererShader")
        
        do {
            try pipelineState = device.makeComputePipelineState(function: kernelFunction!)
        } catch {
            fatalError("newComputePipelineStateWithFunction failed ")
        }

        let threadExecutionWidth = pipelineState.threadExecutionWidth
        
        threadsPerThreadgroup = MTLSize(width:threadExecutionWidth,height:1,depth:1)
        threadgroupsPerGrid = MTLSize(width:particleCount / threadExecutionWidth, height:1, depth:1)
        
        frameStartTime = CFAbsoluteTimeGetCurrent()

        var imageWidthFloat = Float(imageWidth)
        var imageHeightFloat = Float(imageHeight)
        
        imageWidthFloatBuffer =  device.makeBuffer(bytes: &imageWidthFloat, length: MemoryLayout<Float>.size, options: MTLResourceOptions())
        
        imageHeightFloatBuffer = device.makeBuffer(bytes: &imageHeightFloat, length: MemoryLayout<Float>.size, options: MTLResourceOptions())
        #endif
    }
    
    override func draw(_ dirtyRect: CGRect) {
        #if arch(i386) || arch(x86_64)
        #else


        guard let device = device else {
            particleLabDelegate?.particleLabMetalUnavailable()
            return
        }
        
        frameNumber += 1
        
        if frameNumber == 100 {
//            let frametime = (CFAbsoluteTimeGetCurrent() - frameStartTime) / 100
//            print("Frametime: \(frametime)")
           
            frameStartTime = CFAbsoluteTimeGetCurrent()
            frameNumber = 0
        }
        
        
        guard
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder() else
        {
            return
        }
        
        commandEncoder.setComputePipelineState(pipelineState)
        
        let particlesBufferNoCopy = device.makeBuffer(bytesNoCopy: particlesMemory!, length: Int(particlesMemoryByteSize),
            options: MTLResourceOptions(), deallocator: nil)
        
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, index: 0)
        commandEncoder.setBuffer(particlesBufferNoCopy, offset: 0, index: 1)
        

        let inGravityWell = device.makeBuffer(bytes: &gravityWellParticle, length: particleSize, options: MTLResourceOptions())
        commandEncoder.setBuffer(inGravityWell, offset: 0, index: 2)
        
        let colorBuffer = device.makeBuffer(bytes: &particleColor, length: MemoryLayout<ParticleColor>.size, options: MTLResourceOptions())
        commandEncoder.setBuffer(colorBuffer, offset: 0, index: 3)
        
        commandEncoder.setBuffer(imageWidthFloatBuffer, offset: 0, index: 4)
        commandEncoder.setBuffer(imageHeightFloatBuffer, offset: 0, index: 5)
        
        let dragFactorBuffer = device.makeBuffer(bytes: &dragFactor, length: MemoryLayout<Float>.size, options: MTLResourceOptions())
        commandEncoder.setBuffer(dragFactorBuffer, offset: 0, index: 6)
        
        let respawnOutOfBoundsParticlesBuffer = device.makeBuffer(bytes: &respawnOutOfBoundsParticles, length: MemoryLayout<Bool>.size, options: MTLResourceOptions())
        commandEncoder.setBuffer(respawnOutOfBoundsParticlesBuffer, offset: 0, index: 7)

        var type: Int = particleBehaviorType.rawValue
        let behaviorTypeBuffer = device.makeBuffer(bytes: &type, length: MemoryLayout<Int>.size, options: MTLResourceOptions())
        commandEncoder.setBuffer(behaviorTypeBuffer, offset: 0, index: 8)
        
        let shouldMoveBuffer = device.makeBuffer(bytes: &particlesShouldMove, length: MemoryLayout<Bool>.size, options: MTLResourceOptions())
        commandEncoder.setBuffer(shouldMoveBuffer, offset: 0, index: 9)
        
        guard let drawable = currentDrawable else {
            commandEncoder.endEncoding()
            print("metalLayer.nextDrawable() returned nil")
            return
        }

        if clearOnStep {
            drawable.texture.replace(region: self.region,
                mipmapLevel: 0,
                withBytes: blankBitmapRawData,
                bytesPerRow: Int(bytesPerRow))
        }
        
            
        commandEncoder.setTexture(drawable.texture, index: 0)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        commandEncoder.endEncoding()
        
        if !clearOnStep {
            let inPlaceTexture = UnsafeMutablePointer<MTLTexture>.allocate(capacity: 1)
            inPlaceTexture.initialize(to: drawable.texture)
            
            blur.encode(commandBuffer: commandBuffer,
                inPlaceTexture: inPlaceTexture,
                fallbackCopyAllocator: nil)
            
            erode.encode(commandBuffer: commandBuffer,
                inPlaceTexture: inPlaceTexture,
                fallbackCopyAllocator: nil)
        }
        
        commandBuffer.commit()
        
        drawable.present()

        particleLabDelegate?.particleLabDidUpdate("")
        #endif
    }
    
    private func normalizePosition(x: Float, y: Float) -> (x: Float, y: Float) {
        let imageWidthFloat = Float(imageWidth)
        let imageHeightFloat = Float(imageHeight)
        return (x: x / imageWidthFloat, y: y / imageHeightFloat)
    }
    
    final func getGravityWellNormalisedPosition(gravityWell: GravityWell) -> (x: Float, y: Float) {
        switch gravityWell {
        case .one:
            return normalizePosition(x: gravityWellParticle.A.x, y: gravityWellParticle.A.y)

        case .two:
            return normalizePosition(x: gravityWellParticle.B.x, y: gravityWellParticle.B.y)

        case .three:
            return normalizePosition(x: gravityWellParticle.C.x, y: gravityWellParticle.C.y)

        case .four:
            return normalizePosition(x: gravityWellParticle.D.x, y: gravityWellParticle.D.y)
        }
    }
    
    final func setGravityWellProperties(gravityWellIndex: Int, normalisedPositionX: Float, normalisedPositionY: Float, mass: Float, spin: Float) {
        switch gravityWellIndex {
        case 1:
            setGravityWellProperties(gravityWell: .two, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)
            
        case 2:
            setGravityWellProperties(gravityWell: .three, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)

        case 3:
            setGravityWellProperties(gravityWell: .four, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)
            
        default:
            setGravityWellProperties(gravityWell: .one, normalisedPositionX: normalisedPositionX, normalisedPositionY: normalisedPositionY, mass: mass, spin: spin)
        }
    }
    
    final func setGravityWellProperties(gravityWell: GravityWell, normalisedPositionX: Float, normalisedPositionY: Float, mass: Float, spin: Float) {
        let imageWidthFloat = Float(imageWidth)
        let imageHeightFloat = Float(imageHeight)
        
        switch gravityWell {
        case .one:
            gravityWellParticle.A.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.A.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.A.z = mass
            gravityWellParticle.A.w = spin
            
        case .two:
            gravityWellParticle.B.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.B.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.B.z = mass
            gravityWellParticle.B.w = spin
            
        case .three:
            gravityWellParticle.C.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.C.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.C.z = mass
            gravityWellParticle.C.w = spin
            
        case .four:
            gravityWellParticle.D.x = imageWidthFloat * normalisedPositionX
            gravityWellParticle.D.y = imageHeightFloat * normalisedPositionY
            gravityWellParticle.D.z = mass
            gravityWellParticle.D.w = spin
        }
    }
}

protocol ParticleLabDelegate: NSObjectProtocol {
    func particleLabDidUpdate(_ status: String)
    func particleLabMetalUnavailable()
    func positionsForReset(count: Int) -> [CGPoint]
}

enum GravityWell {
    case one
    case two
    case three
    case four
}

//  Since each Particle instance defines four particles, the visible particle count
//  in the API is four times the number we need to create.
enum ParticleCount: Int {
    case small = 512
    case medium = 2_048
    case large = 8_192
    case sixteenthMillion = 32_768
    case qtrMillion = 65_536
    case halfMillion = 131_072
    case oneMillion =  262_144
    case twoMillion =  524_288
    case fourMillion = 1_048_576
    case eightMillion = 2_097_152
    case sixteenMillion = 4_194_304
}

//  Paticles are split into three classes. The supplied particle color defines one
//  third of the rendererd particles, the other two thirds use the supplied particle
//  color components but shifted to BRG and GBR
struct ParticleColor {
    var R: Float32 = 0
    var G: Float32 = 0
    var B: Float32 = 0
    var A: Float32 = 1
}

struct Particle { // Matrix4x4
    var A: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var B: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var C: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
    var D: Vector4 = Vector4(x: 0, y: 0, z: 0, w: 0)
}

// Regular particles use x and y for position and z and w for velocity
// gravity wells use x and y for position and z for mass and w for spin
struct Vector4 {
    var x: Float32 = 0
    var y: Float32 = 0
    var z: Float32 = 0
    var w: Float32 = 0
}

enum BehaviorType: Int {
    case none = 0
    case gravityWell = 1
    case explosion = 2
    case follow = 3
}

#if arch(i386) || arch(x86_64)
#else

extension ParticleLab: ParticleLabService {}

#endif
