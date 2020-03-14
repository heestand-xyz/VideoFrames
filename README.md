# VideoFrames

Convert between Video and Image Frames 

## Install

~~~~swift
.package(url: "https://github.com/hexagons/VideoFrames.git", from: "0.1.0")
~~~~

To use the command line tools add [VideoToFrames](https://github.com/hexagons/pixtools/raw/master/VideoToFrames) or [FramesToVideo](https://github.com/hexagons/pixtools/raw/master/FramesToVideo) to `/usr/local/bin/`

## Example

~~~
$ VideoToFrames ~/Desktop/video.mov ~/Desktop/video_frames/ --format jpg --quality 0.8 
~~~

~~~
$ FramesToVideo ~/Desktop/video_frames ~/Desktop/video.mov --fps 30 --kbps 1000 
~~~
