import Foundation
import Cocoa
import VideoFrames
import ArgumentParser

enum VideoToFramesError: Error {
    case videoNotFound
    case videoFrameBadData
}

struct VideoToFrames: ParsableCommand {

    @Argument()
    var video: URL
    
    @Argument()
    var folder: URL
    
    func run() throws {
        guard FileManager.default.fileExists(atPath: video.path) else {
            throw VideoToFramesError.videoNotFound
        }
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let videoName: String = video.deletingPathExtension().lastPathComponent
        try convertVideoToFramesSync(from: video, frame: { image, index, count in
            print(index, "/", count, "\r", terminator: "")
            fflush(stdout)
            let name: String = "\(videoName)_\("\(index)".zfill(5)).png"
            let url: URL = self.folder.appendingPathComponent(name)
            guard let data = image.png else {
                throw VideoToFramesError.videoFrameBadData
            }
            try data.write(to: url)
        })
        print("            \r", terminator: "")
        print("done!")
    }
    
}

VideoToFrames.main()
