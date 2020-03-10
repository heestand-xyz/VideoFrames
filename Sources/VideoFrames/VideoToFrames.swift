import Foundation
import AVFoundation

public func convertVideoToFrames(url: URL) throws -> [_Image] {
    var frames: [_Image] = []
    let asset: AVAsset = AVAsset(url: url)
    let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    let duration: Float64 = CMTimeGetSeconds(asset.duration)
    for second: Int in 0..<Int(duration) {
        let seconds: Float64 = Float64(second)
        let time: CMTime = CMTimeMakeWithSeconds(seconds, preferredTimescale: Int32(NSEC_PER_SEC))
        let image: CGImage = try generator.copyCGImage(at: time, actualTime: nil)
        frames.append(_Image(cgImage: image))
    }
    return frames
}
