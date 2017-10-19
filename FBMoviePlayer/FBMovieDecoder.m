
//
//  FBMovieDecoder.m
//  TinyVideo
//
//  Created by FB on 2017/10/13.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Accelerate/Accelerate.h>

#import "FBMovieDecoder.h"
#import "FBAudioManager.h"
#import "FBMovieDefs.h"

//-- ffmpeg headers
#import "libavcodec/avcodec.h"
#import "libavutil/avutil.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "libswresample/swresample.h"

#pragma mark -- static global
static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}

static NSData * copyFrameData(UInt8 *src, int linesize, int width, int height)
{
    width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i) {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    return md;
}

static BOOL isNetworkPath (NSString *path)
{
    NSRange r = [path rangeOfString:@":"];
    if (r.location == NSNotFound)
        return NO;
    NSString *scheme = [path substringToIndex:r.length];
    if ([scheme isEqualToString:@"file"])
        return NO;
    return YES;
}

static BOOL audioCodecIsSupported(AVCodecContext *audio)
{
    if (audio->sample_fmt == AV_SAMPLE_FMT_S16) {
        FBAudioManager *audioManager = [FBAudioManager audioManager];
        return  (int)audioManager.samplingRate == audio->sample_rate &&
        audioManager.numOutputChannels == audio->channels;
    }
    return NO;
}



#pragma mark -- decoder
@interface FBMovieDecoder () {
    NSString* _moviePath;
    
    AVFormatContext     *_formatCtx;
    AVCodecContext      *_videoCodecCtx;
    AVCodecContext      *_audioCodecCtx;
    
    AVFrame             *_videoFrame;
    AVFrame             *_audioFrame;
    
    NSInteger           _videoStreamIndex;
    NSInteger           _audioStreamIndex;
    
    CGFloat             _videoTimeBase;
    CGFloat             _audioTimeBase;
    
    // audio resamle
    AVPicture           _picture;
    BOOL                _pictureValid;
    struct SwsContext   *_swsContext;
    SwrContext          *_swrContext;
    void                *_swrBuffer;
    NSUInteger          _swrBufferSize;
    
    FBVideoFrameFormat  _videoFrameFormat;
    
    CGFloat             _position;
    
    double _fps;
}
@end


@implementation FBMovieDecoder

@dynamic moviePath;
@dynamic duration;
@dynamic position;
@dynamic startTime;
@dynamic fps;
@dynamic sampleRate;
@dynamic hasVideo;
@dynamic hasAudio;
@dynamic hasSubtitle;
@dynamic videoFrameFormat;

- (instancetype)init {
    return [self initWithMovie:nil];
}

- (instancetype)initWithMovie:(NSString *)moviePath {
    if (self = [super init]) {
        _moviePath = moviePath;
        
        _videoStreamIndex = -1;
        _audioStreamIndex = -1;
    }
    return self;
}

+ (instancetype)decoderWithMovie:(NSString *)moviePath {
    return [[FBMovieDecoder alloc] initWithMovie:moviePath];
}

- (BOOL)openMovieAtPath:(NSString *)moviePath {
    NSAssert(moviePath, @"err: movie path should not be nil");
    NSAssert(!_formatCtx, @"err: decoder is already in used");
    
    _moviePath = moviePath;
    
    av_register_all();
    avcodec_register_all();
    
    if (![self openInput]) {
        goto openErr;
    }
    
    BOOL v = [self openVideoStream];
    BOOL a = [self openAudioStream];
    if (!v && !a) {
        goto openErr;
    }
    
    //[self openSubtitleStream];
    
    fbmovie_gcd_main_async_safe(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kMoviePlayerDidPreparedNotification object:nil userInfo:@{kMoviePlayerDidPreparedResultKey: [NSNumber numberWithInteger:FBMovieErrorNone]}];
    })
    
    return YES;
    
