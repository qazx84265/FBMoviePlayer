//
//  FBMoviePlayer.m
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import "FBMoviePlayer.h"

#import "FBMoviePlayerView.h"
#import "FBMovieDecoder.h"
#import "FBAudioManager.h"

#import "FBMovieDefs.h"


#define LOCAL_MIN_BUFFERED_DURATION   0.2
#define LOCAL_MAX_BUFFERED_DURATION   0.4
#define NETWORK_MIN_BUFFERED_DURATION 2.0
#define NETWORK_MAX_BUFFERED_DURATION 4.0

NSString* const kMoviePlayerDidCompletedNotification = @"play.end.noti";
NSString* const kMoviePlayerBeginBuffNotification = @"buff.begin.noti";
NSString* const kMoviePlayerEndBuffNotification = @"buff.end.noti";


@interface FBMoviePlayer() {
    FBMoviePlayerView *_glView;
    UIImageView *_imageView;
    id<KxAudioManager> _audioManager;
    FBMovieDecoder *_decoder;
    
    dispatch_queue_t    _decodeQueue;
    
    NSMutableArray      *_videoFrames;
    NSMutableArray      *_audioFrames;
    
    NSMutableArray      *_subtitles;
    
    NSData              *_currentAudioFrame;
    NSUInteger          _currentAudioFramePos;
    
    CGFloat             _moviePosition;
    
    NSTimeInterval      _tickCorrectionTime;
    NSTimeInterval      _tickCorrectionPosition;
    NSUInteger          _tickCounter;
    
    BOOL _isBuffering;
    CGFloat             _bufferedDuration;
    CGFloat             _minBufferedDuration;
    CGFloat             _maxBufferedDuration;
    CGFloat _bufferdPosition; //valid when movie duration is known
    
    BOOL _isDecoding;
    
    BOOL _isPlaying;
}
@property (nonatomic, copy, readwrite) NSString *moviePath;
@property (nonatomic, assign, readwrite) CGFloat movieDuration;
@property (nonatomic, assign, readwrite) CGFloat playedPosition;
@property (nonatomic, assign, readwrite) CGFloat playingProgress;
@end


@implementation FBMoviePlayer

@synthesize audioEnabled = _audioEnabled;

- (instancetype)initWithMovie:(NSString *)moviePath {
    if (self = [super init]) {
        self.moviePath = moviePath;
        
        [self commonInit];
    }
    return self;
}

+ (instancetype)playerWithMovie:(NSString *)moviePath {
    return [[FBMoviePlayer alloc] initWithMovie:moviePath];
}

- (void)commonInit {
    
    NSAssert(self.moviePath, @"err: movie path should not be nil");
    
    self.audioEnabled = YES;
    _moviePosition = 0;
    
    _decodeQueue  = dispatch_queue_create("movie.player", DISPATCH_QUEUE_SERIAL);
    _videoFrames    = [NSMutableArray array];
    _audioFrames    = [NSMutableArray array];
    
    
    _audioManager = [KxAudioManager audioManager];
    [_audioManager activateAudioSession];
    
    
    _decoder = [FBMovieDecoder decoderWithMovie:self.moviePath];
    if (![_decoder prepareForDecode]) {
        NSLog(@"-------->>>>>>>>>>> err: falied to prepare decoder");
        return;
    }
    
    if (_decoder.isNetworkMovie) {
        _minBufferedDuration = NETWORK_MIN_BUFFERED_DURATION;
        _maxBufferedDuration = NETWORK_MAX_BUFFERED_DURATION;
    } else {
        _minBufferedDuration = LOCAL_MIN_BUFFERED_DURATION;
        _maxBufferedDuration = LOCAL_MAX_BUFFERED_DURATION;
    }
    
    if (!_decoder.hasVideo) {
        _minBufferedDuration *= 10.0; // increase for audio
    }
    
    [self setPresentView];
}

