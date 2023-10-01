import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import AVFoundation

public func convertVideoToFrames(from url: URL) async throws -> [_Image] {
    var frames: [_Image] = []
    let asset = try await makeAsset(from: url)
    for i in 0..<asset.info.frameCount {
        let image: _Image = try await getFrame(at: i, info: asset.info, with: asset.generator)
        frames.append(image)
    }
    return frames
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public func convertVideoToFrames(from url: URL,
                                 frameCount: ((Int) -> ())? = nil,
                                 progress: ((Int) -> ())? = nil) async throws -> [_Image] {
    var frames: [_Image] = []
    let asset = try await makeAsset(from: url)
    frameCount?(asset.info.frameCount)
    for i in 0..<asset.info.frameCount {
        progress?(i)
        let image: _Image = try await getFrame(at: i, info: asset.info, with: asset.generator)
        frames.append(image)
    }
    return frames
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public func convertVideoToFrames(from url: URL, info: VideoInfo? = nil) async throws -> AsyncThrowingStream<_Image, Error> {
    let asset = try await makeAsset(from: url, info: info)
    let frameCount = asset.info.frameCount
    return AsyncThrowingStream { stream in
        Task {
            for index in 0..<frameCount {
                do {
                    let image: _Image = try await getFrame(at: index, info: asset.info, with: asset.generator)
                    stream.yield(image)
                } catch {
                    stream.finish(throwing: error)
                    break
                }
            }
            stream.finish()
        }
    }
}

public func convertVideoToFramesWithWithHandlerSync(from url: URL, frame: (_Image, Int, Int) throws -> ()) async throws {
    let asset = try await makeAsset(from: url)
    let count: Int = asset.info.frameCount
    for i in 0..<count {
        let image: _Image = try await getFrame(at: i, info: asset.info, with: asset.generator)
        try frame(image, i, count)
    }
}

//public func convertVideoToFramesWithHandlerAsync(from url: URL, frame: @escaping (_Image, Int) -> (), completion: @escaping (Result<Void, Error>) -> ()) throws {
//    let asset = try makeAsset(from: url)
//    var sum: Int = 0
//    var cancel: Bool = false
//    for i in 0..<asset.info.frameCount {
//        DispatchQueue.global().async {
//            guard !cancel else { return }
//            do {
//                let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
//                DispatchQueue.main.async {
//                    guard !cancel else { return }
//                    frame(image, i)
//                    sum += 1
//                    if sum == asset.info.frameCount {
//                        completion(.success(()))
//                    }
//                }
//            } catch {
//                cancel = true
//                DispatchQueue.main.async {
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
//}

// MARK: - Asset

func makeAsset(from url: URL, info: VideoInfo? = nil) async throws -> (info: VideoInfo, generator: AVAssetImageGenerator) {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw VideoFramesError.videoNotFound
    }
    let asset: AVAsset = AVAsset(url: url)
    let videoInfo: VideoInfo
    if let info {
        videoInfo = info
    } else {
        videoInfo = try await VideoInfo(asset: asset)
    }
    let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero //CMTime(value: CMTimeValue(1), timescale: CMTimeScale(videoInfo.fps))
    generator.requestedTimeToleranceAfter = .zero //CMTime(value: CMTimeValue(1), timescale: CMTimeScale(videoInfo.fps))
    return (videoInfo, generator)
}

// MARK: - Frame

enum VideoFrameError: LocalizedError {
    case videoFrameIndexOutOfBounds(frameIndex: Int, frameCount: Int, frameRate: Double)
    var errorDescription: String? {
        switch self {
        case .videoFrameIndexOutOfBounds(let frameIndex, let frameCount, let frameRate):
            return "Video Frames - Video Frame Index Out of Range (Frame Index: \(frameIndex), Frame Count: \(frameCount), Frame Rate: \(frameRate))"
        }
    }
}

public func videoFrame(at frameIndex: Int, from url: URL, info: VideoInfo? = nil) async throws -> _Image {
    let asset = try await makeAsset(from: url, info: info)
    guard frameIndex >= 0 && frameIndex < asset.info.frameCount
    else { throw VideoFrameError.videoFrameIndexOutOfBounds(frameIndex: frameIndex, frameCount: asset.info.frameCount, frameRate: asset.info.fps) }
    return try await getFrame(at: frameIndex, info: asset.info, with: asset.generator)
}

func getFrame(at frameIndex: Int, info: VideoInfo, with generator: AVAssetImageGenerator) async throws -> _Image {
    let time: CMTime = CMTime(value: CMTimeValue(frameIndex * 1_000_000),
                              timescale: CMTimeScale(info.fps * 1_000_000))
#if os(visionOS)
    let (cgImage, _): (CGImage, CMTime) = try await generator.image(at: time)
#else
    let cgImage: CGImage
    if #available(iOS 16, macOS 13, visionOS 1.0, *) {
        (cgImage, _) = try await generator.image(at: time)
    } else {
        cgImage = try generator.copyCGImage(at: time, actualTime: nil)
    }
#endif
    #if os(macOS)
    let image: NSImage = NSImage(cgImage: cgImage, size: info.size)
    #else
    let image: UIImage = UIImage(cgImage: cgImage)
    #endif
    return image
}
