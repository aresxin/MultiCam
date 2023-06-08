

#if canImport(UIKit)

import UIKit

extension UIImage {
  /**
    Resizes the image.

    - Parameters:
      - scale: If this is 1, `newSize` is the size in pixels.
  */
  @nonobjc public func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    let image = renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
    return image
  }
  /**
    Rotates the image.

    - Parameters:
      - degrees: Rotation angle in degrees.
  */
  @nonobjc public func rotate(degrees: CGFloat) -> UIImage {
      let radians = CGFloat(degrees * .pi) / 180.0 as CGFloat
      var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: radians)).size
      // Trim off the extremely small float value to prevent core graphics from rounding it up
      newSize.width = floor(newSize.width)
      newSize.height = floor(newSize.height)
      let renderer = UIGraphicsImageRenderer(size:self.size)
      let image = renderer.image { rendererContext in
          let context = rendererContext.cgContext
          //rotate from center
          context.translateBy(x: newSize.width/2, y: newSize.height/2)
          context.rotate(by: radians)
          draw(in:  CGRect(origin: CGPoint(x: -self.size.width/2, y: -self.size.height/2), size: size))
      }
      return image
  }

}

#endif
