import UIKit

class CTranslate: UIView {
    let viewSize:Float = 4  // -2 ... +2
    var scale:Float = 0
    var xc:CGFloat = 0
    var fastEdit = true
    var hasFocus = false

    func mapPoint(_ pt:CGPoint) -> float3 {
        var v = float3()
        v.x = Float(pt.x) * scale - viewSize/2 // centered on origin
        v.y = Float(pt.y) * scale - viewSize/2
        v.z = 0
        return v
    }
    
    func unMapPoint(_ p:float3) -> CGPoint {
        var v = CGPoint()
        v.x = xc + CGFloat(p.x / scale)
        v.y = xc + CGFloat(p.y / scale)
        return v
    }
    
    override func draw(_ rect: CGRect) {
        if scale == 0 {
            scale = viewSize / Float(bounds.width)
            xc = bounds.width / 2
            
            let tap1 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap1(_:)))
            tap1.numberOfTapsRequired = 1
            addGestureRecognizer(tap1)
            
            let tap2 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap2(_:)))
            tap2.numberOfTapsRequired = 2
            addGestureRecognizer(tap2)

            isUserInteractionEnabled = true
        }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(fastEdit ? nrmColorFast.cgColor : nrmColorSlow.cgColor)
        context?.addRect(bounds)
        context?.fillPath()

        context?.setLineWidth(1)
        context?.setStrokeColor(UIColor.darkGray.cgColor)
        context?.addRect(bounds)
        context?.move(to: CGPoint(x:0, y:bounds.height/2))
        context?.addLine(to: CGPoint(x:bounds.width, y:bounds.height/2))
        context?.strokePath()
        
        drawText(10,8,.lightGray,16,"Move")
        
        if hasFocus {
            UIColor.red.setStroke()
            UIBezierPath(rect:bounds).stroke()
        }
    }
    
    //MARK:-

    @objc func handleTap1(_ sender: UITapGestureRecognizer) {
        vc.removeAllFocus()
        hasFocus = true
        
        dx = 0
        dy = 0
        setNeedsDisplay()
    }
    
    @objc func handleTap2(_ sender: UITapGestureRecognizer) {
        fastEdit = !fastEdit
        
        dx = 0
        dy = 0
        setNeedsDisplay()
    }

    //MARK:-
    
    func focusMovement(_ pt:CGPoint) {
        if pt.x == 0 { touched = false; return }
        
        dx = Float(pt.x) / 500
        dy = Float(pt.y) / 500
        
        if !fastEdit {
            dx /= 10
            dy /= 10
        }
        
        touched = true
        setNeedsDisplay()
    }
    
    // MARK: Touch --------------------------
    
    var touched:Bool = false
    var dx:Float = 0
    var dy:Float = 0

    func update() -> Bool {
        if touched { vc.alterPosition(dx * speedMult[speedIndex],dy * speedMult[speedIndex]) }
        return touched
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            dx = Float(pt.x - bounds.size.width/2) * 0.05
            dy = Float(pt.y - bounds.size.height/2) * 0.05
            touched = true
            
            if !fastEdit {
                dx /= 100
                dy /= 100
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan(touches, with:event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touched = false
    }

    // MARK:

    func drawText(_ x:CGFloat, _ y:CGFloat, _ color:UIColor, _ sz:CGFloat, _ str:String) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.left
        
        let font = UIFont.init(name: "Helvetica", size:sz)!
        
        let textFontAttributes = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: color,
            NSAttributedStringKey.paragraphStyle: paraStyle,
            ]
        
        str.draw(in: CGRect(x:x, y:y, width:800, height:100), withAttributes: textFontAttributes)
    }
}

