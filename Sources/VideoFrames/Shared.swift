#if os(macOS)
import Cocoa
#else
import UIKit
#endif
@preconcurrency import AVFoundation

#if os(macOS)
public typealias _Image = NSImage
#else
public typealias _Image = UIImage
#endif

@globalActor actor VideoActor {
    static let shared = VideoActor()
}

public struct VideoFrame: @unchecked Sendable {
    public let image: _Image
    public init(image: _Image) {
        self.image = image
    }
}

public enum VideoFramesError: Error {
    case videoNotFound
    case framePixelBuffer(String)
    case videoInfo(String)
}

public struct VideoInfo: Sendable {
    public let duration: Double
    public let fps: Double
    public let size: CGSize
    public var frameCount: Int { Int(duration * fps) }
    public let isStereoscopic: Bool
    public init(duration: Double, fps: Double, size: CGSize, isStereoscopic: Bool = false) {
        self.duration = duration
        self.fps = min(fps, 240)
        self.size = size
        self.isStereoscopic = isStereoscopic
    }
    public init(url: URL) async throws {
        let asset = AVAsset(url: url)
        try await self.init(asset: asset)
    }
    init(asset: AVAsset) async throws {
        guard let track: AVAssetTrack = try await asset.load(.tracks).first else {
            throw VideoFramesError.videoInfo("Video asset track not found.")
        }
        duration = try await CMTimeGetSeconds(asset.load(.duration))
        fps = try await Double(track.load(.nominalFrameRate))
        size = try await track.load(.naturalSize)
        isStereoscopic = try await Self.isStereoscopic(avAsset: asset)
    }
    private static func isStereoscopic(avAsset: AVAsset) async throws -> Bool {
        /// First attempt with stereo multiview video
        if #available(iOS 17.0, tvOS 17.0, macOS 14.0, visionOS 1.0, *) {
            if try await avAsset.loadTracks(withMediaCharacteristic: .containsStereoMultiviewVideo).first != nil {
                return true
            }
        }
        /// Second attempt with format description
        guard let videoTrack = try await avAsset.loadTracks(withMediaType: .video).first else {
            return false
        }
        let formatDescriptions: [CMFormatDescription] = try await videoTrack.load(.formatDescriptions)
        for formatDescription in formatDescriptions {
            if let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [String: Any] {
                let hasLeftEye = extensions["HasLeftStereoEyeView"] as? Bool ?? false
                let hasRightEye = extensions["HasRightStereoEyeView"] as? Bool ?? false
                return hasLeftEye && hasRightEye
            }
        }
        return false
    }
}

struct Asset: Sendable {
    let info: VideoInfo
    let generator: AVAssetImageGenerator
}

extension String {
    public func zfill(_ length: Int) -> String {
        fill("0", for: length)
    }
    public func sfill(_ length: Int) -> String {
        fill(" ", for: length)
    }
    func fill(_ char: Character, for length: Int) -> String {
        let diff = (length - count)
        let prefix = (diff > 0 ? String(repeating: char, count: diff) : "")
        return (prefix + self)
    }
}

extension Double {
    var formattedSeconds: String {
        let milliseconds: Int = Int(self.truncatingRemainder(dividingBy: 1.0) * 1000)
        let formattedMilliseconds: String = "\(milliseconds)".zfill(3)
        return "\(Int(self).formattedSeconds).\(formattedMilliseconds)"
    }
}

extension Int {
    var formattedSeconds: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.second, .minute, .hour]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: TimeInterval(self))!
    }
}

public func logBar(at index: Int, count: Int, from date: Date, length: Int = 50, clear: Bool = true) {
    let fraction: Double = Double(index) / Double(count - 1)
    var bar: String = ""
    bar += "["
    for i in 0..<length {
        let f = Double(i) / Double(length)
        bar += f < fraction ? "=" : " "
    }
    bar += "]"
    let percent = "\("\(Int(round(fraction * 100)))".sfill(3))%"
    let progress: String = "\("\(index + 1)".sfill("\(count)".count))/\(count)"
    let timestamp: String = (-date.timeIntervalSinceNow).formattedSeconds
    let msg: String = "\(bar)  \(percent)  \(progress)  \(timestamp)"
    if clear {
        print(msg, "\r", terminator: "")
        fflush(stdout)
    } else {
        print(msg)
    }
}
