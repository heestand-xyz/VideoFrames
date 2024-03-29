import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public enum VideoFormat: String, CaseIterable {
    case mov
    case mp4
    public var fileType: AVFileType {
        switch self {
        case .mov: return .mov
        case .mp4: return .mp4
        }
    }
}

public enum VideoCodec: String, CaseIterable {
    case h264
    case proRes
    public var codec: AVVideoCodecType {
        switch self {
        case .h264: 
            return .h264
        case .proRes:
            #if os(xrOS)
            print("VideoFrames - Warning: ProRes is not supported in visionOS. Will fallback to h264.")
            return .h264
            #else
            return .proRes4444
            #endif
        }
    }
}

@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public func convertFramesToVideo(
    images: [_Image],
    fps: Double = 30.0,
    kbps: Int = 1_000,
    format: VideoFormat = .mov,
    codec: VideoCodec = .h264,
    url: URL,
    frame: ((Int) -> ())? = nil
) async throws {
    
    let _: Bool = try await withCheckedThrowingContinuation { continuation in
    
        DispatchQueue.global(qos: .background).async {
            
            do {
                try convertFramesToVideo(
                    count: images.count,
                    image: { images[$0] },
                    fps: fps,
                    kbps: kbps,
                    format: format,
                    codec: codec,
                    url: url,
                    frame: { index in
                        frame?(index)
                    }, completion: { result in
                        
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                continuation.resume(returning: true)
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                )
            } catch {
                
                DispatchQueue.main.async {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

public func convertFramesToVideo(images: [_Image], fps: Double = 30.0, kbps: Int = 1_000, as format: VideoFormat = .mov, url: URL, frame: @escaping (Int) -> (), completion: @escaping (Result<Void, Error>) -> ()) throws {
    try convertFramesToVideo(count: images.count, image: { images[$0] }, url: url, frame: frame, completion: completion)
}

public func convertFramesToVideo(
    count: Int,
    image: @escaping (Int) throws -> (_Image),
    fps: Double = 30.0,
    kbps: Int = 1_000,
    format: VideoFormat = .mov,
    codec: VideoCodec = .h264,
    url: URL,
    frame: @escaping (Int) -> (),
    completion: @escaping (Result<Void, Error>) -> ()
) throws {
    precondition(count > 0)
    precondition(fps > 0)
    precondition(kbps > 0)
    
    let imageZero: _Image = try image(0)

    let size: CGSize = imageZero.size
    
    let writer = try AVAssetWriter(url: url, fileType: format.fileType)

    let bps: Int = kbps * 1_000
    
    // FPS (29,97 / 999) * 1000 == 30
    // FPS (29,7 / 99) * 100 == 30
    
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: codec.codec,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bps,
//            AVVideoMaxKeyFrameIntervalKey: fps,
//            AVVideoExpectedSourceFrameRateKey: fps,
//            AVVideoMaxKeyFrameIntervalDurationKey: 1.0 / Double(fps),
        ],
    ])
//    input.mediaTimeScale = 30000 //CMTimeScale(fps * 1000)
    
    writer.add(input)

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String : size.width,
        kCVPixelBufferHeightKey as String : size.height,
    ])

    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    if (adaptor.pixelBufferPool == nil) {
        print("Error converting images to video: pixelBufferPool nil after starting session")
        return
    }

    let queue = DispatchQueue(label: "render")

    var frameIndex: Int = 0

    input.requestMediaDataWhenReady(on: queue, using: {
        while input.isReadyForMoreMediaData && frameIndex < count {
            let time: CMTime = CMTimeMake(value: Int64(frameIndex * 1_000),
                                          timescale: Int32(fps * 1_000))
            do {
                let image: _Image = frameIndex > 0 ? try image(frameIndex) : imageZero
                let pixelBuffer: CVPixelBuffer = try getPixelBuffer(from: image)
                adaptor.append(pixelBuffer, withPresentationTime: time)
                frame(frameIndex)
                frameIndex += 1
            } catch {
                completion(.failure(error))
                return
            }
        }
        guard frameIndex >= count else { return }
        input.markAsFinished()
        writer.finishWriting {
            guard writer.error == nil else {
                completion(.failure(writer.error!))
                return
            }
            completion(.success(()))
        }
    })
}

func getPixelBuffer(from image: _Image) throws -> CVPixelBuffer {
    #if os(macOS)
    guard let cgImage: CGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw VideoFramesError.framePixelBuffer("CGImage Not Found")
    }
    #else
    guard let cgImage: CGImage = image.cgImage else {
        throw VideoFramesError.framePixelBuffer("CGImage Not Found")
    }
    #endif
    return try getPixelBuffer(from: cgImage)
}

func getPixelBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
    let osBits: OSType = kCVPixelFormatType_32ARGB
    let bitCount: Int = 8
    let colorSpace: CGColorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
    var maybePixelBuffer: CVPixelBuffer?
    let attrs: [CFString: Any] = [
        kCVPixelBufferPixelFormatTypeKey: Int(osBits) as CFNumber,
        kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
    ]
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     cgImage.width,
                                     cgImage.height,
                                     osBits,
                                     attrs as CFDictionary,
                                     &maybePixelBuffer)
    guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
        throw VideoFramesError.framePixelBuffer("CVPixelBufferCreate failed with status \(status)")
    }
    let flags = CVPixelBufferLockFlags(rawValue: 0)
    guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
        throw VideoFramesError.framePixelBuffer("CVPixelBufferLockBaseAddress failed.")
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                  width: cgImage.width,
                                  height: cgImage.height,
                                  bitsPerComponent: bitCount,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
        throw VideoFramesError.framePixelBuffer("Context failed to be created.")
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return pixelBuffer
}
