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
    case videoInfoFail
}

struct VideoInfo {
    let duration: Double
    let fps: Double
    let size: CGSize
    var frameCount: Int { Int(duration * fps) }
    init?(asset: AVAsset) {
        guard let track: AVAssetTrack = asset.tracks(withMediaType: .video).first else { return nil }
        duration = CMTimeGetSeconds(asset.duration)
        fps = Double(track.nominalFrameRate)
        size = track.naturalSize
    }
}
