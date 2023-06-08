

import UIKit

extension CIImage {
    func toSquare() -> CIImage {
        let image = UIImage(ciImage: self)
        let scale = image.scale
        let size = image.size
        let cropWidth = min(size.width, size.height)
        let cropRect = CGRect(
            x: (size.width - cropWidth) * scale / 2.0,
            y: (size.height - cropWidth) * scale / 2.0,
            width: cropWidth * scale,
            height: cropWidth * scale)
        return cropped(to: cropRect)
    }

    func addMaskCircle() -> CIImage {
        let radius = extent.size.width / 2
        let y = extent.origin.y + radius
        let x = extent.origin.x + radius
        let circle = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter" : CIVector(x: x, y: y),"inputRadius0": radius, "inputRadius1" : radius, "inputColor0" : CIColor(red: 1, green: 1, blue: 1, alpha: 1), "inputColor1" : CIColor(red: 0, green: 0, blue: 0, alpha: 1)])?.outputImage
        let mask = CIFilter(name: "CIMaskToAlpha", parameters: [kCIInputImageKey : circle!])?.outputImage
        let new = CIFilter(name: "CIBlendWithAlphaMask", parameters: [kCIInputMaskImageKey: mask!, kCIInputImageKey:self])?.outputImage
        return new!
    }

    func addMaskCircle(with width: CGFloat) -> CIImage {
        let suqareImage = square()
        let mask = suqareImage.maskCircle()
        let scale = width / mask.extent.size.width
        let target = mask.transformed(by:  CGAffineTransform(scaleX: scale, y: scale))
        return target
    }

    func resize(size: CGSize, byMax: Bool = false) -> CIImage {
        let srcWidth = CGFloat(extent.width)
        let srcHeight = CGFloat(extent.height)
        let dstWidth: CGFloat = size.width
        let dstHeight: CGFloat = size.height
        let scaleX = dstWidth / srcWidth
        let scaleY = dstHeight / srcHeight
        let scale = byMax ? max(scaleX, scaleY) : min(scaleX, scaleY)
        let transform = CGAffineTransform.init(scaleX: scale, y: scale)
        let output = transformed(by: transform).cropped(to: CGRect(x: 0, y: 0, width: dstWidth, height: dstHeight))
        return output
    }
}


extension CIImage {
    func toUIImage() -> UIImage {
        let context = CIContext()
        let cgimg = context.createCGImage(self, from: extent)
        return UIImage(cgImage: cgimg!)
    }

    func toPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        return toUIImage().pixelBuffer(width: width, height: height)
    }
}


extension CIImage {
    func toSegmentation() -> CIImage? {
        let selfWidth = extent.size.width
        let selfHeight = extent.size.height

        guard let pixBuffer = toPixelBuffer(width: 513, height: 513),
              let output = try? DeepLabV3Int8LUT().prediction(image: pixBuffer) else {
            return nil
        }

        do {
            let segmentations = SegmentationResultMLMultiArray(mlMultiArray: output.semanticPredictions)
            let depthPixelBuffer = try createMask(from: segmentations)

            guard  let resizeDepthPixelBuffer = resizePixelBuffer(depthPixelBuffer, width: Int(selfWidth), height: Int(selfHeight)) else {
                throw ImageError.errorWithReason
            }

            let depthMaskImage = CIImage(cvPixelBuffer: resizeDepthPixelBuffer, options: [:])
            let alphaMatte = depthMaskImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 5.0])
                .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.5])
            let parameters = ["inputMaskImage": alphaMatte]
            let target = applyingFilter("CIBlendWithMask", parameters: parameters)
            return target
        } catch {
            return nil
        }

    }

    private func createMask(from segmentations: SegmentationResultMLMultiArray) throws -> CVPixelBuffer {
        let width = segmentations.segmentationmapWidthSize
        let height = segmentations.segmentationmapHeightSize

        let pixelBuffer = try CVPixelBuffer.make(width: width, height: height, pixelFormat: kCVPixelFormatType_32BGRA)
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }

        let classBaseAddress = segmentations.mlMultiArray.dataPointer.bindMemory(to: Int32.self, capacity: segmentations.mlMultiArray.count)
        let bufferBaseAddress: UnsafeMutablePointer<UInt8> = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)

        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytesPerPixel: Int = 4

        for row in 0..<bufferHeight {
            let rowBaseAddress = bufferBaseAddress.advanced(by: row * bytesPerRow)
            for col in 0..<bufferWidth {
                let classValue = classBaseAddress[row * width + col]
                let colorComponent: UInt8 = classValue == 15 ? 255 : 0
                let pixel = rowBaseAddress.advanced(by: col * bytesPerPixel)
                pixel[0] = colorComponent
                pixel[1] = colorComponent
                pixel[2] = colorComponent
                pixel[3] = 255
            }
        }

        return pixelBuffer
    }
}
