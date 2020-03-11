import Foundation
import Cocoa
import VideoFrames
import ArgumentParser

enum VideoToFramesError: Error {
    case framesFolderNotFound
    case videoFrameBadData
    case unsupportedVideoFormat
    case noFramesFound
}

struct VideoToFrames: ParsableCommand {

    @Argument()
    var folder: URL
    
    @Argument()
    var video: URL
    
    @Option(name: .long)
    var fps: Int?
    
    @Option(name: .long)
    var kbps: Int?
    
    func run() throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir) else {
            throw VideoToFramesError.framesFolderNotFound
        }
        guard isDir.boolValue else {
            throw VideoToFramesError.framesFolderNotFound
        }
        let images: [NSImage] = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .sorted { nameA, nameB -> Bool in
                nameA < nameB
            }
            .map { name -> URL in
                folder.appendingPathComponent(name)
            }
            .compactMap { url -> NSImage? in
                NSImage(contentsOf: url)
            }
        guard !images.isEmpty else {
            throw VideoToFramesError.noFramesFound
        }
        if FileManager.default.fileExists(atPath: video.path) {
            print("override video? y/n")
            guard ["y", "yes"].contains(readLine()) else {
                return
            }
            try FileManager.default.removeItem(at: video)
        }
        let format: String = video.pathExtension
        guard let videoFormat: VideoFormat = VideoFormat(rawValue: format) else {
            print("supported formats: \(VideoFormat.allCases.map({ $0.rawValue }).joined(separator: ", "))")
            throw VideoToFramesError.unsupportedVideoFormat
        }
        var result: Result<Void, Error>!
        let group = DispatchGroup()
        group.enter()
        try convertFramesToVideo(images: images, fps: fps ?? 30, kbps: kbps ?? 100, as: videoFormat, url: video, frame: { index in
            print(index + 1, "/", images.count, "\r", terminator: "")
            fflush(stdout)
        }, completion: { res in
            print("            \r", terminator: "")
            result = res
            group.leave()
        })
        group.wait()
        try result.get()
        print("done!")
    }
    
}

VideoToFrames.main()
