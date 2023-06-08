

import UIKit
import MetalKit

enum MixMode {
    case square
    case circle
    case depth

    static let circleWidth: CGFloat = 180
    static var canvasRect: CGRect = .zero

    static var mCircleWidth: CGFloat {
        return MixMode.circleWidth * 2
    }



    static let depthWidth: CGFloat = UIScreen.main.bounds.size.width - 120
    static let depthHeight: CGFloat = depthWidth * (4/3)

    static let scale: CGFloat = UIScreen.main.scale
    static var mCanvasSize: CGSize {
        return CGSize(width: MixMode.canvasRect.size.width * scale, height: MixMode.canvasRect.size.height * scale)
    }

    static var mSquareSize: CGSize {
        let width = canvasRect.size.width
        let height = (canvasRect.size.height - 1) / 2
        return CGSize(width: width * scale, height: height * scale)
    }


    func rendererRect(_ front: Bool, canvasRect: CGRect) -> CGRect {
        switch self {
        case .circle:
            if front {
                return CGRect(x: canvasRect.size.width - MixMode.circleWidth - 20, y: 100, width: MixMode.circleWidth, height: MixMode.circleWidth)
            } else {
                return canvasRect
            }
        case .depth:
            if front {
                let y = canvasRect.size.height - MixMode.depthHeight - 40
                let x = (canvasRect.size.width - MixMode.depthWidth) / 2
                return CGRect(x: x, y: y, width: MixMode.depthWidth, height: MixMode.depthHeight)
            } else {
                return canvasRect
            }
        case .square:
            let width = canvasRect.size.width
            let height = canvasRect.size.height / 2
            if front {
                return CGRect(x: 0, y: height, width: width, height: height)
            } else {
                return CGRect(x: 0, y: 0, width: width, height: height)
            }
        }
    }
}


extension ViewController {
    func renderer(in view: MTKView)  {
        switch view {
        case backMtkView:
            rendererBack()
        case frontMtkView:
            rendererFront()
        default:
            break
        }
    }

    func rendererBack()  {
        guard let image = backVideoImage else {
            return
        }
        switch mix {
        case .circle:
            let resizeImage = image.resize(size: CGSize(width: MixMode.mCanvasSize.width, height: MixMode.mCanvasSize.height))
            backRendererImage = resizeImage
            backRenderer.update(with: resizeImage)
        case .square:
            let resizeImage = image.resizeY(size: CGSize(width: MixMode.mSquareSize.width, height: MixMode.mSquareSize.height))
            backRendererImage = resizeImage
            backRenderer.update(with: resizeImage)
        case .depth:
            let resizeImage = image.resize(size: CGSize(width: MixMode.mCanvasSize.width, height: MixMode.mCanvasSize.height))
            UIGraphicsBeginImageContext(MixMode.mCanvasSize)
            let cgContext = UIGraphicsGetCurrentContext()
            // Clip area show video
            let path = UIBezierPath()
            path.move(to: CGPoint.init(x: 100 * MixMode.scale, y: 80 * MixMode.scale))
            path.addLine(to: CGPoint.init(x: 100 * MixMode.scale, y: 400 * MixMode.scale))
            path.addLine(to: CGPoint.init(x: 300 * MixMode.scale, y: 400 * MixMode.scale))
            path.close()
            path.addClip()
            // mask color white
            cgContext?.setFillColor(UIColor.white.cgColor)
            cgContext?.fill(CGRect.init(x: 0, y: 0, width: MixMode.mCanvasSize.width, height: MixMode.mCanvasSize.height))
            let maskImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            let mask = CIImage.init(image: maskImage!)


             let new = CIFilter(name: "CIBlendWithAlphaMask", parameters: [kCIInputMaskImageKey: mask!, kCIInputImageKey:resizeImage])?.outputImage
            backRendererImage = new
            backRenderer.update(with: new!)
        }
    }

