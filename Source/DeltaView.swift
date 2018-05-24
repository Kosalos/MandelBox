import UIKit

// test alteration

class DeltaView: UIView {
    var context : CGContext?
    var scenter:Float = 0
    var swidth:Float = 0
    var ident:Int = 0
    var active = true
    var fastEdit = true
    var hasFocus = false
    var highLightPoint = CGPoint()
    var valuePointerX:UnsafeMutableRawPointer! = nil
    var valuePointerY:UnsafeMutableRawPointer! = nil
    var deltaValue:Float = 0
    var name:String = "name"
    
    var mRange = float2(0,256)
    
    func address<T>(of: UnsafePointer<T>) -> UInt { return UInt(bitPattern: of) }
    
    func initialize(_ iname:String) { 
        name = iname
        boundsChanged()
    }
    
    func initializeFloat1(_ v: inout Float,  _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        let addr = address(of:&v)
        valuePointerX = UnsafeMutableRawPointer(bitPattern:addr)!
        
        mRange.x = min
        mRange.y = max
        deltaValue = delta
        name = iname
        boundsChanged()

        let tap1 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap1(_:)))
        tap1.numberOfTapsRequired = 1
        addGestureRecognizer(tap1)

        let tap2 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap2(_:)))
        tap2.numberOfTapsRequired = 2
        addGestureRecognizer(tap2)
        
        let tap3 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap3(_:)))
        tap3.numberOfTapsRequired = 3
        addGestureRecognizer(tap3)
        
        isUserInteractionEnabled = true
    }
    
    func initializeFloat2(_ v: inout Float) {
        let addr = address(of:&v)
        valuePointerY = UnsafeMutableRawPointer(bitPattern:addr)!
        setNeedsDisplay()
    }
    
    //MARK: ==================================

    @objc func handleTap1(_ sender: UITapGestureRecognizer) {
        vc.removeAllFocus()
        hasFocus = true

        deltaX = 0
        deltaY = 0
        setNeedsDisplay()
    }
    
    @objc func handleTap2(_ sender: UITapGestureRecognizer) {
        fastEdit = !fastEdit
        
        deltaX = 0
        deltaY = 0
        setNeedsDisplay()
    }
    
    @objc func handleTap3(_ sender: UITapGestureRecognizer) {
        if valuePointerX == nil || valuePointerY == nil { return }
        
        let valueX:Float = Float(highLightPoint.x)
        let valueY:Float = Float(highLightPoint.y)
        if let valuePointerX = valuePointerX { valuePointerX.storeBytes(of:valueX, as:Float.self) }
        if let valuePointerY = valuePointerY { valuePointerY.storeBytes(of:valueY, as:Float.self) }
        
        handleTap2(sender) // undo the double tap that was also recognized
    }

    //MARK: ==================================

    func highlight(_ x:CGFloat, _ y:CGFloat) {
        highLightPoint.x = x
        highLightPoint.y = y
    }
    
    func setActive(_ v:Bool) {
        active = v
        setNeedsDisplay()
    }
    
    func percentX(_ percent:CGFloat) -> CGFloat { return CGFloat(bounds.size.width) * percent }
  
    func boundsChanged() {
        swidth = Float(bounds.width)
        scenter = swidth / 2
        setNeedsDisplay()
    }
    
    //MARK: ==================================
    
    override func draw(_ rect: CGRect) {
        context = UIGraphicsGetCurrentContext()
        
        if !active {
            let G:CGFloat = 0.13        // color Lead
            UIColor(red:G, green:G, blue:G, alpha: 1).set()
            UIBezierPath(rect:bounds).fill()
            return
        }

        if fastEdit { nrmColorFast.set() } else { nrmColorSlow.set() }
        UIBezierPath(rect:bounds).fill()
        
        if isMinValue(0) {  // X coord
            limColor.set()
            var r = bounds
            r.size.width /= 2
            UIBezierPath(rect:r).fill()
        }
        else if isMaxValue(0) {
            limColor.set()
            var r = bounds
            r.origin.x += bounds.width/2
            r.size.width /= 2
            UIBezierPath(rect:r).fill()
        }
        
        if isMaxValue(1) {  // Y coord
            limColor.set()
            var r = bounds
            r.size.height /= 2
            UIBezierPath(rect:r).fill()
        }
        else if isMinValue(1) {
            limColor.set()
            var r = bounds
            r.origin.y += bounds.width/2
            r.size.height /= 2
            UIBezierPath(rect:r).fill()
        }

        // edge -------------------------------------------------
        let ctx = context!
        ctx.saveGState()
        let path = UIBezierPath(rect:bounds)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
        ctx.restoreGState()
        
        UIColor.black.set()
        context?.setLineWidth(2)
        
        drawVLine(context!,CGFloat(scenter),0,bounds.height)
        drawHLine(context!,0,bounds.width,CGFloat(scenter))
        
        // value ------------------------------------------
        func formatted(_ v:Float) -> String { return String(format:"%6.4f",v) }
        func formatted2(_ v:Float) -> String { return String(format:"%7.5f",v) }
        func formatted3(_ v:Float) -> String { return String(format:"%d",Int(v)) }
        func formatted4(_ v:Float) -> String { return String(format:"%5.2f",v) }
        
        let vx = percentX(0.60)
        
        func valueColor(_ v:Float) -> UIColor {
            var c = UIColor.gray
            if v < 0 { c = UIColor.red } else if v > 0 { c = UIColor.green }
            return c
        }
        
        func coloredValue(_ v:Float, _ y:CGFloat) { drawText(vx,y,valueColor(v),16, formatted(v)) }
  
        
        drawText(10,8,.lightGray,16,name)
        
//        if valuePointerX != nil {
//            let xx:Float = valuePointerX.load(as: Float.self)
//            let yy:Float = valuePointerY.load(as: Float.self)
//            
//            if self.tag == 1 { // iter
//                drawText(vx, 8,valueColor(xx),16, formatted3(xx))
//                drawText(vx,28,valueColor(yy),16, formatted3(yy))
//            }
//            else {
//                coloredValue(xx,8)
//                coloredValue(yy,28)
//            }
//        }
        
        // cursor -------------------------------------------------
        UIColor.black.set()
        context?.setLineWidth(2)
        
        let x = valueRatio(0) * bounds.width
        let y = (CGFloat(1) - valueRatio(1)) * bounds.height
        drawFilledCircle(context!,CGPoint(x:x,y:y),15,UIColor.black.cgColor)
        
        // highlight --------------------------------------
        
        if highLightPoint.x != 0 {
            let den = CGFloat(mRange.y - mRange.x)
            if den != 0 {
                let vx:CGFloat = (highLightPoint.x - CGFloat(mRange.x)) / den
                let vy:CGFloat = (highLightPoint.y - CGFloat(mRange.x)) / den
                let x = CGFloat(vx) * bounds.width
                let y = (CGFloat(1) - vy) * bounds.height
                
                drawFilledCircle(context!,CGPoint(x:x,y:y),4,UIColor.lightGray.cgColor)
            }
        }
        
        if hasFocus {
            UIColor.red.setStroke()
            UIBezierPath(rect:bounds).stroke()
        }
    }
    
    func fClamp2(_ v:Float, _ range:float2) -> Float {
        if v < range.x { return range.x }
        if v > range.y { return range.y }
        return v
    }
    
    var deltaX:Float = 0
    var deltaY:Float = 0
    var touched = false
    
    //MARK: ==================================

    func getValue(_ who:Int) -> Float {
        switch who {
        case 0 :
            if valuePointerX == nil { return 0 }
            return valuePointerX.load(as: Float.self)
        default:
            if valuePointerY == nil { return 0 }
            return valuePointerY.load(as: Float.self)
        }
    }
    
    func isMinValue(_ who:Int) -> Bool {
        if valuePointerX == nil { return false }
        
        return getValue(who) == mRange.x
    }
    
    func isMaxValue(_ who:Int) -> Bool {
        if valuePointerX == nil { return false }
        
        return getValue(who) == mRange.y
    }
    
    func valueRatio(_ who:Int) -> CGFloat {
        let den = mRange.y - mRange.x
        if den == 0 { return CGFloat(0) }
        return CGFloat((getValue(who) - mRange.x) / den )
    }
    
    //MARK: ==================================
    
    func update() -> Bool {
        if valuePointerX == nil || valuePointerY == nil || !active || !touched { return false }
        
        let scale = speedMult[speedIndex]
        let valueX = fClamp2(getValue(0) + deltaX * deltaValue * scale, mRange)
        let valueY = fClamp2(getValue(1) + deltaY * deltaValue * scale, mRange)

        if let valuePointerX = valuePointerX { valuePointerX.storeBytes(of:valueX, as:Float.self) }
        if let valuePointerY = valuePointerY { valuePointerY.storeBytes(of:valueY, as:Float.self) }

        setNeedsDisplay()
        return true
    }
    
    //MARK: ==================================

    func focusMovement(_ pt:CGPoint) {
        if pt.x == 0 { touched = false; return }
        
        deltaX =  Float(pt.x) / 1000
        deltaY = -Float(pt.y) / 1000
        
        if !fastEdit {
            deltaX /= 100
            deltaY /= 100
        }
        
        touched = true
        setNeedsDisplay()
    }
    
    //MARK: ==================================
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !active { return }
        if valuePointerX == nil || valuePointerY == nil { return }
        
        for t in touches {
            let pt = t.location(in: self)

            deltaX = (Float(pt.x) - scenter) / swidth / 10
            deltaY = -(Float(pt.y) - scenter) / swidth / 10
            
            if !fastEdit {
                deltaX /= 100
                deltaY /= 100
            }
            
            touched = true
            setNeedsDisplay()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { touchesBegan(touches, with:event) }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touched = false
    }
}

