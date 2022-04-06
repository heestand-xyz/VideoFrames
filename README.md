# VideoFrames

Convert between Video and Image Frames 

## Install

```swift
.package(url: "https://github.com/heestand-xyz/VideoFrames", from: "0.1.0")
```

## Example

```swift
func convertVideoToFrames(from url: URL, force: Bool = false) async throws -> [_Image]
```

## CLI

To use the command line tools add [VideoToFrames](https://github.com/heestand-xyz/VideoFrames/raw/master/VideoToFrames) or [FramesToVideo](https://github.com/heestand-xyz/VideoFrames/raw/master/FramesToVideo) to `/usr/local/bin/`

```
$ VideoToFrames ~/Desktop/video.mov ~/Desktop/video_frames/ --format jpg --quality 0.8 
```

```
$ FramesToVideo ~/Desktop/video_frames ~/Desktop/video.mov --fps 30 --kbps 1000 
```
