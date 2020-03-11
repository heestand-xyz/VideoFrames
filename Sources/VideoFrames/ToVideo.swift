import Foundation
import AVFoundation

public enum VideoFormat: String, CaseIterable {
    case mov
    case mp4
    var fileType: AVFileType {
        switch self {
        case .mov: return .mov
        case .mp4: return .mp4
        }
    }
}

public func convertFramesToVideo(images: [_Image], fps: Int = 30, as format: VideoFormat = .mov, url: URL, frame: @escaping (Int) -> (), completion: @escaping (Result<Void, Error>) -> ()) throws {
    guard !images.isEmpty else {
        throw VideoFramesError.framesIsEmpty
    }
    let size: CGSize = images.first!.size
    
    let writer = try AVAssetWriter(url: url, fileType: format.fileType)

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height,
    ])
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

    let frameDuration: CMTime = CMTimeMake(value: 1, timescale: Int32(fps))
    var frameIndex: Int = 0

    input.requestMediaDataWhenReady(on: queue, using: {
        while input.isReadyForMoreMediaData && frameIndex < images.count {
            let lastFrameTime: CMTime = CMTimeMake(value: Int64(frameIndex), timescale: Int32(fps))
            let presentationTime: CMTime = frameIndex == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
            let image: _Image = images[frameIndex]
            do {
                let pixelBuffer: CVPixelBuffer = try getPixelBuffer(from: image)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                frame(frameIndex)
                frameIndex += 1
            } catch {
                completion(.failure(error))
                return
            }
        }
        guard frameIndex >= images.count else { return }
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
    #if os(iOS) || os(tvOS)
    guard let cgImage: CGImage = image.cgImage else {
        throw VideoFramesError.framePixelBuffer("CGImage Not Found")
    }
    #elseif os(macOS)
    guard let cgImage: CGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw VideoFramesError.framePixelBuffer("CGImage Not Found")
    }
    #endif
    return try getPixelBuffer(from: cgImage)
}

func getPixelBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
    let osBits: OSType = kCVPixelFormatType_32BGRA
    let bitCount: Int = 8
    let colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
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
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw VideoFramesError.framePixelBuffer("Context failed to be created.")
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return pixelBuffer
}
