import UIKit

class ImageView: UIImageView {

    var pt = CGPoint()
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            pt = touch.location(in: self)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            var npt = touch.location(in: self)
            npt.x -= pt.x
            npt.y -= pt.y
            vc.focusMovement(npt)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pt.x = 0
        pt.y = 0
        vc.focusMovement(pt)
    }
}