    func rendererFront() {
        guard let image = frontVideoImage else {
            return
        }
        switch mix {
        case .circle:
            let circle = image.maskCircle(MixMode.mCircleWidth)
            frontRendererImage = circle
            frontRenderer.update(with: circle)
        case .depth:
            let nemImage = image.segmentation()
            let resizeImage = nemImage!.resizeY(size: CGSize(width: MixMode.depthWidth * MixMode.scale, height: MixMode.depthHeight * MixMode.scale))
            frontRendererImage = resizeImage
            frontRenderer.update(with: resizeImage)

            /*old
            let resizeImage = image.resizeY(size: CGSize(width: MixMode.depthWidth * MixMode.scale, height: MixMode.depthHeight * MixMode.scale))
            let image = resizeImage.toUIImage()
            if let segmentation = image.segmentation() {
                let filter = GraySegmentFilter()
                filter.inputImage = CIImage(cgImage: image.cgImage!)
                filter.maskImage = CIImage(cgImage: segmentation)
                let output = filter.value(forKey:kCIOutputImageKey) as! CIImage
                frontRendererImage = output
                frontRenderer.update(with: output)
            }
            */
        case .square:
            let resizeImage = image.resizeY(size: CGSize(width: MixMode.mSquareSize.width, height: MixMode.mSquareSize.height))
            frontRendererImage = resizeImage
            frontRenderer.update(with: resizeImage)
        }

    }
}

extension CIImage {
    func square() -> CIImage {
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

    func maskCircle() -> CIImage {
        let radius = extent.size.width / 2
        let y = extent.origin.y + radius
        let x = extent.origin.x + radius
        let circle = CIFilter(name: "CIRadialGradient", parameters: ["inputCenter" : CIVector(x: x, y: y),"inputRadius0": radius, "inputRadius1" : radius, "inputColor0" : CIColor(red: 1, green: 1, blue: 1, alpha: 1), "inputColor1" : CIColor(red: 0, green: 0, blue: 0, alpha: 1)])?.outputImage
        let mask = CIFilter(name: "CIMaskToAlpha", parameters: [kCIInputImageKey : circle!])?.outputImage
        let new = CIFilter(name: "CIBlendWithAlphaMask", parameters: [kCIInputMaskImageKey: mask!, kCIInputImageKey:self])?.outputImage
        return new!
    }

    func maskCircle(_ cropWidth: CGFloat) -> CIImage {
        let suqareImage = square()
        let mask = suqareImage.maskCircle()
        let scale = cropWidth / mask.extent.size.width
        let target = mask.transformed(by:  CGAffineTransform(scaleX: scale, y: scale))
        return target
    }

    func resize(size: CGSize) -> CIImage {
        let srcWidth = CGFloat(extent.width)
        let srcHeight = CGFloat(extent.height)
        let dstWidth: CGFloat = size.width
        let dstHeight: CGFloat = size.height
        let scaleX = dstWidth / srcWidth
        let scaleY = dstHeight / srcHeight
        let scale = min(scaleX, scaleY)
        let transform = CGAffineTransform.init(scaleX: scale, y: scale)
        let output = transformed(by: transform).cropped(to: CGRect(x: 0, y: 0, width: dstWidth, height: dstHeight))
        return output
    }

    func resizeY(size: CGSize) -> CIImage {
        let srcWidth = CGFloat(extent.width)
        let srcHeight = CGFloat(extent.height)
        let dstWidth: CGFloat = size.width
        let dstHeight: CGFloat = size.height
        let scaleX = dstWidth / srcWidth
        let scaleY = dstHeight / srcHeight
        let scale = max(scaleX, scaleY)
        let transform = CGAffineTransform.init(scaleX: scale, y: scale)
        let output = transformed(by: transform).cropped(to: CGRect(x: 0, y: 0, width: dstWidth, height: dstHeight))
        return output
    }
}




extension CIImage {
    func segmentation() -> CIImage? {
        let selfWidth = extent.size.width
        let selfHeight = extent.size.height
        let image = toUIImage()
        let pixBuffer = image.pixelBuffer(width: 513, height: 513)

        let deeplabV3 = DeepLabV3Int8LUT()
        guard let v3Output = try? deeplabV3.prediction(image: pixBuffer!) else {
            return nil
        }

        do {
            let segmentations = SegmentationResultMLMultiArray(mlMultiArray: v3Output.semanticPredictions)
            let depthPixelBuffer = try createMask(from: segmentations)
            let resizeDepthPixelBuffer = resizePixelBuffer(depthPixelBuffer, width: Int(selfWidth), height: Int(selfHeight))
            let depthMaskImage = CIImage(cvPixelBuffer: resizeDepthPixelBuffer!, options: [:])
            let alphaMatte = depthMaskImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 5.0])
                .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.5])
            let parameters = ["inputMaskImage": alphaMatte]
            let output = self.applyingFilter("CIBlendWithMask", parameters: parameters)
            return output
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
            // 每一行的像素个数, 并不一定等于 with * bytesPerPixel(4)
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
