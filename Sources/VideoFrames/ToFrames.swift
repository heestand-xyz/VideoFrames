import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import AVFoundation

//#if os(macOS)
//public func convertVideoToFrames(url: URL) throws -> [_Image] {
//
//}
//#endif

//public func convertVideoToFramesAsync(from url: URL, frame: @escaping (_Image) -> (), done: @escaping () -> ()) throws {
//    let generator: AVAssetImageGenerator = makeGenerator(url: url)
//    DispatchQueue.global(qos: .background).async {
//        func next() {
//
//        }
//        for i in 0..<info.frameCount {
//            let image: _Image = getFrame(at: i, info: info, with: generator)
//            DispatchQueue.main.async {
//                frame(image)
//            }
//        }
//    }
//}

public func convertVideoToFrames(from url: URL) throws -> [_Image] {
    var frames: [_Image] = []
//    let (VideoInfo...generator: AVAssetImageGenerator = try makeGenerator(from: url)
//    for i in 0..<info.frameCount {
//        let image: _Image = getFrame(at: i, info: info, with: generator)
//        frames.append(image)
//    }
    return frames
}

func makeGenerator(from url: URL) throws -> (VideoInfo, AVAssetImageGenerator) {
    let asset: AVAsset = AVAsset(url: url)
    guard let info: VideoInfo = VideoInfo(asset: asset) else {
        throw VideoFramesError.videoInfoFail
    }
    let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    return (info, generator)
}

func getFrame(at frameIndex: Int, info: VideoInfo, with generator: AVAssetImageGenerator) throws -> _Image {
    let seconds: Double = Double(frameIndex) / info.fps
    let time: CMTime = CMTimeMakeWithSeconds(seconds, preferredTimescale: Int32(NSEC_PER_SEC))
    let cgImage: CGImage = try generator.copyCGImage(at: time, actualTime: nil)
    #if os(macOS)
    let image: NSImage = NSImage(cgImage: cgImage, size: info.size)
    #else
    let image: UIImage = UIImage(cgImage: cgImage)
    #endif
    return image
}
