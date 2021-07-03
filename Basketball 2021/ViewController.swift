//
//  ViewController.swift
//  Basketball 2021
//
//  Created by Evgeniy Goncharov on 29.06.2021.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var scoreLabel: UILabel!
    
    // MARK: Private Properties
    var score: Int = 0 {
        didSet
        {
            scoreLabel.text = "СЧЕТ: \(self.score)"
        }
    }
    
    let configuration  = ARWorldTrackingConfiguration()
    
    var isHoopAdded = false {
        didSet {
            configuration.planeDetection = []
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set debug options
        sceneView.debugOptions = [.showFeaturePoints]
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Add Contact Delegate for world
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Detect vertical plane
        configuration.planeDetection = [.vertical, .horizontal]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    
    // MARK: Private Methods
    private func getBall() -> SCNNode? {
        
        // Get curret frame
        guard let frame = sceneView.session.currentFrame else { return nil }
        
        // Get camera transform
        let cameraTransform = frame.camera.transform
        let matrixCameraTransform = SCNMatrix4(cameraTransform)
        
        // Ball geometry
        let ball = SCNSphere(radius: 0.125)
        ball.firstMaterial?.diffuse.contents = UIImage(named: "basketball")
        
        // Ball node
        let ballNode = SCNNode(geometry: ball)
        
        // Add physics body
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
        
        // Calculate force for pushing the ball
        let power = Float(10)
        let x = -matrixCameraTransform.m31 * power
        let y = -matrixCameraTransform.m32 * power
        let z = -matrixCameraTransform.m33 * power
        let forceDirection = SCNVector3(x, y, z)
        
        // Apply force
        ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)
        
        // Add 
        ballNode.physicsBody?.categoryBitMask = 3
        ballNode.physicsBody?.collisionBitMask = 1 | 2
        //ballNode.physicsBody?.contactTestBitMask = 1 | 2
        
        // Assing camera position to ball
        ballNode.simdTransform = frame.camera.transform
        
        return ballNode
    }
    
    
    
    private func getHoopNode() -> SCNNode {
        let scene = SCNScene(named: "Hoop.scn", inDirectory: "art.scnassets")!
        let hoopNode = scene.rootNode.clone()
        
        
        // Add physics Score places
        hoopNode.enumerateChildNodes { (node, _) in
            if node.name == "scoreFirst" {
                node.opacity = 0
                node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                node.physicsBody?.categoryBitMask = 1
                node.physicsBody?.collisionBitMask = 0
                
            } else if node.name == "scoreSecond" {
                node.opacity = 0
                node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
                node.physicsBody?.categoryBitMask = 2
                node.physicsBody?.collisionBitMask = 0
                
            } else {
                // Add physics all places
                node.physicsBody = SCNPhysicsBody(
                    type: .static,
                    shape: SCNPhysicsShape(
                        node: node,
                        options:[SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
                    )
                )
            }
            
        }
        
        hoopNode.eulerAngles.x -= .pi / 2
        return hoopNode
    }
    
    private func getPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        let extent = anchor.extent
        let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        // Create 50% transparent plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.5
        
        // Rotate plane node
        planeNode.eulerAngles.x -= .pi / 2
        
        return planeNode
    }
    
    private func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            return
        }
        
        // Chenge plane node center
        planeNode.simdPosition = anchor.center
        
        // Change plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Add the hoop to the center of detected vertial plane
        node.addChildNode(getPlaneNode(for: planeAnchor))
        print(#line, #function, "Vertical plane found! \(planeAnchor)")
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Update plane node
        updatePlaneNode(node, for: planeAnchor)
    }
    
    
    
    
    // MARK: SCNPhysicsContactDelegate
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        if (contact.nodeA.physicsBody?.categoryBitMask == 1 &&
                contact.nodeB.physicsBody?.categoryBitMask == 3 &&
                contact.nodeB.name != "ballTouchedTop") {
            
            contact.nodeB.name = "ballTouchedTop"
            print(#line, #function, "Collision detected with scoreFirs!")
            
        } else if (contact.nodeA.physicsBody?.categoryBitMask == 2 &&
                    contact.nodeB.physicsBody?.categoryBitMask == 3 &&
                    contact.nodeB.name == "ballTouchedTop") {
            
            contact.nodeB.name = "ball"
            print(#line, #function, "Wow!!! You done it!" )
        }
        
    }
    
    
    
    // MARK: - IBActions
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        
        if isHoopAdded {
            // Get basketball node
            guard  let ballNode = getBall() else { return }
            
            // Add basketball to the camera position
            sceneView.scene.rootNode.addChildNode(ballNode)
            
        } else {
            let location = sender.location(in: sceneView)
            
            guard let result = sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
                return
            }
            
            guard let anchor = result.anchor as? ARPlaneAnchor, anchor.alignment == .vertical else {
                return
            }
            
            // Get hoop node and set its coodinates to the point of user touch
            let hoopeNode = getHoopNode()
            hoopeNode.simdTransform = result.worldTransform
            
            //Rotate hope by 90
            hoopeNode.eulerAngles.x -= .pi / 2
            
            isHoopAdded = true
            sceneView.scene.rootNode.addChildNode(hoopeNode)
        }
    }
}
