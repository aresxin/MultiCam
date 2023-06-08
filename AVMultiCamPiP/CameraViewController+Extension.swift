

import Foundation
import MetalKit
import AVFoundation
import ImageIO


extension ViewController {
    func updateMTKView()  {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let canvas = metalContainer.bounds

        MixMode.canvasRect = metalContainer.bounds
        backMtkView.frame = mix.rendererRect(false, canvasRect: canvas)
        frontMtkView.frame = mix.rendererRect(true, canvasRect: canvas)

        photoImageView.frame = metalContainer.bounds
    }

    func setupMTKView() {
        let device = MTLCreateSystemDefaultDevice()!

        backMtkView = MTKView(frame: .zero, device: device)
        backMtkView.device = device
        backMtkView.backgroundColor = UIColor.clear
        backMtkView.delegate = self
        metalContainer.addSubview(backMtkView)
        backRenderer = MetalRenderer(metalDevice: device, renderDestination: backMtkView)


        frontMtkView = DragMTKView(frame: metalContainer.bounds, device: device)
        frontMtkView.device = device
        frontMtkView.backgroundColor = UIColor.clear
        frontMtkView.delegate = self
        metalContainer.addSubview(frontMtkView)
        frontRenderer = MetalRenderer(metalDevice: device, renderDestination: frontMtkView)




        photoImageView = UIImageView(frame: metalContainer.bounds)
        metalContainer.addSubview(photoImageView)
        photoImageView.isHidden = true

        updateMTKView()
    }
}

extension ViewController {
    func rendererBack(_ sampleBuffer: CMSampleBuffer) {
        guard let imagePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError() }
        backVideoImage = CIImage(cvPixelBuffer: imagePixelBuffer)
    }

    func rendererFront(_ sampleBuffer: CMSampleBuffer) {
        guard let imagePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { fatalError() }
        frontVideoImage = CIImage(cvPixelBuffer: imagePixelBuffer)
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }

    func draw(in view: MTKView) {
        renderer(in: view)
    }
}

extension ViewController {
    func depth(_ videoImage: CIImage) -> CIImage {
        let matte = CIImage(cgImage: videoImage.cgImage!, options: [.auxiliaryPortraitEffectsMatte : true])
        return matte
    }
}


extension ViewController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didDrop depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection, reason: AVCaptureOutput.DataDroppedReason) {
        print("\(self.classForCoder)/\(#function)")
    }

    // synchronizer使ってる場合は呼ばれない
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        print("\(self.classForCoder)/\(#function)")
    }
}


extension ViewController: AVCaptureDataOutputSynchronizerDelegate {

    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {

        guard let syncedVideoData = synchronizedDataCollection.synchronizedData(for: frontCameraVideoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        guard !syncedVideoData.sampleBufferWasDropped else {
            print("dropped video:\(syncedVideoData)")
            return
        }
        let videoSampleBuffer = syncedVideoData.sampleBuffer

        let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData
        var depthData = syncedDepthData?.depthData
        print("depthData is ---------\(String(describing: depthData))")
        if let syncedDepthData = syncedDepthData, syncedDepthData.depthDataWasDropped {
            print("dropped depth:\(syncedDepthData)")
            depthData = nil
        }

        // 顔のある位置のしきい値を求める
        let syncedMetaData = synchronizedDataCollection.synchronizedData(for: metadataOutput) as? AVCaptureSynchronizedMetadataObjectData
        var face: AVMetadataObject? = nil
        if let firstFace = syncedMetaData?.metadataObjects.first {
            face = frontCameraVideoDataOutput.transformedMetadataObject(for: firstFace, connection: frontVideoConnection)
            print("face is ------------\(String(describing: face))")
        }
        guard let imagePixelBuffer = CMSampleBufferGetImageBuffer(videoSampleBuffer) else { fatalError() }

        synchronizedDataBufferHandler(videoPixelBuffer: imagePixelBuffer, depthData: depthData, face: face)
    }
}

extension ViewController {
    func synchronizedDataBufferHandler(videoPixelBuffer: CVPixelBuffer, depthData: AVDepthData?, face: AVMetadataObject?)  {
        frontVideoImage = CIImage(cvPixelBuffer: videoPixelBuffer)
        //let videoWidth = CVPixelBufferGetWidth(videoPixelBuffer)
        //let videoHeight = CVPixelBufferGetHeight(videoPixelBuffer)
        //let captureSize = CGSize(width: videoWidth, height: videoHeight)

        DispatchQueue.main.async(execute: {
            self.serialQueue.async {
                guard let depthPixelBuffer = depthData?.depthDataMap else { return }
                self.processBuffer(videoPixelBuffer: videoPixelBuffer, depthPixelBuffer: depthPixelBuffer, face: face, shouldBinarize: true, shouldGamma: true)
            }
        })
    }

