import UIKit
import Metal

//let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait
//let scrnIndex = 0
//let scrnLandscape:Bool = true

let IMAGESIZE_LOW:Int32 = 400
let IMAGESIZE_HIGH:Int32 = 3000

var control = Control()
var vc:ViewController! = nil

class ViewController: UIViewController {
    var cBuffer:MTLBuffer! = nil
    
    var timer = Timer()
    var outTexture: MTLTexture!
    let bytesPerPixel: Int = 4
    var pipeline1: MTLComputePipelineState!
    let queue = DispatchQueue(label: "Queue")
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    var circleMove:Bool = false

    let threadGroupCount = MTLSizeMake(20,20, 1)   // integer factor of SIZE
    var threadGroups = MTLSize()

    @IBOutlet var dCameraXY: DeltaView!
    @IBOutlet var sCameraZ: SliderView!
    @IBOutlet var dFocusXY: DeltaView!
    @IBOutlet var sFocusZ: SliderView!
    @IBOutlet var sZoom: SliderView!
    @IBOutlet var sScaleFactor: SliderView!
    @IBOutlet var sEpsilon: SliderView!
    @IBOutlet var dSphere: DeltaView!
    @IBOutlet var dBox: DeltaView!
    @IBOutlet var dColorR: DeltaView!
    @IBOutlet var dColorG: DeltaView!
    @IBOutlet var dColorB: DeltaView!
    @IBOutlet var dJuliaXY: DeltaView!
    @IBOutlet var sJuliaZ: SliderView!
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

    var cameraX:Float = 0.0
    var cameraY:Float = 0.0
    var cameraZ:Float = 0.0
    var focusX:Float = 0.0
    var focusY:Float = 0.0
    var focusZ:Float = 0.0
    var juliaX:Float = 0.0
    var juliaY:Float = 0.0
    var juliaZ:Float = 0.0
    
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

        cBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<Control>.stride, options: MTLResourceOptions.storageModeShared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        rotated()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        sList = [ sCameraZ,sFocusZ,sZoom,sScaleFactor,sEpsilon,sJuliaZ]
        dList = [ dCameraXY,dFocusXY,dSphere,dBox,dColorR,dColorG,dColorB,dJuliaXY ]

        let cameraRange:Float = 20
        let cameraJog:Float = 0.25
        dCameraXY.initializeFloat1(&cameraX, -cameraRange,cameraRange,cameraJog, "Camera XY")
        dCameraXY.initializeFloat2(&cameraY)
        sCameraZ.initializeFloat(&cameraZ, .delta, -cameraRange,cameraRange,cameraJog, "Camera Z")
        dFocusXY.initializeFloat1(&focusX, -cameraRange,cameraRange,cameraJog, "Focus XY")
        dFocusXY.initializeFloat2(&focusY)
        sFocusZ.initializeFloat(&focusZ, .delta, -cameraRange,cameraRange,cameraJog, "Focus Z")
        
        sZoom.initializeFloat(&control.zoom, .delta, 0.2,2, 0.03, "Zoom")
        sScaleFactor.initializeFloat(&control.scaleFactor, .delta, 2.0,5.0, 0.03, "Scale Factor")
        sEpsilon.initializeFloat(&control.epsilon, .delta, 0.00001, 0.005, 0.001, "epsilon")
        
        dSphere.initializeFloat1(&control.sph1, 0.002,2,0.1 , "Sphere")
        dSphere.initializeFloat2(&control.sph2)
        dSphere.highlight(0.25,1)
        dBox.initializeFloat1(&control.box1, 0.1,3,0.1, "Box")
        dBox.initializeFloat2(&control.box2)
        dBox.highlight(1,2)

        dColorR.initializeFloat1(&control.colorR1, 0,1,0.06, "R"); dColorR.initializeFloat2(&control.colorR2)
        dColorG.initializeFloat1(&control.colorG1, 0,1,0.06, "G"); dColorG.initializeFloat2(&control.colorG2)
        dColorB.initializeFloat1(&control.colorB1, 0,1,0.06, "B"); dColorB.initializeFloat2(&control.colorB2)

        dJuliaXY.initializeFloat1(&juliaX, -10,10, 1, "Julia XY"); dJuliaXY.initializeFloat2(&juliaY)
        sJuliaZ.initializeFloat(&juliaZ, .delta, -10,10,1, "Julia Z")

        reset()
        
