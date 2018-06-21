import UIKit

enum WidgetKind { case single,dual }
let UNUSED:CGFloat = 9999

let limColor = UIColor(red:0.25, green:0.25, blue:0.2, alpha: 1)
let nrmColorFast = UIColor(red:0.2, green:0.2, blue:0.2, alpha: 1)
let nrmColorSlow = UIColor(red:0.2, green:0.25, blue:0.2, alpha: 1)
let textColor = UIColor.lightGray

class Widget: UIView {
    var context : CGContext?
    var kind:WidgetKind = .single
    var ident:Int = 0
    var fastEdit = true
    var hasFocus = false
    
    var highLightPoint = CGPoint(x:UNUSED,y:UNUSED)
    var valuePointerX:UnsafeMutableRawPointer! = nil
    var valuePointerY:UnsafeMutableRawPointer! = nil
    var deltaValue:Float = 0
    var name:String = "name"
    var mRange = float2()
    
    func initCommon(_ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        mRange.x = min
        mRange.y = max
        deltaValue = delta
        name = iname
        
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
    
    func initSingle(_ vx:UnsafeMutableRawPointer, _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        kind = .single
        valuePointerX = vx
        initCommon(min,max,delta,iname)
    }

    func initDual(_ vx:UnsafeMutableRawPointer, _ min:Float, _ max:Float,  _ delta:Float, _ iname:String) {
        kind = .dual
        valuePointerX = vx
        initCommon(min,max,delta,iname)
    }
    func initDual2(_ vy:UnsafeMutableRawPointer) { valuePointerY = vy }

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
        if valuePointerX == nil { return }
        
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
    
    func highlight(_ x:CGFloat) {
        highLightPoint.x = x
    }
    
    func percentX(_ percent:CGFloat) -> CGFloat { return CGFloat(bounds.size.width) * percent }
    
    //MARK: ==================================
    
    override func draw(_ rect: CGRect) {
        context = UIGraphicsGetCurrentContext()
        
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
        
        if kind == .dual {
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
        }
        
        UIColor.black.set()
        context?.setLineWidth(2)
        drawVLine(context!,bounds.midX,0,bounds.height)

        let cursorX = valueRatio(0) * bounds.width
        
        if kind == .dual {
            drawHLine(context!,0,bounds.width,bounds.midY)
        
            let y = (CGFloat(1) - valueRatio(1)) * bounds.height
            drawFilledCircle(context!,CGPoint(x:cursorX,y:y),15,UIColor.black.cgColor)
        }
        else {
            UIColor.darkGray.set()
            drawVLine(context!,cursorX,0,bounds.height)
        }
        
        drawText(10,8,textColor,16,name)
        
        if highLightPoint.x != UNUSED {
            let den = CGFloat(mRange.y - mRange.x)
            if den != 0 {
                let vx:CGFloat = (highLightPoint.x - CGFloat(mRange.x)) / den
                let vy:CGFloat = (highLightPoint.y - CGFloat(mRange.x)) / den
                let x = CGFloat(vx) * bounds.width
                let y = (kind == .dual) ? (CGFloat(1) - vy) * bounds.height : bounds.midY
                
                drawFilledCircle(context!,CGPoint(x:x,y:y),4,UIColor.darkGray.cgColor)
            }
        }
        
        drawBorder(context!,bounds)
        
        let path = UIBezierPath(rect:bounds)
        context!.setStrokeColor(hasFocus ? UIColor.red.cgColor : UIColor.black.cgColor)
        context!.setLineWidth(1)
        context!.addPath(path.cgPath)
        context!.strokePath()
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
        if valuePointerX == nil || !touched { return false }
        
        let valueX = fClamp2(getValue(0) + deltaX * deltaValue, mRange)
        let valueY = fClamp2(getValue(1) + deltaY * deltaValue, mRange)

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
        if valuePointerX == nil { return }
        
        for t in touches {
            let pt = t.location(in: self)

            deltaX =  Float((pt.x - bounds.midX) / bounds.width)  / 10
            deltaY = -Float((pt.y - bounds.midY) / bounds.height) / 10
            
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

