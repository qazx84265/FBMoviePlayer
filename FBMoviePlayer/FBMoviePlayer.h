//
//  FBMoviePlayer.h
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 */
typedef void (^moviePlayerDidEndPlay)();


@interface FBMoviePlayer : NSObject

/**
 * view where movie picture rended in
 * 播放器画面
 */
@property (nonatomic, strong, readonly) UIView *playerView;

/**
 * whether enable audio, default YES;\n
 * 是否播放声音，默认 YES
 */
@property (nonatomic, assign, getter=isAudioEnabled) BOOL audioEnabled;

@property (nonatomic, assign, readonly) BOOL isPlaying;

@property (nonatomic, copy, readonly) NSString* moviePath;

/**
 * movie duration,
 * 视频时长
 */
@property (nonatomic, assign, readonly) CGFloat movieDuration;

@property (nonatomic, assign, readonly) CGFloat playedPosition;

@property (nonatomic, assign, readonly) CGFloat buffedPosition;

@property (nonatomic, assign, readonly) CGFloat playingProgress;

@property (nonatomic, assign, readonly) CGFloat bufferingProgress;


- (instancetype)initWithMovie:(NSString*)moviePath;

+ (instancetype)playerWithMovie:(NSString*)moviePath;

//- (void)playMovie:(NSString*)moviePath;

- (void)play;

- (void)pause;

- (void)stop;

- (void)setMoviePosition:(CGFloat)position;

@end
