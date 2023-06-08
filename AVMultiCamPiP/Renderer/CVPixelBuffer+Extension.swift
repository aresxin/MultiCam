
import UIKit


public extension CVPixelBuffer {
    enum CompatibilityType: Int {
           case bitmap
           case metal
           case openGL
           case openGLES
           case none

           public var attribute: [String: Any] {
               switch self {
               case .bitmap:
                   return [kCVPixelBufferCGBitmapContextCompatibilityKey: true] as [String: Any]
               case .metal:
                   return [kCVPixelBufferMetalCompatibilityKey: true] as [String: Any]
               case .openGL:
                   return [kCVPixelBufferOpenGLCompatibilityKey: true] as [String: Any]
               case .openGLES:
                   return [kCVPixelBufferOpenGLESCompatibilityKey: true] as [String: Any]
               case .none:
                   return [:]
               }
           }
       }


    static func make(width: Int, height: Int, pixelFormat: OSType, compatibility: CompatibilityType = .none) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        var attributes = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
            ] as [String: Any]

        for (key, value) in compatibility.attribute {
            attributes[key] = value
        }

        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attributes as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            throw ImageError.errorWithReason
        }

        return pixelBuffer!
    }

}