- (void)setPresentView {
    CGRect rect = [UIApplication sharedApplication].keyWindow.bounds;
    
    if (_decoder.hasVideo) {
        _glView = [[FBMoviePlayerView alloc] initWithFrame:rect decoder:_decoder];
        _glView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    if (!_glView) {
        NSLog(@"------->>>>>>>>>>> use UIKit && RGB to render video frame");
        [_decoder setupVideoFrameFormat:FBVideoFrameFormatRGB];
        _imageView = [[UIImageView alloc] initWithFrame:rect];
        _imageView.backgroundColor = [UIColor blackColor];
        _imageView.contentMode = UIViewContentModeCenter;
    }
    
    
}


#pragma mark -- setters && getters
- (BOOL)isPlaying {
    return _isPlaying;
}

- (void)setAudioEnabled:(BOOL)audioEnabled {
    _audioEnabled = audioEnabled;
}

- (BOOL)isAudioEnabled {
    return _audioEnabled;
}

- (UIView*)playerView {
    return _glView ? _glView : _imageView;
}

- (NSString*)moviePath {
    return _moviePath;
}


#pragma mark -- public

- (void)playMovie:(NSString *)moviePath {
    NSAssert(moviePath, @"err: movie path should not be nil");
    
    self.moviePath = moviePath;
    
    [self play];
}


- (void)play {
    
    if (_isPlaying) {
        return;
    }
    
    if (!_decoder.hasVideo &&
        !_decoder.hasAudio) {
        return;
    }
    
    _isPlaying = YES;
    
    _tickCorrectionTime = 0;
    _tickCounter = 0;
    
    [self asyncDecodeFrames];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
    
    if (self.audioEnabled && _decoder.hasAudio) {
        [self enableAudio:YES];
    }
}

- (void)pause {
    if (!_isPlaying) {
        return;
    }
    
    _isPlaying = NO;
    [self enableAudio:NO];
    
}

- (void)stop {
    
}

- (void)setDecoderPosition:(CGFloat)position {
    _decoder.position = position;
}

- (void) setMoviePositionFromDecoder {
    _moviePosition = _decoder.position;
}

- (void)setMoviePosition:(CGFloat)position {
    
    BOOL playMode = _isPlaying;
    
    _isPlaying = NO;
    
    [self enableAudio:NO];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self updatePosition:position playMode:playMode];
    });
}

- (void)updatePosition:(CGFloat)position playMode:(BOOL)playMode {
    
    
    [self freeBufferedFrames];
    
    position = MIN(_decoder.duration - 1, MAX(0, position));
    
    weakify(self)
    dispatch_async(_decodeQueue, ^{
        
        if (playMode) {
            strongify(self)
            [self setDecoderPosition:position];
            
            fbmovie_gcd_main_async_safe(^{
                strongify(self)
                [self setMoviePositionFromDecoder];
                [self play];
            })
            
        } else {
            strongify(self)
            [self setDecoderPosition:position];
            [self decodeFrames];
            
            fbmovie_gcd_main_async_safe(^{
                strongify(self)
                [self setMoviePositionFromDecoder];
                [self presentFrame];
            });
        }
    });
}

- (void) freeBufferedFrames {
    
    @synchronized(_videoFrames) {
        [_videoFrames removeAllObjects];
    }
    
    @synchronized(_audioFrames) {
        
        [_audioFrames removeAllObjects];
        _currentAudioFrame = nil;
    }
    
//    if (_subtitles) {
//        @synchronized(_subtitles) {
//            [_subtitles removeAllObjects];
//        }
//    }
    
    _bufferedDuration = 0;
}


#pragma mark -- private
- (BOOL) addFrames: (NSArray *)frames {
    if (_decoder.hasVideo) {
        @synchronized(_videoFrames) {
            for (FBMovieFrame *frame in frames) {
                if (frame.type == FBMovieFrameTypeVideo) {
                    [_videoFrames addObject:frame];
                    _bufferedDuration += frame.duration;
                }
            }
        }
    }
    
    if (_decoder.hasAudio) {
        @synchronized(_audioFrames) {
            for (FBMovieFrame *frame in frames) {
                if (frame.type == FBMovieFrameTypeAudio) {
                    [_audioFrames addObject:frame];
                    if (!_decoder.hasVideo)
                        _bufferedDuration += frame.duration;
                }
            }
        }
        
//        if (!_decoder.hasVideo) {
//            for (FBMovieFrame *frame in frames) {
//                if (frame.type == FBMovieFrameTypeArtwork) {
//                    self.artworkFrame = (KxArtworkFrame *)frame;
//                }
//            }
//        }
    }
    
//    if (_decoder.validSubtitles) {
//        @synchronized(_subtitles) {
//            for (FBMovieFrame *frame in frames) {
//                if (frame.type == FBMovieFrameTypeSubtitle) {
//                    [_subtitles addObject:frame];
//                }
//            }
//        }
//    }
    
    return _isPlaying && (_bufferedDuration < _maxBufferedDuration);
}

