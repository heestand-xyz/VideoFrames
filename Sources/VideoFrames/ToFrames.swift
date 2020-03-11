import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import AVFoundation

public func convertVideoToFrames(from url: URL) throws -> [_Image] {
    var frames: [_Image] = []
    let asset = try makeAsset(from: url)
    for i in 0..<asset.info.frameCount {
        let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
        frames.append(image)
    }
    return frames
}

public func convertVideoToFramesSync(from url: URL, frame: (_Image, Int) throws -> ()) throws {
    let asset = try makeAsset(from: url)
    for i in 0..<asset.info.frameCount {
        let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
        try frame(image, i)
    }
}

//public func convertVideoToFramesAsync(from url: URL, on queue: DispatchQueue = .main, frame: @escaping (_Image, Int) -> (), completion: @escaping (Result<Void, Error>) -> ()) throws {
//    let asset = try makeAsset(from: url)
//    var sum: Int = 0
//    var cancel: Bool = false
//    for i in 0..<asset.info.frameCount {
//        DispatchQueue.global().async {
//            guard !cancel else { return }
//            do {
//                let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
//                queue.async {
//                    guard !cancel else { return }
//                    frame(image, i)
//                    sum += 1
//                    if sum == asset.info.frameCount {
//                        completion(.success(()))
//                    }
//                }
//            } catch {
//                cancel = true
//                completion(.failure(error))
//            }
//        }
//    }
//}

func makeAsset(from url: URL) throws -> (info: VideoInfo, generator: AVAssetImageGenerator) {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw VideoFramesError.videoNotFound
    }
    let asset: AVAsset = AVAsset(url: url)
    guard let info: VideoInfo = VideoInfo(asset: asset) else {
        throw VideoFramesError.videoInfoFail
    }
    let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    return (info, generator)
}

func getFrame(at frameIndex: Int, info: VideoInfo, with generator: AVAssetImageGenerator) throws -> _Image {
    let time: CMTime = getTime(at: frameIndex, fps: info.fps)
    let cgImage: CGImage = try generator.copyCGImage(at: time, actualTime: nil)
    #if os(macOS)
    let image: NSImage = NSImage(cgImage: cgImage, size: info.size)
    #else
    let image: UIImage = UIImage(cgImage: cgImage)
    #endif
    return image
}

func getTime(at frameIndex: Int, fps: Double) -> CMTime {
    let seconds: Double = (Double(frameIndex) + 0.5) / fps
    return CMTimeMakeWithSeconds(seconds, preferredTimescale: Int32(NSEC_PER_SEC))
}
