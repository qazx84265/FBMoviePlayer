//
//  FBMovieDecoder.h
//  TinyVideo
//
//  Created by FB on 2017/10/13.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    
    KxMovieFrameTypeAudio,
    KxMovieFrameTypeVideo,
    KxMovieFrameTypeArtwork,
    KxMovieFrameTypeSubtitle,
    
} KxMovieFrameType;

typedef enum {
    
    KxVideoFrameFormatRGB,
    KxVideoFrameFormatYUV,
    
} KxVideoFrameFormat;

@interface KxMovieFrame : NSObject
@property (readonly, nonatomic) KxMovieFrameType type;
@property (readonly, nonatomic) CGFloat position;
@property (readonly, nonatomic) CGFloat duration;
@end

@interface KxAudioFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSData *samples;
@end

@interface KxVideoFrame : KxMovieFrame
@property (readonly, nonatomic) KxVideoFrameFormat format;
@property (readonly, nonatomic) NSUInteger width;
@property (readonly, nonatomic) NSUInteger height;
@end

@interface KxVideoFrameRGB : KxVideoFrame
@property (readonly, nonatomic) NSUInteger linesize;
@property (readonly, nonatomic, strong) NSData *rgb;
- (UIImage *) asImage;
@end

@interface KxVideoFrameYUV : KxVideoFrame
@property (readonly, nonatomic, strong) NSData *luma;
@property (readonly, nonatomic, strong) NSData *chromaB;
@property (readonly, nonatomic, strong) NSData *chromaR;
@end

@interface KxArtworkFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSData *picture;
- (UIImage *) asImage;
@end

@interface KxSubtitleFrame : KxMovieFrame
@property (readonly, nonatomic, strong) NSString *text;
@end


@interface FBMovieDecoder : NSObject

@property (nonatomic, copy, readonly) NSString* moviePath;

@property (nonatomic, assign, readonly) BOOL isNetworkMovie;

@property (nonatomic, assign, readonly) BOOL isEOF;

@property (nonatomic, assign, readonly) CGFloat fps;

@property (nonatomic, assign, readonly) CGFloat sampleRate;

@property (nonatomic, assign, readonly) CGFloat startTime;

@property (nonatomic, assign, readonly) CGFloat duration;

@property (nonatomic, assign) CGFloat position;

@property (nonatomic, assign, readonly) NSUInteger frameWidth;
@property (nonatomic, assign, readonly) NSUInteger frameHeight;

@property (nonatomic, assign, readonly) BOOL hasVideo;
@property (nonatomic, assign, readonly) BOOL hasAudio;
@property (nonatomic, assign, readonly) BOOL hasSubtitle;

@property (nonatomic, assign, readonly) KxVideoFrameFormat videoFrameFormat;

@property (nonatomic, strong, readonly) KxVideoFrame* currentVideoFrame;


- (instancetype)initWithMovie:(NSString*)moviePath;
+ (instancetype)decoderWithMovie:(NSString*)moviePath;

- (BOOL)openMovieAtPath:(NSString*)moviePath;

- (BOOL)prepareForDecode;

- (BOOL)setupVideoFrameFormat:(KxVideoFrameFormat)format;

- (NSArray<KxMovieFrame*>*)decodeFramesWithDuration:(CGFloat)duration;

- (BOOL)stepFrame;
@end
