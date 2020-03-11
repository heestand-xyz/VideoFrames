#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import AVFoundation

#if os(macOS)
public typealias _Image = NSImage
#else
public typealias _Image = UIImage
#endif

public enum VideoFramesError: Error {
    case videoNotFound
    case framesIsEmpty
    case framePixelBuffer(String)
    case videoInfo(String)
}

struct VideoInfo {
    let duration: Double
    let fps: Int
    let size: CGSize
    var frameCount: Int { Int(duration * Double(fps)) }
    init(asset: AVAsset) throws {
        guard let track: AVAssetTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoFramesError.videoInfo("Video asset track not found.")
        }
        duration = CMTimeGetSeconds(asset.duration)
        let rawFps: Float = track.nominalFrameRate
        guard Float(Int(rawFps)) == rawFps else {
            throw VideoFramesError.videoInfo("Decimal FPS not supported.")
        }
        fps = Int(rawFps)
        size = track.naturalSize
    }
}
