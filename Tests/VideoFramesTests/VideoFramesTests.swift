import XCTest
@testable import VideoFrames

final class VideoFramesTests: XCTestCase {
    
    var repoURL: URL!
    var videoURL: URL!
    
    override func setUp() {
        #if os(macOS)
        if #available(OSX 10.12, *) {
            repoURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Code/Frameworks/Development/VideoFrames")
        }
        #endif
        videoURL = repoURL.appendingPathComponent("Resources/Count.mov")
        XCTAssert(FileManager.default.fileExists(atPath: videoURL.path))
    }
    
    #if os(macOS)
    
    func testConvertVideoToFramesAsync() {
        let expectation = self.expectation(description: "Render")
        var frames: [Int] = []
        try! convertVideoToFramesAsync(from: videoURL, frame: { image, index in
            frames.append(index)
            print("render", index)
        }, done: {
            expectation.fulfill()
        }) { error in
            XCTFail(error.localizedDescription)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        print(frames)
        XCTAssertEqual(frames.count, 100)
    }
    
    func testConvertVideoToFrames() {
        let frames: [NSImage] = try! convertVideoToFrames(from: videoURL)
        XCTAssertEqual(frames.count, 100)
    }

    static var allTests = [
        ("testConvertVideoToFrames", testConvertVideoToFrames),
    ]
    
    #else
    
    static var allTests: [(String, () -> ())] = []
    
    #endif
    
}
