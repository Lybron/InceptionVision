//
//  ViewController.swift
//  Inception
//
//  Created by Lybron Sobers on 6/21/17.
//  Copyright © 2017 Lybron Sobers. All rights reserved.
//

import UIKit
import CoreML
import Vision
import CoreMedia

class ViewController: UIViewController {
  
  @IBOutlet weak var classificationLabel: UILabel!
  @IBOutlet weak var probabilityLabel: UILabel!
  @IBOutlet weak var cameraPreview: UIView!
  
  // MARK: Properties
  let model = Inceptionv3()
  
  private var videoCapture: VideoCapture!
  private let classifyVideoView: ClassifyVideoView = {
    let view = ClassifyVideoView(frame: .zero)
    return view
  }()
  
  // MARK: View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
//    classifyVideoView.frame = cameraPreview.frame
//    cameraPreview = classifyVideoView
    
    let spec = VideoSpec(fps: 10, size: CGSize(width: 299, height: 299))
    videoCapture = VideoCapture(cameraType: .back,
                                preferredSpec: spec,
                                previewContainer: cameraPreview.layer)
    
    videoCapture.imageBufferHandler = { [unowned self] (imageBuffer) in
//      self.classifyFromSampleBuffer(imageBuffer)
      self.classifyVideoSample(sampleBuffer: imageBuffer)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    guard let videoCapture = videoCapture else {return}
    videoCapture.startCapture()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard let videoCapture = videoCapture else {return}
    videoCapture.resizePreview()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    guard let videoCapture = videoCapture else {return}
    videoCapture.stopCapture()
    
    navigationController?.setNavigationBarHidden(false, animated: true)
    super.viewWillDisappear(animated)
  }
  
  // MARK: Core ML
  private func classifyFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    
    guard let result = try? model.prediction(image: pixelBuffer) else {
      print("classification error: model.prediction()")
      return
    }
    
    classificationLabel.text = result.classLabel
    probabilityLabel.text = "\(result.classLabelProbs)"
    
  }
  
  func classifyImage(image: UIImage, completion: @escaping (_ success: Bool) -> Void) {
    // NOTE: Do any pre-processing on background thread
    DispatchQueue.global(qos: .background).async {
      guard let normalizedImage = image.resize(newSize: CGSize(width: 299, height: 299)), let imageData = normalizedImage.pixelBuffer() else {
        completion(false)
        return
      }
      
      guard let result = try? self.model.prediction(image: imageData) else {
        print("there was an error in classifying the image")
        completion(false)
        return
      }
      
      self.classificationLabel.text = result.classLabel
      self.probabilityLabel.text = "\(result.classLabelProbs)"
      
      completion(true)
    }
  }
  
  // Vision
  // NOTE: Only support back camera (impulseadventure.com/photo/exif-orientation.html)
  var exifOrientationFromDeviceOrientation: Int32 {
    let exifOrientation: DeviceOrientation
    enum DeviceOrientation: Int32 {
      case top0ColLeft = 1
      case top0ColRight = 2
      case bottom0ColRight = 3
      case bottom0ColLeft = 4
      case left0ColTop = 5
      case right0ColTop = 6
      case right0ColBottom = 7
      case left0ColBottom = 8
    }
    switch UIDevice.current.orientation {
    case .portraitUpsideDown:
      exifOrientation = .left0ColBottom
    case .landscapeLeft:
      exifOrientation = .top0ColLeft
    case .landscapeRight:
      exifOrientation = .bottom0ColRight
    default:
      exifOrientation = .right0ColTop
    }
    return exifOrientation.rawValue
  }
  
  func classifyVideoSample(sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }
    
    guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else {
      fatalError("could not load Inception model")
    }
    
    // Create a Vision request with completion handler
    let request = VNCoreMLRequest(model: model) { [weak self] request, error in
      guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
        fatalError("unexpected result type from VNCoreMLRequest")
      }
      
      DispatchQueue.main.async {
        self?.classificationLabel.text = "\(topResult.identifier)"
        self?.probabilityLabel.text = "Confidence: \(Int(topResult.confidence * 100))%"
      }
    }
    
    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: self.exifOrientationFromDeviceOrientation, options: getOptionsForImageBuffer(pixelBuffer))
    do {
      try imageRequestHandler.perform([request])
    } catch {
      print(error)
    }
  }
  
  func getOptionsForImageBuffer(_ imageBuffer: CVImageBuffer) -> [VNImageOption:Any] {
    var requestOptions: [VNImageOption:Any] = [:]
    if let cameraIntrinsicData = CMGetAttachment(imageBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
      requestOptions = [.cameraIntrinsics:cameraIntrinsicData]
    }
    return requestOptions
  }
}

extension ViewController {
  func detectScene(image: CIImage){
    classificationLabel.text = "Detecting scene..."
    
    // Load ML model through its generated class
    guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else {
      fatalError("could not load Inception model")
    }
    
    // Create a Vision request with completion handler
    let request = VNCoreMLRequest(model: model) { [weak self] request, error in
      guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
        fatalError("unexpected result type from VNCoreMLRequest")
      }
      
      // Update UI on main queue
      DispatchQueue.main.async {
        self?.classificationLabel.text = "\(topResult.identifier)"
        self?.probabilityLabel.text = "\(Int(topResult.confidence * 100))%"
      }
      
      // Run CoreML Inception classifier on global queue
      let handler = VNImageRequestHandler(ciImage: image)
      DispatchQueue.global(qos: .userInteractive).async {
        do {
          try handler.perform([request])
        } catch {
          print(error)
        }
      }
    }
  }
}

