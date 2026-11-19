# Licences and source offer

FFmpegLGPL.framework contains FFmpeg configured WITHOUT `--enable-gpl`, `--enable-version3` and `--enable-nonfree`,
so it is licensed under the **GNU Lesser General Public License v2.1 or later**.

It is a **dynamic framework**: you can replace it with your own build of the same libraries
(`scripts/build.sh` in this repository reproduces it exactly), which satisfies the LGPL relinking requirement.

Bundled libraries (all permissive or LGPL, no GPL, no x264/x265/fdk-aac):

| Library | Licence |
|---|---|
| FFmpeg (libavformat, libavcodec, libavfilter, libswscale, libswresample, libavutil) | LGPL 2.1+ |
| libvpx (VP8/VP9) | BSD-3-Clause |
| libopus | BSD-3-Clause |
| libvorbis + libogg | BSD-3-Clause |
| LAME (libmp3lame) | LGPL 2.1+ |
| libwebp | BSD-3-Clause |
| dav1d (AV1 decoder) | BSD-2-Clause |

Exact versions: `scripts/versions.env`. Apple frameworks (VideoToolbox, AudioToolbox) are used for hardware H.264 / HEVC / ProRes and AAC.

## Source code

Complete corresponding source = the upstream tarballs listed (exact URLs in `scripts/build.sh`) plus the build script in this
repository. FFmpeg source: https://ffmpeg.org/releases/ . No modifications are applied to any upstream source.
Written offer: for three years after you received an app that contains this framework, email support@ecomswiftllc.com
and we will send you the complete corresponding source of the framework.

FFmpeg is a trademark of Fabrice Bellard, originator of the FFmpeg project. This project is not affiliated with FFmpeg.
Some codecs (H.264, HEVC, AAC, MP3) may be covered by patents in some countries; you are responsible for your use.