    func processBuffer(videoPixelBuffer: CVPixelBuffer, depthPixelBuffer: CVPixelBuffer, face: AVMetadataObject?, shouldBinarize: Bool, shouldGamma: Bool) {
        let videoWidth = CVPixelBufferGetWidth(videoPixelBuffer)
        let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)

        var depthCutOff: Float = 1.0
        if let face = face {
            let faceCenter = CGPoint(x: face.bounds.midX, y: face.bounds.midY)
            let scaleFactor = CGFloat(depthWidth) / CGFloat(videoWidth)
            let faceCenterDepth = readDepth(from: depthPixelBuffer, at: faceCenter, scaleFactor: scaleFactor)
            depthCutOff = faceCenterDepth + 0.25
        }

        // 二値化
        // Convert depth map in-place: every pixel above cutoff is converted to 1. otherwise it's 0
        if shouldBinarize {
            depthPixelBuffer.binarize(cutOff: depthCutOff)
        }

        // Create the mask from that pixel buffer.
        let depthImage = CIImage(cvPixelBuffer: depthPixelBuffer, options: [:])

        // Smooth edges to create an alpha matte, then upscale it to the RGB resolution.
        let alphaUpscaleFactor = Float(CVPixelBufferGetWidth(videoPixelBuffer)) / Float(depthWidth)
        let processedDepth: CIImage
        processedDepth = shouldGamma ? depthImage.applyBlurAndGamma() : depthImage

        self.frontVideoMaskImage = processedDepth.applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": alphaUpscaleFactor])
    }


    private func readDepth(from depthPixelBuffer: CVPixelBuffer, at position: CGPoint, scaleFactor: CGFloat) -> Float {
        let pixelX = Int((position.x * scaleFactor).rounded())
        let pixelY = Int((position.y * scaleFactor).rounded())

        CVPixelBufferLockBaseAddress(depthPixelBuffer, .readOnly)

        let rowData = CVPixelBufferGetBaseAddress(depthPixelBuffer)! + pixelY * CVPixelBufferGetBytesPerRow(depthPixelBuffer)
        let faceCenterDepth = rowData.assumingMemoryBound(to: Float32.self)[pixelX]
        CVPixelBufferUnlockBaseAddress(depthPixelBuffer, .readOnly)

        return faceCenterDepth
    }
}


extension CVPixelBuffer {

    func binarize(cutOff: Float) {
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        for yMap in 0 ..< height {
            let rowData = CVPixelBufferGetBaseAddress(self)! + yMap * CVPixelBufferGetBytesPerRow(self)
            let data = UnsafeMutableBufferPointer<Float32>(start: rowData.assumingMemoryBound(to: Float32.self), count: width)
            for index in 0 ..< width {
                let depth = data[index]
                if depth.isNaN {
                    data[index] = 1.0
                } else if depth <= cutOff {
                    // 前景
                    data[index] = 1.0
                } else {
                    // 背景
                    data[index] = 0.0
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
}


extension CIImage {
    func applyBlurAndGamma() -> CIImage {
        return clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 3.0])
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.5])
            .cropped(to: extent)
    }
}



extension AVCaptureDevice {
    private func formatWithHighestResolution(_ availableFormats: [AVCaptureDevice.Format]) -> AVCaptureDevice.Format?
    {
        var maxWidth: Int32 = 0
        var selectedFormat: AVCaptureDevice.Format?
        for format in availableFormats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = dimensions.width
            if width >= maxWidth {
                maxWidth = width
                selectedFormat = format
            }
        }
        return selectedFormat
    }

    func selectDepthFormat() {
        let availableFormats = formats.filter { format -> Bool in
            let validDepthFormats = format.supportedDepthDataFormats.filter{ depthFormat in
                return CMFormatDescriptionGetMediaSubType(depthFormat.formatDescription) == kCVPixelFormatType_DepthFloat32
            }
            return validDepthFormats.count > 0
        }
        guard let selectedFormat = formatWithHighestResolution(availableFormats) else { fatalError() }

        let depthFormats = selectedFormat.supportedDepthDataFormats
        let depth32formats = depthFormats.filter {
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        }
        guard !depth32formats.isEmpty else { fatalError() }
        let selectedDepthFormat = depth32formats.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        })!

        print("selected format: \(selectedFormat), depth format: \(selectedDepthFormat)")
        try! lockForConfiguration()
        activeFormat = selectedFormat
        activeDepthDataFormat = selectedDepthFormat
        unlockForConfiguration()
    }
}


