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

public func convertVideoToFramesAsync(from url: URL, frame: @escaping (_Image, Int) -> (), done: @escaping () -> (), failed: @escaping (Error) -> ()) throws {
    let asset = try makeAsset(from: url)
    var sum: Int = 0
    var cancel: Bool = false
    for i in 0..<asset.info.frameCount {
        DispatchQueue.global().async {
            guard !cancel else { return }
            print("r", i)
            do {
                let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
                print("x", i)
                DispatchQueue.main.async {
                    guard !cancel else { return }
                    frame(image, i)
                    sum += 1
                    if sum == asset.info.frameCount {
                        done()
                    }
                }
            } catch {
                cancel = true
                failed(error)
            }
        }
    }
}

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
