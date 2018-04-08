import UIKit
import Metal
import simd

let kludgeAutoLayout:Bool = false
let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait
let scrnIndex = 2
let scrnLandscape:Bool = true

let IMAGESIZE_LOW:Int32 = 600
let IMAGESIZE_HIGH:Int32 = 2000

var control = Control()
var vc:ViewController! = nil

class ViewController: UIViewController {
    var cBuffer:MTLBuffer! = nil
    
    var timer = Timer()
    var outTexture: MTLTexture!
    var outTextureL: MTLTexture!
    var outTextureH: MTLTexture!
    let bytesPerPixel: Int = 4
    var pipeline1: MTLComputePipelineState!
    let queue = DispatchQueue(label: "Queue")
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    var circleMove:Bool = false

    let threadGroupCount = MTLSizeMake(20,20, 1)   // integer factor of SIZE
    var threadGroups = MTLSize()
    var threadGroupsL = MTLSize()
    var threadGroupsH = MTLSize()

    @IBOutlet var cRotate: CRotate!
    @IBOutlet var cTranslate: CTranslate!
    @IBOutlet var sZoom: SliderView!
    @IBOutlet var sScaleFactor: SliderView!
    @IBOutlet var sEpsilon: SliderView!
    @IBOutlet var dSphere: DeltaView!
    @IBOutlet var sSphere: SliderView!
    @IBOutlet var dBox: DeltaView!
    @IBOutlet var dColorR: DeltaView!
    @IBOutlet var dColorG: DeltaView!
    @IBOutlet var dColorB: DeltaView!
    @IBOutlet var dJuliaXY: DeltaView!
    @IBOutlet var sJuliaZ: SliderView!
    @IBOutlet var dLightXY: DeltaView!
    @IBOutlet var sLightZ: SliderView!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var resetButton: UIButton!
    @IBOutlet var saveLoadButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var resolutionButton: UIButton!
    @IBOutlet var juliaOnOff: UISwitch!
    
    @IBAction func resetButtonPressed(_ sender: UIButton) { reset() }
    @IBAction func juliaOnOffChanged(_ sender: UISwitch) { control.juliaboxMode = sender.isOn;  updateImage() }
    
    @IBAction func resolutionButtonPressed(_ sender: UIButton) {
        control.size = (control.size == IMAGESIZE_LOW) ? IMAGESIZE_HIGH : IMAGESIZE_LOW
        setResolution()
        updateImage()
    }

    func updateResolutionButton() { resolutionButton.setTitle(control.size == IMAGESIZE_LOW ? " Res: Low" : " Res: High", for: UIControlState.normal) }

    var juliaX:Float = 0.0
    var juliaY:Float = 0.0
    var juliaZ:Float = 0.0
    var lightX:Float = 0.0
    var lightY:Float = 0.0
    var lightZ:Float = 0.0

    var sList:[SliderView]! = nil
    var dList:[DeltaView]! = nil

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