- (BOOL) decodeFrames {
    //NSAssert(dispatch_get_current_queue() == _dispatchQueue, @"bugcheck");
    
    NSArray *frames = nil;
    
    if (_decoder.hasVideo || _decoder.hasAudio) {
        frames = [_decoder decodeFramesWithDuration:0];
    }
    
    if (frames.count > 0) {
        return [self addFrames:frames];
    }
    return NO;
}

- (void) asyncDecodeFrames {
    
    if (_isDecoding)
        return;
    
    __weak __typeof(self) weakSelf = self;
    __weak __typeof(FBMovieDecoder*) weakDecoder = _decoder;
    
    const CGFloat duration = _decoder.isNetworkMovie ? .0f : 0.1f;
    
    _isDecoding = YES;
    dispatch_async(_decodeQueue, ^{
        if (!_isPlaying) {
            return;
        }
        
        BOOL good = YES;
        while (good) {
            good = NO;
            
            @autoreleasepool {
                __strong __typeof(FBMovieDecoder*) decoder = weakDecoder;
                
                if (decoder && (decoder.hasVideo || decoder.hasAudio)) {
                    
                    NSArray *frames = [decoder decodeFramesWithDuration:duration];
                    if (frames.count) {
                        __strong typeof(self) strongSelf = weakSelf;
                        if (strongSelf)
                            good = [strongSelf addFrames:frames];
                    }
                }
            }
        }
        
        _isDecoding = NO;
    });
}

- (void) tick {
    
    if (_isBuffering && ((_bufferedDuration > _minBufferedDuration) || _decoder.isEOF)) {
        
        _tickCorrectionTime = 0;
        _isBuffering = NO;
        
        [self endBuff];
    }
    
    CGFloat interval = 0;
    if (!_isBuffering)
        interval = [self presentFrame];
    
    if (_isPlaying) {
        
        const NSUInteger leftFrames =
        (_decoder.hasVideo ? _videoFrames.count : 0) +
        (_decoder.hasAudio ? _audioFrames.count : 0);
        
        if (0 == leftFrames) {
            if (_decoder.isEOF) {
                [self pause];
                [self updatePlayingStatus];
                [self playCompleted];
                
                return;
            }
            
            if (_minBufferedDuration > 0 && !_isBuffering) {
                
                _isBuffering = YES;
                [self beginBuff];
            }
        }
        
        if (!leftFrames ||
            !(_bufferedDuration > _minBufferedDuration)) {
            
            [self asyncDecodeFrames];
        }
        
        const NSTimeInterval correction = [self tickCorrection];
        const NSTimeInterval time = MAX(interval + correction, 0.01);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
    }
    
    if ((_tickCounter++ % 3) == 0) {
        [self updatePlayingStatus];
    }
}

- (CGFloat) tickCorrection {
    if (_isBuffering)
        return 0;
    
    const NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    
    if (!_tickCorrectionTime) {
        
        _tickCorrectionTime = now;
        _tickCorrectionPosition = _moviePosition;
        return 0;
    }
    
    NSTimeInterval dPosition = _moviePosition - _tickCorrectionPosition;
    NSTimeInterval dTime = now - _tickCorrectionTime;
    NSTimeInterval correction = dPosition - dTime;
    
    
    if (correction > 1.f || correction < -1.f) {
        
        NSLog(@"--------->>>>>>>>>>> tick correction reset %.2f", correction);
        correction = 0;
        _tickCorrectionTime = 0;
    }
    
    return correction;
}

- (void)updatePlayingStatus {
    self.playedPosition = _moviePosition - _decoder.startTime;
    CGFloat duration = _decoder.duration;
    
    if (duration > 0 && duration != MAXFLOAT) {
        self.movieDuration = duration;
        //self.playingProgress = self.playedPosition / self.movieDuration;
    }
}

