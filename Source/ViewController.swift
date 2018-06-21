import UIKit
import Metal
import simd

let kludgeAutoLayout:Bool = false
let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait
let scrnIndex = 1
let scrnLandscape:Bool = false

let IMAGESIZE_LOW:Int32 = 760
let IMAGESIZE_HIGH:Int32 = 2000

var control = Control()
var vc:ViewController! = nil

class ViewController: UIViewController {
    var cBuffer:MTLBuffer! = nil
    var isStereo:Bool = false
    var isFullScreen:Bool = false
    var isHighRes:Bool = false
    var viewXS = Int32()
    var viewYS = Int32()

    var timer = Timer()
    var outTextureL: MTLTexture!
    var outTextureR: MTLTexture!
    let bytesPerPixel: Int = 4
    var pipeline1: MTLComputePipelineState!
    let queue = DispatchQueue(label: "Queue")
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()

    let threadGroupCount = MTLSizeMake(20,20, 1)   // integer factor of SIZE
    var threadGroups = MTLSize()
    
    @IBOutlet var cRotate: CRotate!
    @IBOutlet var cTranslate: CTranslate!
    @IBOutlet var cTranslateZ: CTranslateZ!
    @IBOutlet var sZoom: Widget!
    @IBOutlet var sScaleFactor: Widget!
    @IBOutlet var sEpsilon: Widget!
    @IBOutlet var dSphere: Widget!
    @IBOutlet var sSphere: Widget!
    @IBOutlet var dBox: Widget!
    @IBOutlet var dColorR: Widget!
    @IBOutlet var dColorG: Widget!
    @IBOutlet var dColorB: Widget!
    @IBOutlet var dJuliaXY: Widget!
    @IBOutlet var sJuliaZ: Widget!
    @IBOutlet var wLightXY: Widget!
    @IBOutlet var sLightZ: Widget!
    @IBOutlet var sToeIn: Widget!
    @IBOutlet var sMaxDist: Widget!
    @IBOutlet var sContrast: Widget!
    @IBOutlet var sBlinn: Widget!
    @IBOutlet var metalTextureViewL: MetalTextureView!
    @IBOutlet var metalTextureViewR: MetalTextureView!
    @IBOutlet var resetButton: UIButton!
    @IBOutlet var saveLoadButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var resolutionButton: UIButton!
    @IBOutlet var stereoButton: UIButton!
    @IBOutlet var burningShipButton: UIButton!
    @IBOutlet var juliaOnOff: UISwitch!
    
    @IBAction func resetButtonPressed(_ sender: UIButton) { reset() }
    @IBAction func juliaOnOffChanged(_ sender: UISwitch) { control.juliaboxMode = sender.isOn;  updateImage() }
    
    @IBAction func resolutionButtonPressed(_ sender: UIButton) {
        isHighRes = !isHighRes
        setImageViewResolution()
        updateImage()
    }

    func updateResolutionButton() { resolutionButton.setTitle(isHighRes ? " Res: High" : " Res: Low", for: UIControlState.normal) }

    @IBAction func stereoButtonPressed(_ sender: UIButton) {
        isStereo = !isStereo
        rotated()
        updateImage()
    }
    
    func updateBurningShipButtonBackground() {
        let bsOff = UIColor(red:0.25, green:0.25, blue:0.25, alpha: 1)
        let bsOn  = UIColor(red:0.1, green:0.3, blue:0.1, alpha: 1)
        burningShipButton.backgroundColor = control.burningShip ? bsOn : bsOff
    }

