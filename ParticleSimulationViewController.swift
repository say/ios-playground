//
//  ViewController.swift
//  MetalParticles
//
//  Created by Simon Gladman on 17/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Reengineered based on technique from http://memkite.com/blog/2014/12/30/example-of-sharing-memory-between-gpu-and-cpu-with-swift-and-metal-for-ios8/
//
//  Thanks to https://twitter.com/atveit for tips - espewcially using float4x4!!!
//  Thanks to https://twitter.com/warrenm for examples, especially implemnting matrix 4x4 in Swift
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


enum DemoModes: String
{
    case text = "Render Text"
    case multiTouch = "Multiple Touch"
    case followTouch = "Follow Touch"
    case explosion = "Explosion"
    case random = "Random Motion"
}

class ParticleSimulationViewController: UIViewController, ParticleLabDelegate {

    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    let menuButton = UIButton()
    
    var particleLab: ParticleLab!
    
    var gravityWellAngle: Float = 0
    
    var demoMode = DemoModes.multiTouch
    
    var currentTouches = Set<UITouch>()
    
    var demoText: String = "SAY"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        
        let numParticles = ParticleCount.halfMillion
        
        let width = UInt(self.view.frame.width * UIScreen.main.scale)
        let height = UInt(self.view.frame.height * UIScreen.main.scale)
        
        particleLab = ParticleLab(width: width, height: height, numParticles: numParticles, hiDPI: true)
        particleLab.frame = view.bounds
        
        particleLab.particleLabDelegate = self
        particleLab.dragFactor = 0.5
        particleLab.clearOnStep = true
        particleLab.respawnOutOfBoundsParticles = false
        
        view.addSubview(particleLab)
        
        menuButton.layer.borderColor = UIColor.lightGray.cgColor
        menuButton.layer.borderWidth = 1
        menuButton.layer.cornerRadius = 5
        menuButton.layer.backgroundColor = UIColor.darkGray.cgColor
        menuButton.showsTouchWhenHighlighted = true
        menuButton.imageView?.contentMode = UIView.ContentMode.scaleAspectFit
        menuButton.setImage(UIImage(named: "settings"), for: UIControl.State())
        menuButton.addTarget(self, action: #selector(displayCallout), for: .touchDown)
        
        view.addSubview(menuButton)
        
    }
    
    func positionsForReset(count: Int) -> [CGPoint] {
        
        var positions: [CGPoint] = []
        
        switch demoMode {
        case .text:
            let string = NSAttributedString(string: demoText, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 350, weight: UIFont.Weight(rawValue: 500))])
            positions = string.path?.boundingBox.generateRandomPointsInside(path: string.path!, count: count) ?? []
            
