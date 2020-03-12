import Foundation
import Cocoa
import VideoFrames
import ArgumentParser

enum VideoToFramesError: Error {
    case videoNotFound
    case videoFrameConversionFail(String)
    case unsupportedImageFormat
}

enum ImageFormat {
    case png
    case jpg(Double)
    case tiff
    var ext: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        case .tiff: return "tiff"
        }
    }
    var storageType: NSBitmapImageRep.FileType {
        switch self {
        case .png: return .png
        case .jpg: return .jpeg
        case .tiff: return .tiff
        }
    }
    var properties: [NSBitmapImageRep.PropertyKey: Any] {
        switch self {
        case .jpg(let quality):
            return [.compressionFactor: quality]
        default:
            return [:]
        }
    }
}

struct VideoToFrames: ParsableCommand {

    @Argument()
    var video: URL
    
    @Argument()
    var folder: URL
    
    @Option()
    var format: String?
    
    @Option()
    var quality: Double?
    
    @Flag()
    var force: Bool
    
    func run() throws {
        
        let startDate = Date()
        
        guard FileManager.default.fileExists(atPath: video.path) else {
            throw VideoToFramesError.videoNotFound
        }
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        let videoName: String = video.deletingPathExtension().lastPathComponent
        
        let imageFormat: ImageFormat
        if format == nil {
            imageFormat = .jpg(0.8)
        } else if format == ImageFormat.png.ext {
            imageFormat = .png
        } else if format == ImageFormat.jpg(0).ext {
            imageFormat = .jpg(quality ?? 0.8)
        } else if format == ImageFormat.tiff.ext {
            imageFormat = .tiff
        } else {
            print("supported image formats are png, jpg and tiff.")
            throw VideoToFramesError.unsupportedImageFormat
        }
        
        try convertVideoToFramesSync(from: video, force: force, frame: { image, index, count in
            logBar(at: index, count: count, from: startDate)
            let name: String = "\(videoName)_\("\(index)".zfill(6)).\(imageFormat.ext)"
            let url: URL = self.folder.appendingPathComponent(name)
            guard let rep: Data = image.tiffRepresentation else {
                throw VideoToFramesError.videoFrameConversionFail("tiff not found")
            }
            guard let bitmap = NSBitmapImageRep(data: rep) else {
                throw VideoToFramesError.videoFrameConversionFail("bitmap not found")
            }
            guard let data: Data = bitmap.representation(using: imageFormat.storageType,
                                                         properties: imageFormat.properties) else {
                throw VideoToFramesError.videoFrameConversionFail("rep not found")
            }
            try data.write(to: url)
            if index + 1 == count {
                logBar(at: index, count: count, from: startDate, clear: false)                
            }
        })
    }
    
}

VideoToFrames.main()