    @IBAction func burningShipButtonPressed(_ sender: UIButton) {
        control.burningShip = !control.burningShip
        updateBurningShipButtonBackground()
        updateImage()
    }

    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        isFullScreen = !isFullScreen
        rotated()
        updateImage()
    }
    
    var juliaX:Float = 0.0
    var juliaY:Float = 0.0
    var juliaZ:Float = 0.0
    var lightX:Float = 0.0
    var lightY:Float = 0.0
    var lightZ:Float = 0.0

    var wList:[Widget]! = nil
    var bList:[UIView]! = nil

    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK: -

    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        
        do {
            let defaultLibrary:MTLLibrary! = self.device.makeDefaultLibrary()
            guard let kf1 = defaultLibrary.makeFunction(name: "mandelBoxShader")  else { fatalError() }
            pipeline1 = try device.makeComputePipelineState(function: kf1)
        }
        catch { fatalError("error creating pipelines") }

        let hk = cRotate.bounds
        arcBall.initialize(Float(hk.size.width),Float(hk.size.height))

        cBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<Control>.stride, options: MTLResourceOptions.storageModeShared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        wList = [ sZoom,sScaleFactor,sEpsilon,sJuliaZ,sLightZ,sSphere,sToeIn,sMaxDist,sContrast,sBlinn,
                  dSphere,dBox,dColorR,dColorG,dColorB,dJuliaXY,wLightXY ]
        bList = [ resetButton,saveLoadButton,helpButton,resolutionButton,stereoButton,juliaOnOff,burningShipButton ]

        sZoom.initSingle(&control.zoom,  0.2,2, 0.03, "Zoom")
        sScaleFactor.initSingle(&control.scaleFactor,  -5.0,5.0, 0.1, "Scale Factor")
        sScaleFactor.highlight(3)
        
        sEpsilon.initSingle(&control.epsilon,  0.00001, 0.0005, 0.0001, "epsilon")
        
        dSphere.initDual(&control.sph1, 0,3,0.1 , "Sphere");  dSphere.initDual2(&control.sph2)
        dSphere.highlight(0.25,1)
        sSphere.initSingle(&control.sph3,  0.1,6.0,0.1, "Sphere M")
        sSphere.highlight(4)

        dBox.initDual(&control.box1, 0,3,0.05, "Box"); dBox.initDual2(&control.box2)
        dBox.highlight(1,2)

        dColorR.initDual(&control.colorR1, 0,1,0.06, "R"); dColorR.initDual2(&control.colorR2)
        dColorG.initDual(&control.colorG1, 0,1,0.06, "G"); dColorG.initDual2(&control.colorG2)
        dColorB.initDual(&control.colorB1, 0,1,0.06, "B"); dColorB.initDual2(&control.colorB2)

        dJuliaXY.initDual(&juliaX, -10,10, 1, "Julia XY"); dJuliaXY.initDual2(&juliaY)
        sJuliaZ.initSingle(&juliaZ,  -10,10,1, "Julia Z")

        wLightXY.initDual(&lightX,-1,1, 0.1, "Light XY"); wLightXY.initDual2(&lightY)
        sLightZ.initSingle(&lightZ,  -1,1, 0.1, "Light Z")

        let toeInRange:Float = 0.008
        sToeIn.initSingle(&control.toeIn,  -toeInRange,+toeInRange,0.0002, "Parallax")
        sToeIn.highlight(0)

        sMaxDist.initSingle(&control.maxDist,  0.01,6,0.2, "F")
        sContrast.initSingle(&control.contrast, 0.1,5,0.1, "C")
        sBlinn.initSingle(&control.blinn, 0.1,2,0.1, "B")

        reset()        
        timer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)
    }
    
    
    //MARK: -

    func reset() {
        isHighRes = false
        updateResolutionButton()

        control.camera = vector_float3(0.38135, 2.3424, -0.380833)
        control.focus = vector_float3(-0.52,-1.22,-0.31)
        control.transformMatrix = matrix_float4x4.init(diagonal: float4(1,1,1,1))
        control.zoom = 0.6141
        control.epsilon = 0.000074
        control.scaleFactor = 3
        
        control.sph1 = 0.25
        control.sph2 = 1
        control.sph3 = 4
        control.box1 = 1
        control.box2 = 2
        
        control.colorR1 = 0.5
        control.colorR2 = 0.5
        control.colorG1 = 0.5
        control.colorG2 = 0.5
        control.colorB1 = 0.5
        control.colorB2 = 0.5
        
        control.julia = float3()
        control.juliaboxMode = false
        juliaOnOff.isOn = false
        
        control.light.x = 0.33
        control.light.y = 0.66
        control.light.z = 1.0

        control.toeIn = 0.0011
        control.maxDist = 3
        control.contrast = 0.8
        control.blinn = 0.5

        unWrapFloat3()
        
        for w in wList { w.setNeedsDisplay() }
        alterAngle(0,0)
        updateImage()
    }
    
    func updateWidgets() {
        if control.maxDist < 0.1 { control.maxDist = 1 }  // so older saves have a initialized fog value
        if control.contrast < 0.1 { control.contrast = 1 }
        updateBurningShipButtonBackground()
        juliaOnOff.isOn = control.juliaboxMode
        unWrapFloat3()

        for w in wList { w.setNeedsDisplay() }
        setImageViewResolution()
        updateImage()
    }
    
    func setImageViewResolution() {
        control.xSize = viewXS
        control.ySize = viewYS
        if !isHighRes {
            control.xSize /= 2
            control.ySize /= 2
        }
        
        let xsz = Int(control.xSize)
        let ysz = Int(control.ySize)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: xsz,
            height: ysz,
            mipmapped: false)
        outTextureL = self.device.makeTexture(descriptor: textureDescriptor)!
        outTextureR = self.device.makeTexture(descriptor: textureDescriptor)!

        metalTextureViewL.initialize(outTextureL)
        metalTextureViewR.initialize(outTextureR)
        
        let maxsz = max(xsz,ysz) + Int(threadGroupCount.width-1)
        threadGroups = MTLSizeMake(
            maxsz / threadGroupCount.width,
            maxsz / threadGroupCount.height,1)
        
        updateResolutionButton()
    }
    
    //MARK: -

    func removeAllFocus() {
        for w in wList { if w.hasFocus { w.hasFocus = false; w.setNeedsDisplay() }}
        if cTranslate.hasFocus { cTranslate.hasFocus = false; cTranslate.setNeedsDisplay() }
        if cTranslateZ.hasFocus { cTranslateZ.hasFocus = false; cTranslateZ.setNeedsDisplay() }
        if cRotate.hasFocus { cRotate.hasFocus = false; cRotate.setNeedsDisplay() }
    }
    
    func focusMovement(_ pt:CGPoint) {
        for w in wList { if w.hasFocus { w.focusMovement(pt); return }}
        if cTranslate.hasFocus { cTranslate.focusMovement(pt); return }
        if cTranslateZ.hasFocus { cTranslateZ.focusMovement(pt); return }
        if cRotate.hasFocus { cRotate.focusMovement(pt); return }
    }
    
    //MARK: -
    
    var xs = CGFloat()
    var ys = CGFloat()

    @objc func rotated() {
        xs = view.bounds.width
        ys = view.bounds.height
        
        if kludgeAutoLayout {
            xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
            ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y
        }

        let bys:CGFloat = 32    // slider height
        let gap:CGFloat = 10
        let cxs:CGFloat = 120
        let cxs2:CGFloat = (cxs * 2 - gap) / 3
        let yHop = bys + gap
        let xHop = cxs + gap
        let xHop2 = cxs2 + gap

        var sz:CGFloat = xs - 10
        var by:CGFloat = sz + 10  // top of widgets
        var x:CGFloat = 0
        var y = by

        func frame(_ xs:CGFloat, _ ys:CGFloat, _ dx:CGFloat, _ dy:CGFloat) -> CGRect {
            let r = CGRect(x:x, y:y, width:xs, height:ys)
            x += dx; y += dy
            return r
        }

        func portraitCommon() {
            sZoom.frame = frame(cxs,bys,0,yHop)
            sScaleFactor.frame = frame(cxs,bys,0,yHop)
            
            let xx = cxs - bys - 5
            cTranslate.frame = frame(xx,cxs,0,0)
            var x2 = x
            x += xx + 5
            cTranslateZ.frame = frame(bys,cxs,0,xHop)

            x = x2
            stereoButton.frame = frame(bys,bys,yHop,0)
            sToeIn.frame = frame(cxs - bys - gap,bys,0,0)
            x = x2 + xHop
            
            y = by
            dSphere.frame = frame(cxs,cxs,0,xHop)
            sSphere.frame = frame(cxs,bys,0,yHop)
            dBox.frame = frame(cxs2,cxs2,xHop,0)
            y = by
            dColorR.frame = frame(cxs2,cxs2,0,xHop2)
            dColorG.frame = frame(cxs2,cxs2,0,xHop2)
            dColorB.frame = frame(cxs2,cxs2,xHop2,0)
            y = by
            dJuliaXY.frame = frame(cxs,cxs,0,xHop)
            sJuliaZ.frame  = frame(cxs,bys,0,yHop + 5)
            
            x2 = x
            juliaOnOff.frame = frame(50,30,60,0)
            resetButton.frame = frame(50,bys,0,yHop)
            x = x2
            let xHop2 = xHop/3 - 5
            sMaxDist.frame = frame(xHop2,bys,xHop2+3,0)
            sContrast.frame = frame(xHop2,bys,xHop2+3,0)
            sBlinn.frame = frame(xHop2,bys,xHop2,0)
            x += 8
            
            x2 = x
            y = by
            wLightXY.frame = frame(cxs,cxs,0,xHop)
            sLightZ.frame  = frame(cxs,bys,0,yHop + 5)
            saveLoadButton.frame = frame(80,bys,20,yHop)
            helpButton.frame = frame(bys,bys,bys + 20,0)
            burningShipButton.frame = frame(bys,bys,0,0)
            x = x2 + xHop
            y = by
            resolutionButton.frame = frame(80,bys,0,yHop)
            sEpsilon.frame = frame(cxs,bys,0,yHop)
            cRotate.frame = frame(cxs,cxs,0,cxs+gap)
        }
        
        func portraitMono() {
            sz = xs
            by = ys - 260  // top of widgets
            x = (xs - 730) / 2
            y = by
            
            viewXS = Int32(sz)
            viewYS = Int32(by-10)

            metalTextureViewR.isHidden = true
            sToeIn.isHidden = true

            metalTextureViewL.frame = CGRect(x:0, y:0, width:CGFloat(viewXS), height:CGFloat(viewYS))
            portraitCommon()
        }

        func portraitStereo() {
            sz = xs
            by = ys - 260  // top of widgets
            x = (xs - 730) / 2
            y = by

            viewXS = Int32(sz/2)
            viewYS = Int32(by-10)

            metalTextureViewR.isHidden = false
            sToeIn.isHidden = false
            
            metalTextureViewL.frame = CGRect(x:0, y:0, width:CGFloat(viewXS), height:CGFloat(viewYS))
            metalTextureViewR.frame = CGRect(x:CGFloat(viewXS), y:0, width:CGFloat(viewXS), height:CGFloat(viewYS))
            portraitCommon()
        }

        func landScapeCommon() {
            x = 30
            y = ys - cxs - 40
            let xx = cxs - bys - 5
            cTranslate.frame = frame(xx,cxs,0,0)
            x += xx + 5
            cTranslateZ.frame = frame(bys,cxs,0,0)
            
            x = xs - cxs - 30
            cRotate.frame = frame(cxs,cxs,0,0)
        }
        
        func landScapeMono() {
            by = 10     // top of widgets
            let left = xs - 260
            x = left
            y = by
            
            viewXS = Int32(left-10)
            viewYS = Int32(ys)
            
            metalTextureViewR.isHidden = true
            sToeIn.isHidden = true
            
            metalTextureViewL.frame = CGRect(x:CGFloat(), y:CGFloat(), width:CGFloat(viewXS), height:CGFloat(viewYS))
            
            sZoom.frame = frame(cxs,bys,0,yHop)
            sScaleFactor.frame = frame(cxs,bys,xHop,0)
            y = by
            resolutionButton.frame = frame(80,bys,0,yHop)
            sEpsilon.frame = frame(cxs,bys,0,0)
            x = left
            y = by + 90
            dSphere.frame = frame(cxs,cxs,xHop,0)
            dBox.frame = frame(cxs,cxs,0,xHop)
            x = left
            sSphere.frame  = frame(cxs,bys,xHop,bys+gap)
            x = left
            dColorR.frame = frame(cxs2,cxs2,xHop2,0)
            dColorG.frame = frame(cxs2,cxs2,xHop2,0)
            dColorB.frame = frame(cxs2,cxs2,0,xHop2)
            x = left
            dJuliaXY.frame = frame(cxs,cxs,xHop,0)
            wLightXY.frame = frame(cxs,cxs,0,xHop)
            x = left
            sJuliaZ.frame  = frame(cxs,bys,cxs+gap,0)
            sLightZ.frame  = frame(cxs,bys,0,yHop)
            x = left
            juliaOnOff.frame = frame(50,30,xHop,0)
            saveLoadButton.frame = frame(80,bys,0,bys+gap)

            x = left
            let xHop3 = xHop/3 - 6
            sMaxDist.frame = frame(xHop3,bys,xHop3+5,0)
            sContrast.frame = frame(xHop3,bys,xHop3+5,0)
            sBlinn.frame = frame(xHop3,bys,xHop3,0)
            x += 15
            
            resetButton.frame = frame(50,bys,0,bys+gap)
            stereoButton.frame = frame(bys,bys,0,bys+gap)
            helpButton.frame = frame(bys,bys,bys + 20,0)
            burningShipButton.frame = frame(bys,bys,0,0)

            landScapeCommon()
            
            sZoom.setNeedsDisplay()
        }

        func landScapeStereo() {
            let sz2 = xs / 2
            by = ys - 270  // top of widgets
            x = (xs - 700) / 2
            y = by
            
            viewXS = Int32(sz2)
            viewYS = Int32(by-10)
            
            metalTextureViewR.isHidden = false
            sToeIn.isHidden = false
            
            metalTextureViewL.frame = CGRect(x:CGFloat(), y:CGFloat(), width:CGFloat(viewXS), height:CGFloat(viewYS))
            metalTextureViewR.frame = CGRect(x:sz2+2, y:CGFloat(), width:CGFloat(viewXS), height:CGFloat(viewYS))

            sZoom.frame = frame(cxs,bys,0,yHop)
            sScaleFactor.frame = frame(cxs,bys,0,yHop)
            
            var x2 = x
            stereoButton.frame = frame(bys,bys,yHop,0)
            sToeIn.frame = frame(cxs - bys - gap,bys,0,yHop + 4)
            
            x = x2
            let xHop3 = xHop/3 - 6
            sMaxDist.frame = frame(xHop3,bys,xHop3+5,0)
            sContrast.frame = frame(xHop3,bys,xHop3+5,0)
            sBlinn.frame = frame(xHop3,bys,xHop3,0)

            x = x2 + xHop
            y = by
            dSphere.frame = frame(cxs,cxs,0,xHop)
            sSphere.frame  = frame(cxs,bys,0,yHop)
            dBox.frame = frame(cxs2,cxs2,xHop,0)
            
            y = by
            dColorR.frame = frame(cxs2,cxs2,0,xHop2)
            dColorG.frame = frame(cxs2,cxs2,0,xHop2)
            dColorB.frame = frame(cxs2,cxs2,xHop2,0)
            y = by
            dJuliaXY.frame = frame(cxs,cxs,0,xHop)
            sJuliaZ.frame  = frame(cxs,bys,0,yHop + 5)
            juliaOnOff.frame = frame(50,30,0,yHop)
            resetButton.frame = frame(50,bys,xHop,0)
            y = by
            x2 = x
            wLightXY.frame = frame(cxs,cxs,0,xHop)
            sLightZ.frame  = frame(cxs,bys,0,yHop + 5)
            saveLoadButton.frame = frame(80,bys,0,yHop)
            helpButton.frame = frame(bys,bys,bys + 20,0)
            burningShipButton.frame = frame(bys,bys,0,0)

            x = x2 + xHop
            y = by
            resolutionButton.frame = frame(80,bys,0,yHop)
            sEpsilon.frame = frame(cxs,bys,0,yHop)
            
            landScapeCommon()
        }
        
        // ------------------------------------------------------------------
        
        func fullScreenStereo() {
            viewXS = Int32(xs/2)
            viewYS = Int32(ys)
            
            metalTextureViewR.isHidden = false
            
            metalTextureViewL.frame = CGRect(x:0, y:0, width:CGFloat(viewXS), height:CGFloat(viewYS))
            metalTextureViewR.frame = CGRect(x:CGFloat(viewXS), y:0, width:CGFloat(viewXS), height:CGFloat(viewYS))
            
            landScapeCommon()
            
            view.bringSubview(toFront: cRotate)
            
            sToeIn.isHidden = false
            x = 40 + cxs + 30
            y = ys - 40 - bys
            sToeIn.frame = CGRect(x:x, y:y, width:100, height:bys)
        }

        func fullScreenMono() {
            viewXS = Int32(xs)
            viewYS = Int32(ys)

            metalTextureViewR.isHidden = true
            sToeIn.isHidden = true
            
            metalTextureViewL.frame = CGRect(x:0, y:0, width:xs, height:ys)
            landScapeCommon()
        }
        
        // ------------------------------------------------------------------

        if wList != nil {
            for w in wList { w.isHidden = isFullScreen }
            for b in bList { b.isHidden = isFullScreen }
        }

        if isFullScreen {
            if isStereo { fullScreenStereo() } else { fullScreenMono() }
        }
        else {
            let isPortrait:Bool = ys > xs
            
            if isPortrait {
                if isStereo { portraitStereo() } else { portraitMono() }
            }
            else {
                if isStereo { landScapeStereo() } else { landScapeMono() }
            }
        }
        
        if wList != nil { for w in wList { w.setNeedsDisplay() }}
        setImageViewResolution()
        updateImage()
    }
    
    //MARK: -
    
    func unWrapFloat3() {
        juliaX = control.julia.x
        juliaY = control.julia.y
        juliaZ = control.julia.z
        lightX = control.light.x
        lightY = control.light.y
        lightZ = control.light.z
    }
    
    func wrapFloat3() {
        control.julia.x = juliaX
        control.julia.y = juliaY
        control.julia.z = juliaZ
        control.light.x = lightX
        control.light.y = lightY
        control.light.z = lightZ
    }
    
    //MARK: -
    
    @objc func timerHandler() {
        var refresh:Bool = false
        
        if cTranslate.update() { refresh = true }
        if cTranslateZ.update() { refresh = true }
        if cRotate.update() { refresh = true }
        for w in wList { if w.update() { refresh = true }}

        if refresh { updateImage() }
    }
    
    //MARK: -
    
    func alterAngle(_ dx:Float, _ dy:Float) {
        let center:CGFloat = cRotate.bounds.width/2
        arcBall.mouseDown(CGPoint(x: center, y: center))
        arcBall.mouseMove(CGPoint(x: center + CGFloat(dx/50), y: center + CGFloat(dy/50)))
        
        let direction = simd_make_float4(0,0.1,0,0)
        let rotatedDirection = simd_mul(arcBall.transformMatrix, direction)
        
        control.focus.x = rotatedDirection.x
        control.focus.y = rotatedDirection.y
        control.focus.z = rotatedDirection.z
        control.focus += control.camera
        
        updateImage()
    }
    
    func alterPosition(_ dx:Float, _ dy:Float, _ dz:Float) {
        func axisAlter(_ dir:float4, _ amt:Float) {
            let diff = simd_mul(arcBall.transformMatrix, dir) * amt / 300.0
            
            func alter(_ value: inout float3) {
                value.x -= diff.x
                value.y -= diff.y
                value.z -= diff.z
            }
            
            alter(&control.camera)
            alter(&control.focus)
        }

        let q:Float = 0.1
        axisAlter(simd_make_float4(q,0,0,0),dx)
        axisAlter(simd_make_float4(0,0,q,0),dy)
        axisAlter(simd_make_float4(0,q,0,0),dz)

        updateImage()
    }
    
    //MARK: -
    
    var isBusy:Bool = false

    func updateImage() {
        if isBusy { return }
        isBusy = true
        
        calcRayMarch(0)
        metalTextureViewL.display(metalTextureViewL.layer)

        if isStereo {
            calcRayMarch(1)
            metalTextureViewR.display(metalTextureViewR.layer)
        }
        
        isBusy = false
    }
    
    //MARK: -
    
    func calcRayMarch(_ who:Int) {
        wrapFloat3()

        var c = control
        if who == 0 { c.camera.x -= control.toeIn }
        if who == 1 { c.camera.x += control.toeIn }
        c.light = normalize(c.light)
        
        cBuffer.contents().copyMemory(from: &c, byteCount:MemoryLayout<Control>.stride)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline1)
        commandEncoder.setTexture(who == 0 ? outTextureL : outTextureR, index: 0)
        commandEncoder.setBuffer(cBuffer, offset: 0, index: 0)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
