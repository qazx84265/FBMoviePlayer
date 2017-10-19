//
//  FBMovieDecoder.h
//  TinyVideo
//
//  Created by FB on 2017/10/13.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FBMovieFrame.h"



#pragma mark -- FBMovieDecoder
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

@property (nonatomic, assign, readonly) FBVideoFrameFormat videoFrameFormat;

@property (nonatomic, strong, readonly) FBVideoFrame* currentVideoFrame;

/**************************************
 *     initializer not avaliable      *
 **************************************/
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;


/**************************************
 *     initializer  avaliable         *
 **************************************/
- (instancetype)initWithMovie:(NSString*)moviePath;
+ (instancetype)decoderWithMovie:(NSString*)moviePath;

- (BOOL)openMovieAtPath:(NSString*)moviePath;

- (BOOL)prepareForDecode;

- (BOOL)setupVideoFrameFormat:(FBVideoFrameFormat)format;

- (NSArray<FBMovieFrame*>*)decodeFramesWithDuration:(CGFloat)duration;


@end


