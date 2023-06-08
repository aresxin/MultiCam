

import UIKit
import Photos


extension ViewController {
    func getCurrentCVPixelBuffer() -> CVPixelBuffer? {
        var currentImage: CIImage?
        switch mix {
        case .circle:
            currentImage = getCircle()
        case .depth:
            currentImage = getDepth()
        case .square:
            currentImage = getSquare()
        }
        
        return currentImage?.toCVPixelBuffer()
    }


    func getCircle() -> CIImage? {
        guard let back = backRendererImage,  let front = frontRendererImage else {
            return nil
        }
        let drawX = frontMtkView.frame.origin.x * MixMode.scale

        let drawY: CGFloat = (metalContainer.frame.size.height - (frontMtkView.frame.size.height + frontMtkView.frame.origin.y)) * MixMode.scale - front.extent.origin.y
        let transformed = front.transformed(by: CGAffineTransform(translationX: drawX, y: drawY))
        let renderImage = transformed.composited(over: back)
        return renderImage
    }

    func getDepth() -> CIImage?  {
        guard let back = backRendererImage,  let front = frontRendererImage else {
            return nil
        }
        let drawX = frontMtkView.frame.origin.x * MixMode.scale
        let drawY: CGFloat = (metalContainer.frame.size.height - (frontMtkView.frame.size.height + frontMtkView.frame.origin.y)) * MixMode.scale - front.extent.origin.y
        let transformed = front.transformed(by: CGAffineTransform(translationX: drawX, y: drawY))
        let renderImage = transformed.composited(over: back)
        return renderImage
    }

    func getSquare() -> CIImage? {
        guard let back = backRendererImage,  let front = frontRendererImage else {
            return nil
        }
        var renderImage = CIImage(color: CIColor(color: UIColor.black))
        let frontTransformed = front.transformed(by: CGAffineTransform(translationX: 0, y: 0))
        renderImage = frontTransformed.composited(over: renderImage)

        let y = (frontMtkView.frame.size.height) * MixMode.scale
        let backTransformed  = back.transformed(by: CGAffineTransform(translationX: 0, y: y))
        renderImage = backTransformed.composited(over: renderImage)


        let canvasWidth = back.extent.width
        let canvaHeight = back.extent.height + front.extent.height + MixMode.scale
        renderImage = renderImage.cropped(to: CGRect(x: 0, y: 0, width: canvasWidth, height: canvaHeight))
        return renderImage
    }
}

extension ViewController {
    func processMYVideoSampleBuffer(_ fullScreenSampleBuffer: CMSampleBuffer) {
        guard let r = metalRecorder, r.isRecording else {
            return
        }
        guard renderingEnabled else {
            return
        }

        guard let mixedPixelBuffer = getCurrentCVPixelBuffer() else {
            return
        }

        metalRecorder?.recordVideo(pixelBuffer: mixedPixelBuffer, presentationTime: CMSampleBufferGetPresentationTimeStamp(fullScreenSampleBuffer))
    }

}
