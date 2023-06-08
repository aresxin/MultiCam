
import UIKit

/**
 NAMESPACE: p
 MEANING: Pixel buffer render coordinate system
 */

/**
 NAMESPACE: v
 MEANING: view coordinate system
*/

/**
 NAMESPACE: w
 MEANING: width
 NAMESPACE: h
 MEANING: height
*/



struct PIPCanvas {
    // MARK: Constant
    private static let vDepthMargin: CGFloat = 60

    // MARK: Main Canvas Size
    private static let vMainW = UIScreen.main.bounds.size.width
    private static let vMainH = vMainW * (16/9)

    // MARK: Scale
    private static let scale: CGFloat = UIScreen.main.scale


    // MRAK: Circle Canvas Size
    static let vCircleW: CGFloat = 180
    static let pCircleW: CGFloat = vCircleW * 2


    // MRAK: Depth Canvas Size
    static let vDepthW: CGFloat = vMainW - (vDepthMargin * 2)
    static let vDepthH: CGFloat = vDepthW * (4/3)


    // MRAK: Pixel buffer size
    static let pMainW: CGFloat =  vMainW * scale
    static let pMainH: CGFloat = vMainH * scale
    static let pCanvasSize: CGSize = CGSize(width: pMainW, height: pMainH)

    // MRAK: Pixel buffer Square size
    static let pSquareSize: CGSize = CGSize(width: pMainW, height: pMainH / 2)

}
