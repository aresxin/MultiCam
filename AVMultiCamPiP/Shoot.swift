

import UIKit
import Photos

extension ViewController {
    func shoot() {
        switch mix {
        case .circle:
            shootCircle()
        case .depth:
            shootDepth()
        case .square:
            shootSquare()
        }
    }


    func shootCircle() {
        guard let back = backRendererImage,  let front = frontRendererImage else {
            return
        }
        let drawX = frontMtkView.frame.origin.x * MixMode.scale

        let drawY: CGFloat = (metalContainer.frame.size.height - (frontMtkView.frame.size.height + frontMtkView.frame.origin.y)) * MixMode.scale - front.extent.origin.y
        let transformed = front.transformed(by: CGAffineTransform(translationX: drawX, y: drawY))
        let renderImage = transformed.composited(over: back)
        showPhoto(renderImage)
    }

    func shootDepth()  {
        guard let back = backRendererImage,  let front = frontRendererImage else {
            return
        }
        let drawX = frontMtkView.frame.origin.x * MixMode.scale
        let drawY: CGFloat = (metalContainer.frame.size.height - (frontMtkView.frame.size.height + frontMtkView.frame.origin.y)) * MixMode.scale - front.extent.origin.y
        let transformed = front.transformed(by: CGAffineTransform(translationX: drawX, y: drawY))
        let renderImage = transformed.composited(over: back)
        showPhoto(renderImage)
    }

    func shootSquare() {
        guard let back = backRendererImage,  let front = frontRendererImage else {
            return
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

        showPhoto(renderImage)
    }
}


extension ViewController {
    func showPhoto(_ photo: CIImage)  {
        let image = photo.toUIImage()
        photoImageView.image = image
        photoImageView.isHidden = false
        ViewController.trySaveImage(image, inAlbumNamed: "PIP")
        delay(1) {
            self.photoImageView.isHidden = true
        }
    }
}





extension ViewController {
    class func trySaveImage(_ image: UIImage, inAlbumNamed: String) {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            if let album = album(named: inAlbumNamed) {
                saveImage(image, toAlbum: album)
            } else {
                createAlbum(withName: inAlbumNamed) {
                    if let album = album(named: inAlbumNamed) {
                        saveImage(image, toAlbum: album)
                    }
                }
            }
        }
    }

    fileprivate class func saveImage(_ image: UIImage, toAlbum album: PHAssetCollection) {
        PHPhotoLibrary.shared().performChanges({
            let changeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            let enumeration: NSArray = [changeRequest.placeholderForCreatedAsset!]
            albumChangeRequest?.addAssets(enumeration)
        })
    }

    fileprivate class func createAlbum(withName name: String, completion:@escaping () -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }, completionHandler: { success, _ in
            if success {
                completion()
            }
        })
    }

    fileprivate class func album(named: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", named)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album,
                                                                 subtype: .any,
                                                                 options: fetchOptions)
        return collection.firstObject
    }
}



public func delay(_ interval: TimeInterval, block: @escaping ()->()) {
    let delayTime = DispatchTime.now() + interval
    DispatchQueue.main.asyncAfter(deadline: delayTime) {
        block()
    }
}