        case .followTouch:
            let circle = UIBezierPath.init(arcCenter: CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2),
                                           radius: view.bounds.height / 2,
                                           startAngle: 0,
                                           endAngle: .pi * 2,
                                           clockwise: true)
            positions = circle.bounds.generateRandomPointsInside(path: circle.cgPath, count: count)
            
            
        default:
            positions = view.bounds.generatePointsInside(count: count)
        }
        
        
        return positions
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        menuButton.frame = CGRect(x: view.frame.width - 60,
                                  y: view.frame.height - 80,
                                  width: 30,
                                  height: 30)
    }
    
    func particleLabMetalUnavailable()
    {
        // handle metal unavailable here
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        currentTouches = currentTouches.union(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        currentTouches = currentTouches.subtracting(touches)
    }
    
    @objc func displayCallout()
    {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        
        let textAction = UIAlertAction(title: DemoModes.text.rawValue, style: UIAlertAction.Style.default, handler: calloutActionHandler)
        let cloudChamberAction = UIAlertAction(title: DemoModes.random.rawValue, style: UIAlertAction.Style.default, handler: calloutActionHandler)
        let orbitsAction = UIAlertAction(title: DemoModes.followTouch.rawValue, style: UIAlertAction.Style.default, handler: calloutActionHandler)
        let multiTouchAction = UIAlertAction(title: DemoModes.multiTouch.rawValue, style: UIAlertAction.Style.default, handler: calloutActionHandler)

        let finishedAction = UIAlertAction(title: "Leave Simulator", style: UIAlertAction.Style.destructive, handler: calloutActionHandler)
        
        alertController.addAction(textAction)
        alertController.addAction(cloudChamberAction)
        alertController.addAction(orbitsAction)
        alertController.addAction(multiTouchAction)

        alertController.addAction(finishedAction)
        
        particleLab.isPaused = true
        
        present(alertController, animated: true, completion: {self.particleLab.isPaused = false})
    }
    
    func calloutActionHandler(_ value: UIAlertAction!) -> Void
    {
        guard let title = value.title, let demoMode = DemoModes(rawValue: title) else {
            navigationController?.popViewController(animated: true)
            return
        }
        
        self.demoMode = demoMode

        switch demoMode
        {
        case .text:
            particleLab.particleBehaviorType = .none
            particleLab.dragFactor = 0.82
            particleLab.clearOnStep = true
            particleLab.particlesShouldMove = false
            
            particleLab.resetParticles()
            
        case .followTouch:
            particleLab.particleBehaviorType = .follow
            particleLab.dragFactor = 0.82
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.clearOnStep = true
            particleLab.particlesShouldMove = true
            particleLab.resetParticles()
            
        case .random:
            particleLab.dragFactor = 0.8
            particleLab.particleBehaviorType = .gravityWell
            particleLab.respawnOutOfBoundsParticles = false
            particleLab.clearOnStep = true
            particleLab.particlesShouldMove = true
            particleLab.resetParticles()
            
        case .multiTouch:
            particleLab.dragFactor = 0.95
            particleLab.respawnOutOfBoundsParticles = false
            particleLab.particleBehaviorType = .gravityWell
            particleLab.clearOnStep = true
            particleLab.particlesShouldMove = true
            particleLab.resetParticles()
            
        case .explosion:
            particleLab.dragFactor = 0.98
            particleLab.respawnOutOfBoundsParticles = true
            particleLab.particleBehaviorType = .explosion
            particleLab.clearOnStep = true
            particleLab.particlesShouldMove = true
            particleLab.resetParticles()
            
        }
    }
    
    func particleLabDidUpdate(_ status: String) {
        switch demoMode {
        case .followTouch:
            followTouchStep()
            
        case .random:
            particleLab.resetGravityWells()
            randomStep()
            
        case .text:
            particleLab.resetGravityWells()
            multiTouchStep()
            
        case .multiTouch:
            particleLab.resetGravityWells()
            multiTouchStep()
            
        case .explosion:
            followTouchStep()
        }
    }
    
    func randomStep() {
        gravityWellAngle = gravityWellAngle + 0.02
        
        particleLab.setGravityWellProperties(gravityWell: .one,
                                             normalisedPositionX: 0.5 + 0.1 * sin(gravityWellAngle + Float.pi * 0.5),
                                             normalisedPositionY: 0.5 + 0.1 * cos(gravityWellAngle + Float.pi * 0.5),
                                             mass: 11 * sin(gravityWellAngle / 1.9),
                                             spin: 23 * cos(gravityWellAngle / 2.1))
        
        particleLab.setGravityWellProperties(gravityWell: .four,
                                             normalisedPositionX: 0.5 + 0.1 * sin(gravityWellAngle + Float.pi * 1.5),
                                             normalisedPositionY: 0.5 + 0.1 * cos(gravityWellAngle + Float.pi * 1.5),
                                             mass: 11 * sin(gravityWellAngle / 1.9),
                                             spin: 23 * cos(gravityWellAngle / 2.1))
        
        particleLab.setGravityWellProperties(gravityWell: .two,
                                             normalisedPositionX: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * cos(gravityWellAngle / 1.3),
                                             normalisedPositionY: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * sin(gravityWellAngle / 1.3),
                                             mass: 26, spin: -19 * sin(gravityWellAngle * 1.5))
        
        particleLab.setGravityWellProperties(gravityWell: .three,
                                             normalisedPositionX: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * cos(gravityWellAngle / 1.3 + Float.pi),
                                             normalisedPositionY: 0.5 + (0.35 + sin(gravityWellAngle * 2.7)) * sin(gravityWellAngle / 1.3 + Float.pi),
                                             mass: 26, spin: -19 * sin(gravityWellAngle * 1.5))
        
    }
    
    func followTouchStep() {
        guard let touch = Array(currentTouches).first else {
            return
        }
        
        let touchMultiplier = touch.force == 0 && touch.maximumPossibleForce == 0
            ? 1
            : Float(touch.force / touch.maximumPossibleForce)
        
        particleLab.setGravityWellProperties(gravityWell: .one,
                                             normalisedPositionX: Float(touch.location(in: view).x / view.frame.width),
                                             normalisedPositionY: Float(touch.location(in: view).y / view.frame.height),
                                             mass: 200 * touchMultiplier,
                                             spin: 0)
    }
    
    func multiTouchStep() {
        let currentTouchesArray = Array(currentTouches)
        
        for (i, currentTouch) in currentTouchesArray.enumerated() where i < 4 {
            let touchMultiplier = currentTouch.force == 0 && currentTouch.maximumPossibleForce == 0
                ? 1
                : Float(currentTouch.force / currentTouch.maximumPossibleForce)
            
            particleLab.setGravityWellProperties(gravityWellIndex: i,
                                                 normalisedPositionX: Float(currentTouch.location(in: view).x / view.frame.width) ,
                                                 normalisedPositionY: Float(currentTouch.location(in: view).y / view.frame.height),
                                                 mass: 140 * touchMultiplier,
                                                 spin: 20 * touchMultiplier)
        }
    }
    
}