        timer = Timer.scheduledTimer(timeInterval: 1.0/30.0, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)
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
        let xs:CGFloat = view.bounds.width
        let ys:CGFloat = view.bounds.height
//        let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
//        let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y

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
            x = (xs - 600) / 2
            y = by

            imageView.frame = CGRect(x:5, y:5, width:sz, height:sz)

            dCameraXY.frame = frame(cxs,cxs,0,cxs + gap)
            sCameraZ.frame  = frame(cxs,bys,0,bys + gap + 4)
            sZoom.frame = frame(cxs,bys,0,bys + gap)
            sScaleFactor.frame = frame(cxs,bys,cxs + gap,0)
            y = by
            dFocusXY.frame = frame(cxs,cxs,0,cxs + gap)
            sFocusZ.frame  = frame(cxs,bys,0,bys + gap + 4)
            resolutionButton.frame = frame(80,bys,0,bys + gap)
            sEpsilon.frame = frame(cxs,bys,cxs + gap,0)
            y = by
            dSphere.frame = frame(cxs,cxs,0,cxs + gap)
            dBox.frame = frame(cxs,cxs,cxs + gap,0)
            y = by
            dColorR.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            dColorG.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            dColorB.frame = frame(cxs2,cxs2,cxs2 + gap,0)
            y = by
            dJuliaXY.frame = frame(cxs,cxs,0,cxs + gap)
            sJuliaZ.frame  = frame(cxs,bys,0,bys + gap + 5)
            
            let x2 = x
            juliaOnOff.frame = frame(50,30,80,0)
            resetButton.frame = frame(50,bys,0,bys+gap)
            x = x2
            saveLoadButton.frame = frame(80,bys,100,0)
            helpButton.frame = frame(bys,bys,0,0)
        }
        else {          // landscape
            sz = ys - 10
            by = 5  // top of widgets
            let left = sz + 10
            x = left
            y = by
            
            imageView.frame = CGRect(x:5, y:5, width:sz, height:sz)
            
            dCameraXY.frame = frame(cxs,cxs,0,cxs + gap)
            sCameraZ.frame  = frame(cxs,bys,0,bys + gap + 4)
            sZoom.frame = frame(cxs,bys,0,bys + gap)
            sScaleFactor.frame = frame(cxs,bys,cxs + gap,0)
            y = by
            dFocusXY.frame = frame(cxs,cxs,0,cxs + gap)
            sFocusZ.frame  = frame(cxs,bys,0,bys + gap)
            resolutionButton.frame = frame(80,bys,0,bys + gap)
            sEpsilon.frame = frame(cxs,bys,0,0)
            x = left
            y = by + 260
            dSphere.frame = frame(cxs,cxs,0,cxs + gap)
            dBox.frame = frame(cxs,cxs,cxs + gap,0)
            y = by + 260
            dColorR.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            dColorG.frame = frame(cxs2,cxs2,0,cxs2 + gap)
            dColorB.frame = frame(cxs2,cxs2,0,0)
            x = left
            y = by + 520
            dJuliaXY.frame = frame(cxs,cxs,0,cxs + gap)
            sJuliaZ.frame  = frame(cxs,bys,0,bys+gap)
            juliaOnOff.frame = frame(50,30,cxs + gap,0)
            y = by + 520
            resetButton.frame = frame(50,bys,0,bys+gap*2)
            saveLoadButton.frame = frame(80,bys,30,bys+gap*2)
            helpButton.frame = frame(bys,bys,0,0)
        }
    }
    
    //MARK: -
    
    func unWrapFloat3() {
        cameraX = control.camera.x
        cameraY = control.camera.y
        cameraZ = control.camera.z
        focusX = control.focus.x
        focusY = control.focus.y
        focusZ = control.focus.z
        juliaX = control.julia.x
        juliaY = control.julia.y
        juliaZ = control.julia.z
    }
    
    func wrapFloat3() {
        control.camera.x = cameraX
        control.camera.y = cameraY
        control.camera.z = cameraZ
        control.focus.x = focusX
        control.focus.y = focusY
        control.focus.z = focusZ
        control.julia.x = juliaX
        control.julia.y = juliaY
        control.julia.z = juliaZ
    }
    
    //MARK: -

    @objc func timerHandler() {
        var refresh:Bool = false
        for s in sList { if s.update() { refresh = true }}
        for d in dList { if d.update() { refresh = true }}

        if refresh { updateImage() }
    }
    
    func updateImage() {
        queue.async {
            self.calcRayMarch()
            DispatchQueue.main.async { self.imageView.image = self.image(from: self.outTexture) }
        }
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
