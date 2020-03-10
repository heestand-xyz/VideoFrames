#if os(macOS)
import Cocoa
#else
import UIKit
#endif

#if os(macOS)
public typealias _Image = NSImage
#else
public typealias _Image = UIImage
#endif
