//
//  KxAudioManager.h
//  kxmovie
//
//  Created by Kolyvan on 23.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt


#import <CoreFoundation/CoreFoundation.h>

/**
 * data fill callback
 */
typedef void (^fbAudioManagerOutputHandler)(float *data, UInt32 numFrames, UInt32 numChannels);


@interface FBAudioManager : NSObject

@property (nonatomic, assign, readonly) UInt32             numOutputChannels;
@property (nonatomic, assign, readonly) Float64            samplingRate;
@property (nonatomic, assign, readonly) UInt32             numBytesPerSample;
@property (nonatomic, assign, readonly) Float32            outputVolume;
@property (nonatomic, assign, readonly) BOOL               playing;
@property (nonatomic, copy, readonly) NSString   *audioRoute;

@property (nonatomic, copy) fbAudioManagerOutputHandler outputHandler;

/**************************************
 *     initializer not avaliable      *
 **************************************/
//- (instancetype)init UNAVAILABLE_ATTRIBUTE;
//+ (instancetype)new UNAVAILABLE_ATTRIBUTE;


+ (instancetype)audioManager;


- (BOOL) activateAudioSession;
- (void) deactivateAudioSession;
- (BOOL) play;
- (void) pause;

@end



