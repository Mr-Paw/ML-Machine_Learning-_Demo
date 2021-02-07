//
//  ViewController.swift
//  ML Demo
//
//  Created by paw on 07.02.2021.
//

import UIKit
import Vision
import AVKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var requests: [VNCoreMLRequest] = []
    
//    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var categoryLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        view.layer.addSublayer(categoryLabel.layer)
        previewLayer.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        setupVision()
    }

    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: macipadiphone(configuration: MLModelConfiguration()).model)
            else { fatalError("Can't load VisionML model") }

        let request = VNCoreMLRequest(model: visionModel) { (request, error) in
            guard let results = request.results else { return }
            self.handleRequestResults(results)
        }

       requests = [request]
    }
    
    func handleRequestResults(_ results: [Any]) {
        let categoryText: String?

        defer {
            DispatchQueue.main.async {
                self.categoryLabel.text = categoryText
                print(categoryText as Any)
            }
        }

        guard let foundObject = results
            .compactMap({ $0 as? VNClassificationObservation })
            .first(where: { $0.confidence > 0.7 })
            else {
                categoryText = nil
                return
        }

        let category = foundObject.identifier//categoryTitle(identifier: foundObject.identifier)
        let confidence = "\(round(foundObject.confidence * 100 * 100) / 100)%"
        categoryText = "Это \(category)! С \(confidence)% вероятностью!"
    }
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
    
//        view.layer.addSublayer(categoryLabel.layer)
        var requestOptions: [VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
            attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
        }
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            options: requestOptions)

        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
}

