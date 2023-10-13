//
//  ViewController.swift
//  QRScanner
//
//  Created by Manikanta Sirumalla on 25/08/23.
//

import UIKit
import AVFoundation
import CoreImage

public class QRScannerViewController: UIViewController {
    private var captureSession: AVCaptureSession?
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession!)
        layer.frame = view.layer.bounds
        return layer
    }()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCamera()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            showCameraSetupError(.noCameraAvailable)
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: captureDevice)
            if captureSession!.canAddInput(videoInput) {
                captureSession!.addInput(videoInput)
            } else {
                showCameraSetupError(.inputNotSupported)
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession!.canAddOutput(metadataOutput) {
                captureSession!.addOutput(metadataOutput)
            } else {
                showCameraSetupError(.outputNotSupported)
                return
            }
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
            
            view.layer.addSublayer(previewLayer)
            captureSession!.startRunning()
            
        } catch {
            showCameraSetupError(.inputNotSupported)
        }
    }
    
    private func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }
    
    private func stopCamera() {
        captureSession?.stopRunning()
    }
    
    public static func generateImageFromQRCode(metadataObject: AVMetadataMachineReadableCodeObject) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(metadataObject as! CMSampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            
            UIGraphicsBeginImageContextWithOptions(uiImage.size, false, uiImage.scale)
            uiImage.draw(at: CGPoint.zero)
            
            let boundingBox = metadataObject.bounds
            let path = UIBezierPath(rect: boundingBox)
            UIColor.green.setStroke()
            path.lineWidth = 2.0
            path.stroke()
            
            let imageWithBoundingBox = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return imageWithBoundingBox
        }
        return nil
    }
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    // Rest of the AVCaptureMetadataOutputObjectsDelegate methods...
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let _ = metadataObject.stringValue else {
            return
        }
        captureSession?.stopRunning()
        
        // Transition to a new view controller to display the QR code and bounding box
        if let qrCodeDisplayVC = QRDisplayViewController(qrCodeMetadataObject: metadataObject, qrCodeImage: QRScannerViewController.generateImageFromQRCode(metadataObject: metadataObject))
            
        {
            navigationController?.pushViewController(qrCodeDisplayVC, animated: true)
        }
    }
}

class QRDisplayViewController: UIViewController {
    var qrCodeImageView: UIImageView!

    init?(qrCodeMetadataObject: AVMetadataMachineReadableCodeObject, qrCodeImage: UIImage?) {
        super.init(nibName: nil, bundle: nil)

        guard let image = qrCodeImage else {
            return nil
        }

        qrCodeImageView = UIImageView(image: image)
        qrCodeImageView.contentMode = .scaleAspectFit
        qrCodeImageView.frame = qrCodeMetadataObject.bounds

        view.addSubview(qrCodeImageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension QRScannerViewController {
    enum CameraError: Error {
        case noCameraAvailable
        case inputNotSupported
        case outputNotSupported
        
        var localizedDescription: String {
            switch self {
            case .noCameraAvailable:
                return "No camera is available on this device."
            case .inputNotSupported:
                return "The camera input is not supported."
            case .outputNotSupported:
                return "The metadata output is not supported."
            }
        }
    }
    
    private func showCameraSetupError(_ error: CameraError) {
        DispatchQueue.main.async {
            let ac = UIAlertController(title: "Camera Setup Error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(ac, animated: true)
            self.captureSession = nil
        }
    }
}
