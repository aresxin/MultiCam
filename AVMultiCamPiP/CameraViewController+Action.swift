

import Foundation

extension ViewController {
    @IBAction func actionMixCircle() {
        mix = .circle
        updateMTKView()
    }

    @IBAction func actionMixDepth() {
        mix = .depth
        updateMTKView()
    }

    @IBAction func actionMixSquare() {
        mix = .square
        updateMTKView()
    }
}
