import Foundation
import Cocoa
import ArgumentParser

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        let path: String = argument.replacingOccurrences(of: "\\ ", with: " ")
        if path.starts(with: "/") {
            self = URL(fileURLWithPath: path)
        } else if path.starts(with: "~/") {
            if #available(OSX 10.12, *) {
                self = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path.replacingOccurrences(of: "~/", with: ""))
            } else {
                return nil
            }
        } else {
            let callURL: URL = URL(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent()
            if argument == "." {
                self = callURL
            } else {
                self = callURL.appendingPathComponent(path)
            }
        }
    }
}
