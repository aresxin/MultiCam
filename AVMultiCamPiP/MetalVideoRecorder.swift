

import Foundation
import AVKit

class MetalVideoRecorder {

    var isRecording = false
    var recordingStartTime = TimeInterval(0)


    fileprivate var prevTime: CMTime = .zero


    private var assetWriter: AVAssetWriter
    private var assetWriterVideoInput: AVAssetWriterInput
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor

    private var assetWriterAudioInput: AVAssetWriterInput


    init?(outputURL url: URL, size: CGSize) {
        do {
            let outputFileName = NSUUID().uuidString
            let outputFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(outputFileName).appendingPathExtension("MOV")

            debugPrint(url)
            assetWriter = try AVAssetWriter(outputURL: outputFileURL, fileType: AVFileType.m4v)
        } catch {
            return nil
        }
        
        let outputSettings: [String: Any] = [ AVVideoCodecKey : AVVideoCodecType.h264,
                                              AVVideoWidthKey : size.width,
                                              AVVideoHeightKey : size.height ]
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String : size.width,
            kCVPixelBufferHeightKey as String : size.height ]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput,
                                                                           sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        assetWriter.add(assetWriterVideoInput)



        // Add an audio input
        let audioSettings: [String: Any] = [
        AVFormatIDKey : kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey : 2,
        AVSampleRateKey : 44100.0,
        AVEncoderBitRateKey: 192000]

        assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        assetWriterAudioInput.expectsMediaDataInRealTime = true
        assetWriter.add(assetWriterAudioInput)
    }
    
    func startRecording() {
        isRecording = true
        return

//        assetWriter.startWriting()
//        assetWriter.startSession(atSourceTime: CMTime.zero)
//        
//        recordingStartTime = CACurrentMediaTime()
//        isRecording = true
    }



    private func startWritingIfNeeded(timestamp: CMTime) {
        guard assetWriter.status != .writing else { return }
        let result = assetWriter.startWriting()
        if !result {
            return
        }
        assetWriter.startSession(atSourceTime: timestamp)
        isRecording = true
    }
    
    func endRecording(completion: @escaping (URL) -> Void) {
        isRecording = false
        
        assetWriterVideoInput.markAsFinished()
        assetWriter.finishWriting {
            completion(self.assetWriter.outputURL)
        }
    }

    func recordVideo(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard isRecording else { return }
        startWritingIfNeeded(timestamp: presentationTime)
        guard isRecording,
            assetWriter.status == .writing,
            assetWriterVideoInput.isReadyForMoreMediaData, assetWriterPixelBufferInput.pixelBufferPool != nil else {
                return
        }



        if CMTimeCompare(presentationTime, self.prevTime) <= 0 { return }
        self.prevTime = presentationTime

//        let frameTime = CACurrentMediaTime() - recordingStartTime
//        let presentationTime = CMTimeMakeWithSeconds(frameTime, preferredTimescale: 240)
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: presentationTime)
    }

    func recordAudio(sampleBuffer: CMSampleBuffer) {
        guard isRecording,
            assetWriter.status == .writing,
            assetWriterAudioInput.isReadyForMoreMediaData else {
                return
        }

        assetWriterAudioInput.append(sampleBuffer)
    }
}