openErr:
    [self releaseResources];
    fbmovie_gcd_main_async_safe(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kMoviePlayerDidPreparedNotification object:nil userInfo:@{kMoviePlayerDidPreparedResultKey: [NSNumber numberWithInteger:FBMovieErrorOpenStream]}];
    })
    
    return NO;
}

- (BOOL)prepareForDecode {
    return [self openMovieAtPath:_moviePath];
}

- (BOOL)openInput {
    _isNetworkMovie = isNetworkPath(_moviePath);
    // env init for network
    if (_isNetworkMovie) {
        avformat_network_init();
    }
    
    //AVDictionary* opts = NULL;
    //av_dict_set(&opts, "stimeout", "3000000", 0);//设置超时3秒
    if (avformat_open_input(&_formatCtx, [_moviePath UTF8String], NULL, NULL) < 0) {
        NSLog(@"------->>>>>>>> err: could not open input");
        return NO;
    }
    
    if (avformat_find_stream_info(_formatCtx, NULL) < 0) {
        NSLog(@"------>>>>>>>> err: could not check stream info");
        avformat_close_input(&_formatCtx);
        return NO;
    }
    
#if DEBUG
    for (int i = 0; i < _formatCtx->nb_streams; ++i) {
        printf("******************** stream %d ***********************\n", i);
        av_dump_format(_formatCtx, i, 0, 0);
    }
    printf("***********************************************\n");
#endif
    
    return YES;
}

