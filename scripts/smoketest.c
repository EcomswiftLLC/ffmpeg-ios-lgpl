// Runs inside the iOS simulator: proves the dynamic framework loads and the LGPL codec set is present.
#include <stdio.h>
#include <string.h>
#include "FFmpegLGPL.h"

static int fails = 0;
static void need_enc(const char *n) {
  const AVCodec *c = avcodec_find_encoder_by_name(n);
  printf("encoder %-18s %s\n", n, c ? "ok" : "MISSING");
  if (!c) fails++;
}
static void need_dec(const char *n) {
  const AVCodec *c = avcodec_find_decoder_by_name(n);
  printf("decoder %-18s %s\n", n, c ? "ok" : "MISSING");
  if (!c) fails++;
}
static void need_mux(const char *n) {
  const AVOutputFormat *f = av_guess_format(n, NULL, NULL);
  printf("muxer   %-18s %s\n", n, f ? "ok" : "MISSING");
  if (!f) fails++;
}
static void need_filter(const char *n) {
  const AVFilter *f = avfilter_get_by_name(n);
  printf("filter  %-18s %s
", n, f ? "ok" : "MISSING");
  if (!f) fails++;
}
static void need_demux(const char *n) {
  const AVInputFormat *f = av_find_input_format(n);
  printf("demuxer %-18s %s\n", n, f ? "ok" : "MISSING");
  if (!f) fails++;
}
int main(void) {
  printf("avformat %u avcodec %u avutil %u\n", avformat_version(), avcodec_version(), avutil_version());
  printf("license: %s\n", avformat_license());
  if (strstr(avformat_license(), "GPL") && !strstr(avformat_license(), "LGPL")) { printf("GPL BUILD DETECTED\n"); fails++; }
  if (strstr(avformat_configuration(), "--enable-gpl") && !strstr(avformat_configuration(), "--disable-gpl")) { printf("enable-gpl in config\n"); fails++; }
  const char *encs[] = {"h264_videotoolbox", "hevc_videotoolbox", "libvpx", "libvpx-vp9", "libopus", "libvorbis", "libmp3lame",
                        "libwebp", "aac", "flac", "mpeg4", "mpeg2video", "mjpeg", "wmv2", "msmpeg4", "flv", "pcm_s16le", "ac3", "alac", "gif", "apng", "libwebp_anim", "prores_ks", "wmav2", NULL};
  for (int i = 0; encs[i]; i++) need_enc(encs[i]);
  const char *decs[] = {"h264", "hevc", "libdav1d", "vp8", "vp9", "wmv3", "mpeg4", "msmpeg4", "mpeg2video", "theora", "vorbis", "opus", "mp3", "aac", "ac3", "eac3", "flac", "wmav2", "amrnb", "rv40", "dvvideo", "mjpeg", NULL};
  for (int i = 0; decs[i]; i++) need_dec(decs[i]);
  const char *muxs[] = {"mp4", "mov", "matroska", "webm", "avi", "flv", "asf", "mpegts", "mpeg", "ogg", "gif", "webp", "apng", "ipod", "3gp", "mp3", "wav", "flac", "opus", "caf", "aiff", NULL};
  for (int i = 0; muxs[i]; i++) need_mux(muxs[i]);
  const char *dmxs[] = {"matroska,webm", "avi", "asf", "flv", "mpegts", "mpeg", "ogg", "mov,mp4,m4a,3gp,3g2,mj2", "mxf", "rm", "dv", "gif", "webp_pipe", "ac3", "eac3", "amr", "aiff", "wav", "flac", NULL};
  for (int i = 0; dmxs[i]; i++) need_demux(dmxs[i]);
  const char *fls[] = {"fps", "scale", "transpose", "hflip", "palettegen", "paletteuse", "split", "format", "aformat", "aresample", NULL};
  for (int i = 0; fls[i]; i++) need_filter(fls[i]);
  printf("%s (%d missing)\n", fails ? "SMOKETEST FAILED" : "SMOKETEST PASSED", fails);
  return fails ? 1 : 0;
}