        let szL = Int(IMAGESIZE_LOW)
        let textureDescriptorL = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: szL,
            height: szL,
            mipmapped: false)
        outTextureL = self.device.makeTexture(descriptor: textureDescriptorL)!
        threadGroupsL = MTLSizeMake(szL / threadGroupCount.width,szL / threadGroupCount.height,1)
        
        let szH = Int(IMAGESIZE_HIGH)
        let textureDescriptorH = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: szH,
            height: szH,
            mipmapped: false)
        outTextureH = self.device.makeTexture(descriptor: textureDescriptorH)!
        threadGroupsH = MTLSizeMake(szH / threadGroupCount.width,szH / threadGroupCount.height,1)

        cBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<Control>.stride, options: MTLResourceOptions.storageModeShared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        rotated()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sList = [ sZoom,sScaleFactor,sEpsilon,sJuliaZ,sLightZ,sSphere]
        dList = [ dSphere,dBox,dColorR,dColorG,dColorB,dJuliaXY,dLightXY ]

        sZoom.initializeFloat(&control.zoom, .delta, 0.2,2, 0.03, "Zoom")
        sScaleFactor.initializeFloat(&control.scaleFactor, .delta, -5.0,5.0, 0.3, "Scale Factor")
        sEpsilon.initializeFloat(&control.epsilon, .delta, 0.00001, 0.005, 0.001, "epsilon")
        
        dSphere.initializeFloat1(&control.sph1, 0,3,0.1 , "Sphere")
        dSphere.initializeFloat2(&control.sph2)
        dSphere.highlight(0.25,1)
        sSphere.initializeFloat(&control.sph3, .delta, 0.1,6.0,0.1, "Sphere M")
        
        dBox.initializeFloat1(&control.box1, 0,3,0.1, "Box")
        dBox.initializeFloat2(&control.box2)
        dBox.highlight(1,2)

        dColorR.initializeFloat1(&control.colorR1, 0,1,0.06, "R"); dColorR.initializeFloat2(&control.colorR2)
        dColorG.initializeFloat1(&control.colorG1, 0,1,0.06, "G"); dColorG.initializeFloat2(&control.colorG2)
        dColorB.initializeFloat1(&control.colorB1, 0,1,0.06, "B"); dColorB.initializeFloat2(&control.colorB2)

        dJuliaXY.initializeFloat1(&juliaX, -10,10, 1, "Julia XY"); dJuliaXY.initializeFloat2(&juliaY)
        sJuliaZ.initializeFloat(&juliaZ, .delta, -10,10,1, "Julia Z")

        dLightXY.initializeFloat1(&lightX, -1,1, 1, "Light XY"); dLightXY.initializeFloat2(&lightY)
        sLightZ.initializeFloat(&lightZ, .delta, -1,1,1, "Light Z")

        reset()
        
        timer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)
    }
    
    
    //MARK: -

    func reset() {
        control.size = IMAGESIZE_LOW
        setResolution()

        control.camera = vector_float3(0.38135, 2.3424, -0.380833)
        control.focus = vector_float3(-0.52,-1.22,-0.31)
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

        unWrapFloat3()
        
        for s in sList { s.setNeedsDisplay() }
        for d in dList { d.setNeedsDisplay() }
        
        updateImage()
    }
    
    func updateWidgets() {
        juliaOnOff.isOn = control.juliaboxMode
        unWrapFloat3()

        for s in sList { s.setNeedsDisplay() }
        for d in dList { d.setNeedsDisplay() }
        
        updateImage()
    }
    
    func setResolution() {
        let sz = Int(control.size)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: sz,
            height: sz,
            mipmapped: false)
        outTexture = self.device.makeTexture(descriptor: textureDescriptor)!
        
        threadGroups = MTLSizeMake(
            sz / threadGroupCount.width,
            sz / threadGroupCount.height,1)
        
        resolutionButton.setTitle(control.size == IMAGESIZE_LOW ? " Res: Low" : " Res: High", for: UIControlState.normal)
    }
    
    //MARK: -
    
    var oldXS:CGFloat = 0
    
    @objc func rotated() {
        var xs = view.bounds.width
        var ys = view.bounds.height
        
        if kludgeAutoLayout {
            xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
            ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y
        }

        if xs == oldXS { return }
        oldXS = xs
        
        let bys:CGFloat = 32    // slider height
        let gap:CGFloat = 10
        let cxs:CGFloat = 120
        let cxs2:CGFloat = (cxs * 2 - gap) / 3

        var sz:CGFloat = xs - 10
        var by:CGFloat = sz + 10  // top of widgets
        var x:CGFloat = 0
        var y = by

        func frame(_ xs:CGFloat, _ ys:CGFloat, _ dx:CGFloat, _ dy:CGFloat) -> CGRect {
            let r = CGRect(x:x, y:y, width:xs, height:ys)
            x += dx; y += dy
            return r
        }
        
        if ys > xs {    // portrait
            sz = xs - 10
            by = sz + 10  // top of widgets
            x = (xs - 730) / 2
            y = by

            imageView.frame = CGRect(x:5, y:5, width:sz, height:sz)

            sZoom.frame = frame(cxs,bys,0,bys + gap)
            sScaleFactor.frame = frame(cxs,bys,0,bys + gap)
            cTranslate.frame = frame(cxs,cxs,cxs + gap,0)
            y = by
            dSphere.frame = frame(cxs,cxs,0,cxs + gap)
            sSphere.frame  = frame(cxs,bys,0,bys + gap)
            dBox.frame = frame(cxs2,cxs2,cxs + gap,0)
            y = by
            dColorR.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            dColorG.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            dColorB.frame = frame(cxs2,cxs2,cxs2 + gap,0)
            y = by
            dJuliaXY.frame = frame(cxs,cxs,0,cxs + gap)
            sJuliaZ.frame  = frame(cxs,bys,0,bys + gap + 5)
            juliaOnOff.frame = frame(50,30,0,bys + gap)
            resetButton.frame = frame(50,bys,cxs + gap,0)
            y = by
            let x2 = x
            dLightXY.frame = frame(cxs,cxs,0,cxs + gap)
            sLightZ.frame  = frame(cxs,bys,0,bys + gap + 5)
            saveLoadButton.frame = frame(80,bys,0,bys + gap)
            helpButton.frame = frame(bys,bys,0,0)
            x = x2 + cxs + gap
            y = by
            resolutionButton.frame = frame(80,bys,0,bys + gap)
            sEpsilon.frame = frame(cxs,bys,0,bys + gap)
            cRotate.frame = frame(cxs,cxs,0,0)
        }
        else {          // landscape
            sz = ys - 10
            by = 50     // top of widgets
            let left = sz + 10
            x = left
            y = by
            
            imageView.frame = CGRect(x:5, y:5, width:sz, height:sz)
            
            sZoom.frame = frame(cxs,bys,0,bys + gap)
            sScaleFactor.frame = frame(cxs,bys,cxs + gap,0)
            y = by
            resolutionButton.frame = frame(80,bys,0,bys + gap)
            sEpsilon.frame = frame(cxs,bys,0,0)
            x = left
            y = by + 90
            dSphere.frame = frame(cxs,cxs,cxs + gap,0)
            dBox.frame = frame(cxs,cxs,0,cxs + gap)
            x = left
            sSphere.frame  = frame(cxs,bys,0,bys + gap)
            y = by + 260
            dColorR.frame = frame(cxs2,cxs2,cxs2 + gap,0)
            dColorG.frame = frame(cxs2,cxs2,cxs2 + gap,0)
            dColorB.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            x = left
            dJuliaXY.frame = frame(cxs,cxs,cxs + gap,0)
            dLightXY.frame = frame(cxs,cxs,0,cxs + gap)
            x = left
            sJuliaZ.frame  = frame(cxs,bys,cxs+gap,0)
            sLightZ.frame  = frame(cxs,bys,0,bys + gap)
            x = left
            juliaOnOff.frame = frame(50,30,cxs + gap,0)
            saveLoadButton.frame = frame(80,bys,0,bys+gap + 20)
            x = left
            resetButton.frame = frame(50,bys,0,bys + gap)
            helpButton.frame = frame(bys,bys,0,30)
            
            x = 10
            y = ys - cxs - 10
            cTranslate.frame = frame(cxs,cxs,0,0)
            x = xs - cxs - 10
            cRotate.frame = frame(cxs,cxs,0,0)
        }
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
        if cRotate.update() { refresh = true }
        for s in sList { if s.update() { refresh = true }}
        for d in dList { if d.update() { refresh = true }}

        if refresh { updateImage() }
    }
    
    //MARK: -
    
    func updateImage() {
        queue.async {
            self.calcRayMarch()
            DispatchQueue.main.async { self.imageView.image = self.image(from: self.outTexture) }
        }
    }
    
    //MARK: -
    
    func alterAngle(_ dx:Float, _ dy:Float) {
        let center:CGFloat = cRotate.bounds.width/2
        arcBall.mouseDown(CGPoint(x: center, y: center))
        arcBall.mouseMove(CGPoint(x: center + CGFloat(dx/10), y: center + CGFloat(dy/10)))
        
        let direction = simd_make_float4(0,0.1,0,0)
        let rotatedDirection = simd_mul(arcBall.transformMatrix, direction)
        
        control.focus.x = rotatedDirection.x
        control.focus.y = rotatedDirection.y
        control.focus.z = rotatedDirection.z
        control.focus += control.camera
        
        updateImage()
    }
    
    func alterPosition(_ dx:Float, _ dy:Float) {
        let diff = dy * (control.focus - control.camera) / 100.0
        control.camera -= diff
        control.focus -= diff
        
        updateImage()
    }
    
    //MARK: -

    func calcRayMarch() {
        wrapFloat3()

        cBuffer.contents().copyMemory(from: &control, byteCount:MemoryLayout<Control>.stride)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline1)
        commandEncoder.setTexture(outTexture, index: 0)
        commandEncoder.setBuffer(cBuffer, offset: 0, index: 0)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    //MARK: -
    // edit Scheme, Options, Metal API Validation : Disabled
    //the fix is to turn off Metal API validation under Product -> Scheme -> Options
    
    func image(from texture: MTLTexture) -> UIImage {
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        let bytesPerRow = texture.width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let context = CGContext(data: &src,
                                width: texture.width,
                                height: texture.height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        let dstImageFilter = context?.makeImage()
        
        return UIImage(cgImage: dstImageFilter!, scale: 0.0, orientation: UIImageOrientation.up)
    }
}
