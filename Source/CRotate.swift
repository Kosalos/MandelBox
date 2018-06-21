import UIKit

class CRotate: UIView {
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
            self.backgroundColor = .clear
        }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(fastEdit ? nrmColorFast.cgColor : nrmColorSlow.cgColor)
        context?.addRect(bounds)
        context?.fillPath()

        UIColor.black.set()
        context?.setLineWidth(2)
        drawVLine(context!,bounds.midX,0,bounds.height)
        drawHLine(context!,0,bounds.width,bounds.midY)
        drawText(10,8,textColor,16,"Rotate")

        drawBorder(context!,bounds)
        
        if hasFocus {
            context?.setLineWidth(1)
            context!.setStrokeColor(UIColor.red.cgColor)
            drawRect(context!,bounds)
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
    
    // MARK: Touch --------------------------
    
    var touched:Bool = false
    var dx:Float = 0
    var dy:Float = 0
    
    func update() -> Bool {
        if touched { vc.alterAngle(dx,dy) }
        return touched
    }
    
    //MARK:-
    
    func focusMovement(_ pt:CGPoint) {
        if pt.x == 0 { touched = false; return }
        
        dx = Float(pt.x) / 10
        dy = Float(pt.y) / 10
        
        if !fastEdit {
            dx /= 10
            dy /= 10
        }
        
        touched = true
        setNeedsDisplay()
    }
    
    // MARK: Touch --------------------------
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            dx = Float(pt.x - bounds.size.width/2) * 0.05
            dy = Float(pt.y - bounds.size.height/2) * 0.05
            touched = true
            
            if !fastEdit {
                dx /= 10
                dy /= 10
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan(touches, with:event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touched = false
    }
}

// MARK:

func drawLine(_ context:CGContext, _ p1:CGPoint, _ p2:CGPoint) {
    context.beginPath()
    context.move(to:p1)
    context.addLine(to:p2)
    context.strokePath()
}

func drawVLine(_ context:CGContext, _ x:CGFloat, _ y1:CGFloat, _ y2:CGFloat) { drawLine(context,CGPoint(x:x,y:y1),CGPoint(x:x,y:y2)) }
func drawHLine(_ context:CGContext, _ x1:CGFloat, _ x2:CGFloat, _ y:CGFloat) { drawLine(context,CGPoint(x:x1, y:y),CGPoint(x: x2, y:y)) }

func drawRect(_ context:CGContext, _ r:CGRect) {
    context.beginPath()
    context.addRect(r)
    context.strokePath()
}

func drawFilledCircle(_ context:CGContext, _ center:CGPoint, _ diameter:CGFloat, _ color:CGColor) {
    context.beginPath()
    context.addEllipse(in: CGRect(x:CGFloat(center.x - diameter/2), y:CGFloat(center.y - diameter/2), width:CGFloat(diameter), height:CGFloat(diameter)))
    context.setFillColor(color)
    context.fillPath()
}

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

//MARK:-


func drawBorder(_ context:CGContext,_ rect:CGRect) {
    let colorGray1 = UIColor(red:0.01, green:0.01, blue:0.01, alpha:1).cgColor
    let colorGray3 = UIColor(red:0.4, green:0.4, blue:0.4, alpha:1).cgColor
    let p1  = CGPoint(x:rect.minX, y:rect.minY)
    let p2  = CGPoint(x:rect.minX + rect.width, y:rect.minY)
    let p3  = CGPoint(x:rect.minX + rect.width, y:rect.minY + rect.height)
    let p4  = CGPoint(x:rect.minX, y:rect.minY + rect.height)
    
    func line(_ p1:CGPoint, _ p2:CGPoint, _ strokeColor:CGColor) {
        let path = CGMutablePath()
        path.move(to: p1)
        path.addLine(to: p2)
        
        context.setLineWidth(5)
        context.beginPath()
        context.setStrokeColor(strokeColor)
        context.addPath(path)
        context.drawPath(using:.stroke)
    }
    
    line(p1,p2,colorGray1)
    line(p1,p4,colorGray1)
    line(p2,p3,colorGray3)
    line(p3,p4,colorGray3)
}



