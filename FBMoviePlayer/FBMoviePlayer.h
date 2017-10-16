//
//  FBMoviePlayer.h
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * called when movie is played to end
 */
typedef void (^moviePlayerDidCompletedHandler)();

//
@protocol FBMoviePlayerDelegate;

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
 * Is key-value observable
 */
@property (nonatomic, assign, readonly) CGFloat movieDuration;

/**
 * movie played position,
 * 已播放时长
 * Is key-value observable
 */
@property (nonatomic, assign, readonly) CGFloat playedPosition;

@property (nonatomic, assign, readonly) CGFloat buffedPosition;

/**
 * movie playing progress,
 * 播放进度
 * Is key-value observable
 */
@property (nonatomic, assign, readonly) CGFloat playingProgress;

@property (nonatomic, assign, readonly) CGFloat bufferingProgress;

// delegate
@property (nonatomic, weak) id<FBMoviePlayerDelegate> delegate;

@property (nonatomic, copy) moviePlayerDidCompletedHandler completedHandler;

//
- (instancetype)initWithMovie:(NSString*)moviePath;

+ (instancetype)playerWithMovie:(NSString*)moviePath;

//- (void)playMovie:(NSString*)moviePath;

- (void)play;

- (void)pause;

- (void)stop;

- (void)setMoviePosition:(CGFloat)position;

@end


#pragma mark -- delegate

@protocol FBMoviePlayerDelegate<NSObject>

@optional
/**
 * movie end,
 * 播放结束
 */
- (void)moviePlayerDidCompleted:(FBMoviePlayer*)player;

@end


FOUNDATION_EXTERN NSString* const kMoviePlayerDidCompletedNotification;
FOUNDATION_EXTERN NSString* const kMoviePlayerBeginBuffNotification;
FOUNDATION_EXTERN NSString* const kMoviePlayerEndBuffNotification;