- (void)playCompleted {
    _decoder.position = 0;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMoviePlayerDidCompletedNotification object:nil];
    
    if (self.completedHandler) {
        self.completedHandler();
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(moviePlayerDidCompleted:)]) {
        [self.delegate moviePlayerDidCompleted:self];
    }
}

- (void)beginBuff {
    [[NSNotificationCenter defaultCenter] postNotificationName:kMoviePlayerBeginBuffNotification object:nil];
}

- (void)endBuff {
    [[NSNotificationCenter defaultCenter] postNotificationName:kMoviePlayerEndBuffNotification object:nil];
}

- (CGFloat) presentFrame {
    
    CGFloat interval = 0;
    
    if (_decoder.hasVideo) {
        
        FBVideoFrame *frame;
        
        @synchronized(_videoFrames) {
            
            if (_videoFrames.count > 0) {
                
                frame = _videoFrames[0];
                [_videoFrames removeObjectAtIndex:0];
                _bufferedDuration -= frame.duration;
            }
        }
        
        if (frame)
            interval = [self presentVideoFrame:frame];
        
    } else if (_decoder.hasAudio) {
        
        //interval = _bufferedDuration * 0.5;
        
//        if (self.artworkFrame) {
//
//            _imageView.image = [self.artworkFrame asImage];
//            self.artworkFrame = nil;
//        }
    }
    
//    if (_decoder.validSubtitles)
//        [self presentSubtitles];
    
    return interval;
}

- (CGFloat) presentVideoFrame: (FBVideoFrame *) frame {
    
    if (_glView) {
        [_glView displayMovieFrame:frame];
        
    } else {
        FBVideoFrameRGB *rgbFrame = (FBVideoFrameRGB *)frame;
        _imageView.image = [rgbFrame asImage];
    }
    
    _moviePosition = frame.position;
    
    return frame.duration;
}

- (void) audioCallbackFillData: (float *) outData
                     numFrames: (UInt32) numFrames
                   numChannels: (UInt32) numChannels
{
    //fillSignalF(outData,numFrames,numChannels);
    //return;
    
    if (_isBuffering) {
        memset(outData, 0, numFrames * numChannels * sizeof(float));
        return;
    }
    
    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        FBAudioFrame *frame = _audioFrames[0];

                        if (_decoder.hasVideo) {
                            
                            const CGFloat delta = _moviePosition - frame.position;
                            
                            if (delta < -0.1) {
                                
                                memset(outData, 0, numFrames * numChannels * sizeof(float));
#ifdef DEBUG
                                NSLog(@"----->>>>>> desync audio (outrun) wait %.4f %.4f", _moviePosition, frame.position);
#endif
                                break; // silence and exit
                            }
                            
                            [_audioFrames removeObjectAtIndex:0];
                            
                            if (delta > 0.1 && count > 1) {
#ifdef DEBUG
                                NSLog(@"----->>>>>> desync audio (lags) skip %.4f %.4f", _moviePosition, frame.position);
#endif
                                continue;
                            }
                            
                        } else {
                            
                            [_audioFrames removeObjectAtIndex:0];
                            _moviePosition = frame.position;
                            _bufferedDuration -= frame.duration;
                        }
                        
                        _currentAudioFramePos = 0;
                        _currentAudioFrame = frame.samples;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                const void *bytes = (Byte *)_currentAudioFrame.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (_currentAudioFrame.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, bytes, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft)
                    _currentAudioFramePos += bytesToCopy;
                else
                    _currentAudioFrame = nil;
                
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //NSLog(@"---->>>>> silence audio");
                
                break;
            }
        }//while
    }//@autoreleasepool
}


- (void)enableAudio:(BOOL)on {
    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
    
    if (on && _decoder.hasAudio) {
        
        audioManager.outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
            [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
        };
        
        [audioManager play];
        
        NSLog(@"------->>>>>>>>audio device smr: %d fmt: %d chn: %d",
                    (int)audioManager.samplingRate,
                    (int)audioManager.numBytesPerSample,
                    (int)audioManager.numOutputChannels);
        
    } else {
        
        [audioManager pause];
        audioManager.outputBlock = nil;
    }
}

@end
