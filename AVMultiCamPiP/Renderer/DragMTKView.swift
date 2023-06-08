

import MetalKit
class DragMTKView: MTKView {
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        addGesture()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


// MAKR: Gesture
extension DragMTKView {
    private func addGesture() {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(wasDragged(_:)))
        addGestureRecognizer(gesture)
        gesture.delegate = self
    }

    @objc func wasDragged(_ gestureRecognizer: UIPanGestureRecognizer) {

        if gestureRecognizer.state == UIGestureRecognizer.State.began || gestureRecognizer.state == UIGestureRecognizer.State.changed {

            let translation = gestureRecognizer.translation(in: self)

            let oldCenter = center


            center = CGPoint(x: gestureRecognizer.view!.center.x + translation.x, y: gestureRecognizer.view!.center.y + translation.y)

            if !superview!.bounds.contains(frame) {
                center = oldCenter
            }

            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self)
        }
    }
}

extension DragMTKView: UIGestureRecognizerDelegate {

}
