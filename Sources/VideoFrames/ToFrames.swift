import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import AVFoundation

public func convertVideoToFrames(from url: URL, force: Bool = false) throws -> [_Image] {
    var frames: [_Image] = []
    let asset = try makeAsset(from: url, force: force)
    for i in 0..<asset.info.frameCount {
        let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
        frames.append(image)
    }
    return frames
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public func convertVideoToFrames(from url: URL, force: Bool = false) async throws -> [_Image] {
    var frames: [_Image] = []
    let asset = try makeAsset(from: url, force: force)
    for i in 0..<asset.info.frameCount {
        let frame: _Image = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
                    DispatchQueue.main.async {
                        continuation.resume(returning: image)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        frames.append(frame)
    }
    return frames
}

//@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
//public func convertVideoToFrames(from url: URL, force: Bool = false) async throws -> [_Image] {
//
//    let asset = try makeAsset(from: url, force: force)
//
//    return try await withThrowingTaskGroup(of: (Int, _Image).self) { group in
//
//        for index in 0..<asset.info.frameCount {
//
//            group.addTask {
//
//                let image: _Image = try await withCheckedThrowingContinuation { continuation in
//
//                    DispatchQueue.global(qos: .background).async {
//
//                        do {
//
//                            let image = try getFrame(at: index, info: asset.info, with: asset.generator)
//
//                            DispatchQueue.main.async {
//                                continuation.resume(returning: image)
//                            }
//
//                        } catch {
//
//                            DispatchQueue.main.async {
//                                continuation.resume(throwing: error)
//                            }
//                        }
//                    }
//                }
//
//                return (index, image)
//            }
//        }
//
//        var images: [(Int, _Image)] = []
//
//        for try await (index, image) in group {
//            images.append((index, image))
//        }
//
//        return images
//            .sorted(by: { leadingPack, trailingPack in
//                leadingPack.0 < trailingPack.0
//            })
//            .map(\.1)
//    }
//}

public func convertVideoToFramesWithWithHandlerSync(from url: URL, force: Bool = false, frame: (_Image, Int, Int) throws -> ()) throws {
    let asset = try makeAsset(from: url, force: force)
    let count: Int = asset.info.frameCount
    for i in 0..<count {
        let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
        try frame(image, i, count)
    }
}

public func convertVideoToFramesWithHandlerAsync(from url: URL, force: Bool = false, frame: @escaping (_Image, Int) -> (), completion: @escaping (Result<Void, Error>) -> ()) throws {
    let asset = try makeAsset(from: url, force: force)
    var sum: Int = 0
    var cancel: Bool = false
    for i in 0..<asset.info.frameCount {
        DispatchQueue.global().async {
            guard !cancel else { return }
            do {
                let image: _Image = try getFrame(at: i, info: asset.info, with: asset.generator)
                DispatchQueue.main.async {
                    guard !cancel else { return }
                    frame(image, i)
                    sum += 1
                    if sum == asset.info.frameCount {
                        completion(.success(()))
                    }
                }
            } catch {
                cancel = true
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

func makeAsset(from url: URL, force: Bool = false) throws -> (info: VideoInfo, generator: AVAssetImageGenerator) {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw VideoFramesError.videoNotFound
    }
    let asset: AVAsset = AVAsset(url: url)
    let info: VideoInfo = try VideoInfo(asset: asset, roundFps: force)
    let generator: AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero //CMTime(value: CMTimeValue(1), timescale: CMTimeScale(info.fps))
    generator.requestedTimeToleranceAfter = .zero //CMTime(value: CMTimeValue(1), timescale: CMTimeScale(info.fps))
    return (info, generator)
}

func getFrame(at frameIndex: Int, info: VideoInfo, with generator: AVAssetImageGenerator) throws -> _Image {
    let time: CMTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(info.fps))
    var actualTime: CMTime = CMTime(value: -1, timescale: 1)
    let cgImage: CGImage = try generator.copyCGImage(at: time, actualTime: &actualTime)
//    print("TIME", frameIndex, "-->", time.seconds * Double(info.fps),  "-->", actualTime.seconds * Double(info.fps))
    #if os(macOS)
    let image: NSImage = NSImage(cgImage: cgImage, size: info.size)
    #else
    let image: UIImage = UIImage(cgImage: cgImage)
    #endif
    return image
}
