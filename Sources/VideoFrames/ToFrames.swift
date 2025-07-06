import Foundation
#if os(macOS)
import Cocoa
#else
import UIKit
#endif
import VideoToolbox
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

// MARK: - Asset

func makeAsset(from url: URL, info: VideoInfo? = nil) async throws -> Asset {
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
    return Asset(info: videoInfo, generator: generator)
}

// MARK: - Frame

enum VideoFrameError: LocalizedError {
    case videoFrameIndexOutOfBounds(frameIndex: Int, frameCount: Int, frameRate: Double)
    case videoTimeOutOfBounds(time: TimeInterval, duration: TimeInterval)
    case videoInfoIsNotStereoscopic
    case failedToLoadSteroscopicVideoFrame(code: Int)
    var errorDescription: String? {
        switch self {
        case .videoFrameIndexOutOfBounds(let frameIndex, let frameCount, let frameRate):
            "Video Frames - Video Frame Index Out of Bounds (Frame Index: \(frameIndex), Frame Count: \(frameCount), Frame Rate: \(frameRate))"
        case .videoTimeOutOfBounds(let time, let duration):
            "Video Frames - Video Time Out of Bounds (Time: \(time), Duration: \(duration))"
        case .videoInfoIsNotStereoscopic:
            "Video Frames - Video Info is Not Stereoscopic"
        case .failedToLoadSteroscopicVideoFrame(let code):
            "Video Frames - Failed to Load Stereoscopic Video Frame with Code: \(code)"
        }
    }
}

public func videoFrame(at frameIndex: Int, from url: URL, info: VideoInfo? = nil) async throws -> _Image {
    let asset = try await makeAsset(from: url, info: info)
    guard frameIndex >= 0 && frameIndex < asset.info.frameCount
    else { throw VideoFrameError.videoFrameIndexOutOfBounds(frameIndex: frameIndex, frameCount: asset.info.frameCount, frameRate: asset.info.fps) }
    return try await getFrame(at: frameIndex, info: asset.info, with: asset.generator)
}

public func videoFrame(at time: TimeInterval, from url: URL, info: VideoInfo? = nil) async throws -> _Image {
    let asset = try await makeAsset(from: url, info: info)
    guard time >= 0.0 && time <= asset.info.duration
    else { throw VideoFrameError.videoTimeOutOfBounds(time: time, duration: asset.info.duration) }
    let cmTime: CMTime = CMTime(value: CMTimeValue(time * 1_000_000),
                                timescale: CMTimeScale(1_000_000))
    return try await getFrame(at: cmTime, info: asset.info, with: asset.generator)
}

func getFrame(at frameIndex: Int, info: VideoInfo, with generator: AVAssetImageGenerator) async throws -> _Image {
    let time: CMTime = CMTime(value: CMTimeValue(frameIndex * 1_000_000),
                              timescale: CMTimeScale(info.fps * 1_000_000))
    return try await getFrame(at: time, info: info, with: generator)
}

func getFrame(at time: CMTime, info: VideoInfo, with generator: AVAssetImageGenerator) async throws -> _Image {
#if os(visionOS)
    let (cgImage, _): (CGImage, CMTime) = try await generator.image(at: time)
#else
    let cgImage: CGImage
    if #available(iOS 16, tvOS 16, macOS 13, visionOS 1.0, *) {
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

@available(iOS 17.0, tvOS 17.0, macOS 14.0, visionOS 1.0, *)
public func stereoscopicVideoFrame(at frameIndex: Int, from url: URL, info: VideoInfo? = nil) async throws -> (left: _Image, right: _Image) {
    let info: VideoInfo = if let info {
        info
    } else {
        try await VideoInfo(url: url)
    }
    guard info.isStereoscopic else {
        throw VideoFrameError.videoInfoIsNotStereoscopic
    }
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaCharacteristic: .containsStereoMultiviewVideo).first else {
        throw VideoFrameError.videoInfoIsNotStereoscopic
    }
    let assetReader = try AVAssetReader(asset: asset)
    let outputSettings: [String: Any] = [
        AVVideoDecompressionPropertiesKey as String: [kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs as String: try await videoLayerIDs(for: track)]
    ]
    let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
    guard assetReader.canAdd(trackOutput) else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 0)
    }
    assetReader.add(trackOutput)
    
    precondition(info.fps > 0.0)
    let time = Double(frameIndex) / info.fps
    let cursorTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(info.fps))
    let cureorDuration = CMTime(value: 1, timescale: CMTimeScale(info.fps))
    assetReader.timeRange = CMTimeRange(start: cursorTime, duration: cureorDuration)
    
    guard let cursor = track.makeSampleCursorAtFirstSampleInDecodeOrder() else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 1)
    }
    let sampleBufferGenerator = AVSampleBufferGenerator(asset: asset, timebase: nil)
    var presentationTimes = [CMTime]()
    let request = AVSampleBufferRequest(start: cursor)
    var numSamples: Int64 = 0
    repeat {
        let buf = try sampleBufferGenerator.makeSampleBuffer(for: request)
        presentationTimes.append(buf.presentationTimeStamp)
        numSamples = cursor.stepInDecodeOrder(byCount: 1)
    } while numSamples == 1
    
    guard assetReader.startReading() else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 2)
    }
    
    guard assetReader.status == .reading else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 3)
    }
    guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 4)
    }
    guard let taggedBuffers = sampleBuffer.taggedBuffers else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 5)
    }
    guard taggedBuffers.count == 2 else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 6)
    }
    
    var leftEyeImage: _Image?
    var rightEyeImage: _Image?

    let context = CIContext()

    for taggedBuffer in taggedBuffers {
        guard case let .pixelBuffer(pixelBuffer) = taggedBuffer.buffer else { continue }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { continue }

        if taggedBuffer.tags.contains(.stereoView(.leftEye)) {
#if os(macOS)
            leftEyeImage = NSImage(cgImage: cgImage, size: info.size)
#else
            leftEyeImage = UIImage(cgImage: cgImage)
#endif
        } else if taggedBuffer.tags.contains(.stereoView(.rightEye)) {
#if os(macOS)
            rightEyeImage = NSImage(cgImage: cgImage, size: info.size)
#else
            rightEyeImage = UIImage(cgImage: cgImage)
#endif
        }
    }

    guard let left = leftEyeImage, let right = rightEyeImage else {
        throw VideoFrameError.failedToLoadSteroscopicVideoFrame(code: 7)
    }
    return (left, right)
}

@available(iOS 17.0, tvOS 17.0, macOS 14.0, visionOS 1.0, *)
private func videoLayerIDs(for videoTrack: AVAssetTrack) async throws -> [Int64]? {
    let formatDescriptions = try await videoTrack.load(.formatDescriptions)
    var tags = [Int64]()
    if let tagCollections = formatDescriptions.first?.tagCollections {
        tags = tagCollections.flatMap({ $0 }).compactMap { tag in
            tag.value(onlyIfMatching: .videoLayerID)
        }
    }
    return tags
}
