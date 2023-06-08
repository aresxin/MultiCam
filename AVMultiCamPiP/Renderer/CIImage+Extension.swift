

import UIKit

extension CIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(extent.width)
        let height = Int(extent.height)
        return toUIImage().pixelBuffer(width: width, height: height)
    }
}
