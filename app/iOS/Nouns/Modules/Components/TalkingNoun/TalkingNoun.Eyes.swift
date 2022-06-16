// Copyright (C) 2022 Nouns Collective
//
// Originally authored by Ziad Tamim
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import SpriteKit
import Services

extension TalkingNoun {
  
  final class Eyes: SKSpriteNode {
    
    /// Various eyes states.
    enum State: String {
      case idle
      case active
    }
    
    private class var nounComposer: NounComposer {
      AppCore.shared.nounComposer
    }
    
    var state: State = .idle
    let eyesNode = SKSpriteNode()
    
    let blinkTextures: [SKTexture]
    let shiftTextures: [SKTexture]

    let blinkOnly: Bool

    init(seed: Seed, frameSize: CGSize, blinkOnly: Bool = true) {
      guard let blinkTextures = Self.nounComposer.glasses[seed.glasses].textures["eyes-blink"] else {
        fatalError("Couldn't load eye blink textures.")
      }
      
      self.blinkTextures = blinkTextures.map {
        let texture = SKTexture(imageNamed: $0)
        texture.filteringMode = .nearest
        return texture
      }
      
      guard let shiftTextures = Self.nounComposer.glasses[seed.glasses].textures["eyes-shift"] else {
        fatalError("Couldn't load eye shift textures.")
      }
      
      self.shiftTextures = shiftTextures.map {
        let texture = SKTexture(imageNamed: $0)
        texture.filteringMode = .nearest
        return texture
      }

      self.blinkOnly = blinkOnly
      
      guard let glassesFrame = Self.nounComposer.glasses[seed.glasses].textures["glasses-frame"]?.first else {
        fatalError("Couldn't load eye shift textures.")
      }
      
      let glassesFrameTexture = SKTexture(imageNamed: glassesFrame)
      glassesFrameTexture.filteringMode = .nearest
      super.init(texture: glassesFrameTexture, color: SKColor.clear, size: frameSize)

      eyesNode.texture = self.blinkTextures.first
      eyesNode.size = frameSize
      addChild(eyesNode)
      
      animateEyes()
    }
    
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func animateEyes() {
      guard action(forKey: State.idle.rawValue) == nil else {
        return
      }
      
      let pause = SKAction.wait(forDuration: 10, withRange: 4)
      let shortPause = SKAction.wait(forDuration: 3, withRange: 1)
      let blink = SKAction.run {
        self.eyesNode.run(SKAction.animate(with: self.blinkTextures, timePerFrame: 0.05))
      }
      let goofyEye = SKAction.customAction(withDuration: 0.0, actionBlock: randomEye)
      let sequence = SKAction.sequence(blinkOnly ? [pause, blink] : [shortPause, blink, shortPause, goofyEye])
      let repeatForever = SKAction.repeatForever(sequence)
      
      run(repeatForever, withKey: State.idle.rawValue)
    }
    
    private func randomEye(_ node: SKNode, _ elapsedTime: CGFloat) {
      eyesNode.texture = state == .active ? shiftTextures.first : shiftTextures.randomElement()
    }
  }
}