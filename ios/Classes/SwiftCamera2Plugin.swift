import Flutter
import UIKit
import AVKit

public class SwiftCamera2Plugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.sonerik.camera2", binaryMessenger: registrar.messenger())
        let instance = SwiftCamera2Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let cameraProviderHolder = CameraProviderHolder()
        let factory = CameraPreviewFactory(messenger: registrar.messenger(), cameraProviderHolder: cameraProviderHolder)
        registrar.register(factory, withId: "cameraPreview")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasCameraPermission":
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) == AVAuthorizationStatus.authorized {
                result(true)
            } else {
                result(false)
            }
        default: result(FlutterMethodNotImplemented)
        }
    }
}

private class CameraProviderHolder {
    private var session: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "capture session queue", qos: .userInitiated)
    
    private var activePreviewIds = [Int64]()
    private let activePreviews = NSMapTable<NSNumber, CameraPreviewView>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    
    func onPreviewCreated(viewId: Int64, previewView: CameraPreviewView) {
        if (session == nil) {
            session = AVCaptureSession()
        }
//        detachLastPreview()
        previewView.captureSession = session

        if (activePreviews.count == 0) {
            prepareSession(session: session!)
            sessionQueue.async { [weak self] in
                self?.session?.startRunning()
            }
        }

        activePreviews.setObject(previewView, forKey: NSNumber(value: viewId))
        activePreviewIds.append(viewId)
    }
    
    func onPreviewDisposed(viewId: Int64) {
//        detachLastPreview()
        activePreviews.removeObject(forKey: NSNumber(value: viewId))
        if let idIndex = activePreviewIds.firstIndex(of: viewId) {
            activePreviewIds.remove(at: idIndex)
        }
        
        if (activePreviews.count == 0) {
            let s = session
            sessionQueue.async {
                s?.stopRunning()
            }
            session = nil
        } else {
            if let lastId = activePreviewIds.last {
                activePreviews.object(forKey: NSNumber(value: lastId))?.captureSession = session
            }
        }
    }
    
    func detachLastPreview() {
        guard let viewId = activePreviewIds.last else {
            return
        }
        let lastActivePreview = activePreviews.object(forKey: NSNumber(value: viewId))
        DispatchQueue.main.async {
            lastActivePreview?.captureSession = nil
        }
    }
    
    func prepareSession(session: AVCaptureSession) {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        let videoDevice = AVCaptureDevice.devices(for: AVMediaType.video).first { (device) -> Bool in
            device.position == AVCaptureDevice.Position.back
        }
        let videoDeviceInput: AVCaptureDeviceInput!
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch let error as NSError {
            videoDeviceInput = nil
            NSLog("Could not create video device input: %@", error)
        } catch _ {
            fatalError()
        }
        
        let stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
        
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
        }
        if session.canAddOutput(stillImageOutput) {
            session.addOutput(stillImageOutput)
        }
        session.commitConfiguration()
    }
}

private class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger?
    private let cameraProviderHolder: CameraProviderHolder?
    
    init(messenger: FlutterBinaryMessenger, cameraProviderHolder: CameraProviderHolder) {
        self.messenger = messenger
        self.cameraProviderHolder = cameraProviderHolder
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        let view = CameraPreviewView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            onDispose: {
                self.cameraProviderHolder?.onPreviewDisposed(viewId: viewId)
            }
        )
        cameraProviderHolder?.onPreviewCreated(viewId: viewId, previewView: view)
        return view
    }
}

private class CameraPreviewView: NSObject, FlutterPlatformView {
    private var _view: UIPreviewView
    private let _viewId: Int64
    private let _onDispose: (() -> Void)?
    
    var captureSession: AVCaptureSession? {
        get { return _view.videoPreviewLayer.session }
        set { _view.videoPreviewLayer.session = newValue }
    }
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        onDispose: (() -> Void)?
    ) {
        _view = UIPreviewView()
        _view.videoPreviewLayer.videoGravity = .resizeAspectFill

        _viewId = viewId
        _onDispose = onDispose
        super.init()
        
        let channel = FlutterMethodChannel(name: "dev.sonerik.camera2/preview_\(viewId)", binaryMessenger: messenger!)
        channel.setMethodCallHandler({[weak self] (call: FlutterMethodCall, result: FlutterResult) -> Void in
            self?.handleMethodCall(call: call, result: result)
        })
    }
    
    deinit {
        NSLog("deinit: \(_viewId)")
        if let onDispose = _onDispose {
            onDispose()
        }
    }
    
    func view() -> UIView {
        return _view
    }
    
    func handleMethodCall(call: FlutterMethodCall, result: FlutterResult) -> Void {
        NSLog("call: \(call.method)")
    }
}

private class UIPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    /// Convenience wrapper to get layer as its statically known type.
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
