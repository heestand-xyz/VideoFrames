import XCTest
@testable import VideoFrames

final class VideoFramesTests: XCTestCase {
    
    var repoURL: URL!
    
    override func setUp() {
        #if os(macOS)
        if #available(OSX 10.12, *) {
            repoURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code/Frameworks/Development/VideoFrames")
        }
        #endif
    }
    
    #if os(macOS)
    
    func testConvertVideoToFrames() {
        let url: URL = repoURL.appendingPathComponent("Resources/Count.mov")
        XCTAssert(FileManager.default.fileExists(atPath: url.path))
        let frames: [NSImage] = try! convertVideoToFrames(from: url)
        XCTAssertEqual(frames.count, 100)
    }

    static var allTests = [
        ("testConvertVideoToFrames", testConvertVideoToFrames),
    ]
    
    #else
    
    static var allTests: [(String, () -> ())] = []
    
    #endif
    
}
