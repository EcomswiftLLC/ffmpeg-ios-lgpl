LGPL-only FFmpeg for iOS 17+ (device arm64 + simulator arm64) as one dynamic framework, `FFmpegLGPL.xcframework`.

Contents: libavformat/avcodec/avfilter/swscale/swresample/avutil, VideoToolbox + AudioToolbox, libvpx (VP8/VP9), libopus, libvorbis, libmp3lame, libwebp, dav1d. No GPL, no x264/x265/fdk-aac.

Assets: `FFmpegLGPL.xcframework.zip`, `FFmpegLGPL-headers.zip` (use as HEADER_SEARCH_PATHS, then `#include "FFmpegLGPL.h"`), `checksums.txt` (sha256), `ffmpeg-config-iphoneos.mak`, `smoketest-output.txt` (codecs, muxers and demuxers verified inside the iOS simulator).
See NOTICE.md for licences and the source offer.