- (BOOL)openVideoStream {
    _videoStreamIndex = -1;
    
    AVCodec *pCodec;
    // find first video stream
    if ((_videoStreamIndex = av_find_best_stream(_formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        NSLog(@"------->>>>>>> err: could not find video stream");
        return NO;
    }
    
    AVStream *vStream = _formatCtx->streams[_videoStreamIndex];
    _videoCodecCtx = vStream->codec;
    
    // find video codec
    pCodec = avcodec_find_decoder(_videoCodecCtx->codec_id);
    if (!pCodec) {
        NSLog(@"------->>>>>>> err: could not find video decoder");
        return NO;
    }
    NSLog(@"--------->>>>>>>>>> use video decoder: %s", pCodec->name);
    
    // open video codec
    if (avcodec_open2(_videoCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"------->>>>>>> err: could not open video decoder: %s", pCodec->name);
        return NO;
    }
    
    _videoFrame = av_frame_alloc();
    if (!_videoFrame) {
        avcodec_close(_videoCodecCtx);
        return NO;
    }
    
    // retrive fps
    //    if(vStream->avg_frame_rate.den && vStream->avg_frame_rate.num) {
    //        _fps = av_q2d(vStream->avg_frame_rate);
    //    } else {
    //        _fps = 25;
    //    }
    avStreamFPSTimeBase(vStream, 0.04/*1/25*/, &_fps, &_videoTimeBase);
    
    return YES;
}

- (BOOL)openAudioStream {
    _audioStreamIndex = -1;
    
    AVCodec *pCodec;
    // find first audio stream
    if ((_audioStreamIndex = av_find_best_stream(_formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, &pCodec, 0)) < 0) {
        NSLog(@"------->>>>>>> err: could not find audio stream");
        return NO;
    }
    
    AVStream *aStream = _formatCtx->streams[_audioStreamIndex];
    _audioCodecCtx = aStream->codec;
    
    // find video codec
    pCodec = avcodec_find_decoder(_audioCodecCtx->codec_id);
    if (!pCodec) {
        NSLog(@"------->>>>>>> err: could not find audio decoder");
        return NO;
    }
    NSLog(@"--------->>>>>>>>>> use audio decoder: %s", pCodec->name);
    
    // open video codec
    if (avcodec_open2(_audioCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"------->>>>>>> err: could not open audio decoder: %s", pCodec->name);
        return NO;
    }
    
    if (!audioCodecIsSupported(_audioCodecCtx)) {
        FBAudioManager *audioManager = [FBAudioManager audioManager];
        _swrContext = swr_alloc_set_opts(NULL,
                                        av_get_default_channel_layout(audioManager.numOutputChannels),
                                        AV_SAMPLE_FMT_S16,
                                        audioManager.samplingRate,
                                        av_get_default_channel_layout(_audioCodecCtx->channels),
                                        _audioCodecCtx->sample_fmt,
                                        _audioCodecCtx->sample_rate,
                                        0,
                                        NULL);
        
        if (!_swrContext || swr_init(_swrContext) != 0) {
            if (_swrContext) {
                swr_free(&_swrContext);
            }
            avcodec_close(_audioCodecCtx);
            
            return NO;
        }
    }
    
    _audioFrame = av_frame_alloc();
    if (!_audioFrame) {
        avcodec_close(_audioCodecCtx);
        return NO;
    }
    
    avStreamFPSTimeBase(aStream, 0.025, 0, &_audioTimeBase);
    
    return YES;
}

- (BOOL)openSubtitleStream {
    return YES;
}

- (NSArray<FBMovieFrame*>*)decodeFramesWithDuration:(CGFloat)duration {
    // no video && audio stream found
    if (!_formatCtx) {
        return nil;
    }
    
    if (_videoStreamIndex<0 && _audioStreamIndex<0) {
        return nil;
    }
    
    NSMutableArray *frames = [NSMutableArray new];
    
    AVPacket packet;
    CGFloat decodedDuration = 0.0;
    BOOL finished = NO;
    
    while (!finished) {
        if (av_read_frame(_formatCtx, &packet) < 0) {
            // end
            _isEOF = YES;
            break;
        }
        
        // video frame
        if (_videoStreamIndex == packet.stream_index) {
            int pktSize = packet.size;
            while (pktSize > 0) {
                int gotframe = 0;
                int len = -1;
                len = avcodec_decode_video2(_videoCodecCtx,
                                                _videoFrame,
                                                &gotframe,
                                                &packet);
//                len = avcodec_send_packet(_videoCodecCtx, &packet);
                if (len < 0) {
                    NSLog(@"------>>>>>>> decode video error, skip packet");
                    break;
                }
//                len = avcodec_receive_frame(_videoCodecCtx, _videoFrame);
//                if (len < 0) {
//                    NSLog(@"------>>>>>>> decode video error, skip frame");
//                    break;
//                }
                
                if (gotframe) {
                    FBVideoFrame *frame = [self handleVideoFrame];
                    if (frame) {
                        [frames addObject:frame];
                        
                        _position = frame.position;
                        decodedDuration += frame.duration;
                        if (decodedDuration >= duration) {
                            finished = YES;
                        }
                    }
                }// if gotframe
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
            } // while pktsize
        } //if
        // audio frame
        else if (_audioStreamIndex == packet.stream_index) {
            int pktSize = packet.size;
            while (pktSize > 0) {
                int gotframe = 0;
                int len = -1;
                len = avcodec_decode_audio4(_audioCodecCtx,
                                            _audioFrame,
                                            &gotframe,
                                            &packet);
                if (len < 0) {
                    NSLog(@"------>>>>>>> decode audio error, skip packet");
                    break;
                }
                
                if (gotframe) {
                    FBAudioFrame *frame = [self handleAudioFrame];
                    if (frame) {
                        [frames addObject:frame];
                        
                        // if movie has video stream, use video stream's position
                        // else, use audio stream's position
                        if (_videoStreamIndex < 0) {
                            _position = frame.position;
                            decodedDuration += frame.duration;
                            if (decodedDuration >= duration) {
                                finished = YES;
                            }
                        }
                    }
                }// if gotframe
                
                if (0 == len) {
                    break;
                }
                
                pktSize -= len;
            } // while pktsize
        }
    }//while
    
    return [NSArray arrayWithArray:frames];
}

#pragma mark -- dealloc
- (void)dealloc {
    [self releaseResources];
}

- (void)releaseResources {
    
    [self closeScaler];
    
    if (_videoCodecCtx) {
        avcodec_close(_videoCodecCtx);
        _videoCodecCtx = NULL;
    }
    
    if (_videoFrame) {
        av_frame_free(&_videoFrame);
        _videoFrame = NULL;
    }
    
    if (_audioCodecCtx) {
        avcodec_close(_audioCodecCtx);
        _audioCodecCtx = NULL;
    }
    
    if (_formatCtx) {
        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
    }
}

- (void) closeScaler
{
    if (_swsContext) {
        sws_freeContext(_swsContext);
        _swsContext = NULL;
    }
    
    if (_pictureValid) {
        avpicture_free(&_picture);
        _pictureValid = NO;
    }
}

- (BOOL) setupScaler
{
    [self closeScaler];
    
    _pictureValid = avpicture_alloc(&_picture,
                                    AV_PIX_FMT_RGB24,
                                    _videoCodecCtx->width,
                                    _videoCodecCtx->height) == 0;
    
    if (!_pictureValid)
        return NO;
    
    _swsContext = sws_getCachedContext(_swsContext,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       _videoCodecCtx->pix_fmt,
                                       _videoCodecCtx->width,
                                       _videoCodecCtx->height,
                                       AV_PIX_FMT_RGB24,
                                       SWS_FAST_BILINEAR,
                                       NULL, NULL, NULL);
    
    return _swsContext != NULL;
}


- (BOOL)stepFrame {
    int frameFinished = 0;
    AVPacket packet;
    while (!frameFinished && av_read_frame(_formatCtx, &packet) >= 0) {
        if (packet.stream_index == _videoStreamIndex) {
            avcodec_decode_video2(_videoCodecCtx,
                                  _videoFrame,
                                  &frameFinished,
                                  &packet);
        }
    }
    if (frameFinished == 0) {
        [self releaseResources];
    }
    return frameFinished != 0;
}

- (FBVideoFrame *) handleVideoFrame {
    
    if (!_videoFrame->data[0])
        return nil;
    
    FBVideoFrame *frame;
    
    if (_videoFrameFormat == FBVideoFrameFormatYUV) {
        
        FBVideoFrameYUV * yuvFrame = [[FBVideoFrameYUV alloc] init];
        
        yuvFrame.luma = copyFrameData(_videoFrame->data[0],
                                      _videoFrame->linesize[0],
                                      _videoCodecCtx->width,
                                      _videoCodecCtx->height);
        
        yuvFrame.chromaB = copyFrameData(_videoFrame->data[1],
                                         _videoFrame->linesize[1],
                                         _videoCodecCtx->width / 2,
                                         _videoCodecCtx->height / 2);
        
        yuvFrame.chromaR = copyFrameData(_videoFrame->data[2],
                                         _videoFrame->linesize[2],
                                         _videoCodecCtx->width / 2,
                                         _videoCodecCtx->height / 2);
        
        frame = yuvFrame;
        
    } else {
        
        if (!_swsContext &&
            ![self setupScaler]) {
            
            NSLog(@"-------->>>>>>>>> err: failed to setup video scaler");
            return nil;
        }
        
        sws_scale(_swsContext,
                  (const uint8_t **)_videoFrame->data,
                  _videoFrame->linesize,
                  0,
                  _videoCodecCtx->height,
                  _picture.data,
                  _picture.linesize);
        
        
        FBVideoFrameRGB *rgbFrame = [[FBVideoFrameRGB alloc] init];
        
        rgbFrame.linesize = _picture.linesize[0];
        rgbFrame.rgb = [NSData dataWithBytes:_picture.data[0]
                                      length:rgbFrame.linesize * _videoCodecCtx->height];
        frame = rgbFrame;
    }
    
    frame.width = _videoCodecCtx->width;
    frame.height = _videoCodecCtx->height;
    frame.position = av_frame_get_best_effort_timestamp(_videoFrame) * _videoTimeBase;
    
    const int64_t frameDuration = av_frame_get_pkt_duration(_videoFrame);
    if (frameDuration) {
        
        frame.duration = frameDuration * _videoTimeBase;
        frame.duration += _videoFrame->repeat_pict * _videoTimeBase * 0.5;
        
        //if (_videoFrame->repeat_pict > 0) {
        //    LoggerVideo(0, @"_videoFrame.repeat_pict %d", _videoFrame->repeat_pict);
        //}
        
    } else {
        
        // sometimes, ffmpeg unable to determine a frame duration
        // as example yuvj420p stream from web camera
        frame.duration = 1.0 / _fps;
    }
    
    
    return frame;
}

-(FBAudioFrame *)handleAudioFrame {
    
    if (!_audioFrame->data[0])
        return nil;
    
    FBAudioManager *audioManager = [FBAudioManager audioManager];
    const NSUInteger numChannels = audioManager.numOutputChannels;
    NSInteger numFrames;
    
    void *audioData;
    
    if (_swrContext) {
        const NSUInteger ratio = MAX(1, audioManager.samplingRate / _audioCodecCtx->sample_rate) *
        MAX(1, audioManager.numOutputChannels / _audioCodecCtx->channels) * 2;
        
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       audioManager.numOutputChannels,
                                                       (int)(_audioFrame->nb_samples * ratio),
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        
        if (!_swrBuffer || _swrBufferSize < bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = { _swrBuffer, 0 };
        
        numFrames = swr_convert(_swrContext,
                                outbuf,
                                (int)(_audioFrame->nb_samples * ratio),
                                (const uint8_t **)_audioFrame->data,
                                _audioFrame->nb_samples);
        
        if (numFrames < 0) {
            NSLog(@"---------->>>>>>>>>>>> fail resample audio");
            return nil;
        }
        
        
        audioData = _swrBuffer;
        
    } else {
        if (_audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSLog(@"---------->>>>>>>>>>>> bugcheck, audio format is invalid");
            return nil;
        }
        
        audioData = _audioFrame->data[0];
        numFrames = _audioFrame->nb_samples;
    }
    
    const NSUInteger numElements = numFrames * numChannels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    FBAudioFrame *frame = [[FBAudioFrame alloc] init];
    frame.position = av_frame_get_best_effort_timestamp(_audioFrame) * _audioTimeBase;
    frame.duration = av_frame_get_pkt_duration(_audioFrame) * _audioTimeBase;
    frame.samples = data;
    
    if (frame.duration == 0) {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        frame.duration = frame.samples.length / (sizeof(float) * numChannels * audioManager.samplingRate);
    }
    
#if 0
    NSLog(@"AFD: %.4f %.4f | %.4f ",
                frame.position,
                frame.duration,
                frame.samples.length / (sizeof(float) * audioManager.samplingRate));
#endif
    
    return frame;
}

//- (KxSubtitleFrame *) handleSubtitle: (AVSubtitle *)pSubtitle {
//
//    NSMutableString *ms = [NSMutableString string];
//
//    for (NSUInteger i = 0; i < pSubtitle->num_rects; ++i) {
//
//        AVSubtitleRect *rect = pSubtitle->rects[i];
//        if (rect) {
//
//            if (rect->text) { // rect->type == SUBTITLE_TEXT
//
//                NSString *s = [NSString stringWithUTF8String:rect->text];
//                if (s.length) [ms appendString:s];
//
//            } else if (rect->ass && _subtitleASSEvents != -1) {
//
//                NSString *s = [NSString stringWithUTF8String:rect->ass];
//                if (s.length) {
//
//                    NSArray *fields = [KxMovieSubtitleASSParser parseDialogue:s numFields:_subtitleASSEvents];
//                    if (fields.count && [fields.lastObject length]) {
//
//                        s = [KxMovieSubtitleASSParser removeCommandsFromEventText: fields.lastObject];
//                        if (s.length) [ms appendString:s];
//                    }
//                }
//            }
//        }
//    }
//
//    if (!ms.length)
//        return nil;
//
//    KxSubtitleFrame *frame = [[KxSubtitleFrame alloc] init];
//    frame.text = [ms copy];
//    frame.position = pSubtitle->pts / AV_TIME_BASE + pSubtitle->start_display_time;
//    frame.duration = (CGFloat)(pSubtitle->end_display_time - pSubtitle->start_display_time) / 1000.f;
//
//#if 0
//    LoggerStream(2, @"SUB: %.4f %.4f | %@",
//                 frame.position,
//                 frame.duration,
//                 frame.text);
//#endif
//
//    return frame;
//}

- (BOOL) setupVideoFrameFormat: (FBVideoFrameFormat) format {
    if (format == FBVideoFrameFormatYUV &&
        _videoCodecCtx &&
        (_videoCodecCtx->pix_fmt == AV_PIX_FMT_YUV420P || _videoCodecCtx->pix_fmt == AV_PIX_FMT_YUVJ420P)) {
        
        _videoFrameFormat = FBVideoFrameFormatYUV;
        return YES;
    }
    
    _videoFrameFormat = FBVideoFrameFormatRGB;
    return _videoFrameFormat == format;
}


#pragma mark -- getters
- (NSString*)moviePath {
    return _moviePath;
}

- (CGFloat)duration {
    if (!_formatCtx) {
        return 0.0;
    }
    
    if (AV_NOPTS_VALUE == _formatCtx->duration) {
        return MAXFLOAT;
    }
    
    return _formatCtx->duration / AV_TIME_BASE;
}

- (CGFloat)position {
    return _position;
}

- (void)setPosition:(CGFloat)position {
    
    NSLog(@"-------->>>>>>>>>> seek to : %f", position);
    
    _position = position;
    _isEOF = NO;
    
    if (_videoStreamIndex >= 0) {
        int64_t ts = (int64_t)(_position / _videoTimeBase);
        avformat_seek_file(_formatCtx, (int)_videoStreamIndex, ts, ts, ts, AVSEEK_FLAG_FRAME);
        avcodec_flush_buffers(_videoCodecCtx);
    }
    
    if (_audioStreamIndex >= 0) {
        int64_t ts = (int64_t)(_position / _audioTimeBase);
        avformat_seek_file(_formatCtx, (int)_audioStreamIndex, ts, ts, ts, AVSEEK_FLAG_FRAME);
        avcodec_flush_buffers(_audioCodecCtx);
    }
}

- (CGFloat)startTime {
    if (_videoStreamIndex >= 0) {
        AVStream *st = _formatCtx->streams[_videoStreamIndex];
        if (AV_NOPTS_VALUE != st->start_time) {
            return st->start_time * _videoTimeBase;
        }
        return 0.0;
    }
    
    if (_audioStreamIndex >= 0) {
        AVStream *st = _formatCtx->streams[_audioStreamIndex];
        if (AV_NOPTS_VALUE != st->start_time) {
            return st->start_time * _audioTimeBase;
        }
        return 0.0;
    }
    
    return 0.0;
}

- (CGFloat)fps {
    return _fps;
}

- (NSUInteger)frameWidth {
    return _videoCodecCtx ? _videoCodecCtx->width : 0;
}

- (NSUInteger)frameHeight {
    return _videoCodecCtx ? _videoCodecCtx->height : 0;
}

- (BOOL)hasVideo {
    return _videoStreamIndex >= 0;
}

- (BOOL)hasAudio {
    return _audioStreamIndex >= 0;
}

- (FBVideoFrameFormat)videoFrameFormat {
    return _videoFrameFormat;
}


@end
