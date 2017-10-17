//
//  FBAudioManager.m
//  TinyVideo
//
//  Created by FB on 2017/10/14.
//  Copyright © 2017年 FB. All rights reserved.
//

#import "FBAudioManager.h"

#import <AudioToolbox/AudioToolbox.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <TargetConditionals.h>

#define MAX_FRAME_SIZE 4096
#define MAX_CHAN       2

#define MAX_SAMPLE_DUMPED 5

static void* kOutputVolumeKVOCtx = &kOutputVolumeKVOCtx;

static BOOL checkError(OSStatus error, const char *operation);

static OSStatus renderCallback (void *inRefCon, AudioUnitRenderActionFlags    *ioActionFlags, const AudioTimeStamp * inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList* ioData);


@interface KxAudioManagerImpl : KxAudioManager<KxAudioManager> {
    
    BOOL                        _initialized;
    BOOL                        _activated;
    float                       *_outData;
    AudioUnit                   _audioUnit;
    AudioStreamBasicDescription _outputFormat;
}

@property (readonly) UInt32             numOutputChannels;
@property (readonly) Float64            samplingRate;
@property (readonly) UInt32             numBytesPerSample;
@property (readwrite) Float32           outputVolume;
@property (readonly) BOOL               playing;
@property (readonly, strong) NSString   *audioRoute;

@property (readwrite, copy) KxAudioManagerOutputBlock outputBlock;
@property (readwrite) BOOL playAfterSessionEndInterruption;

- (BOOL) activateAudioSession;
- (void) deactivateAudioSession;
- (BOOL) play;
- (void) pause;

- (BOOL) checkAudioRoute;
- (BOOL) setupAudio;
- (BOOL) checkSessionProperties;
- (BOOL) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData;

@end

@implementation KxAudioManager

+ (id<KxAudioManager>) audioManager
{
    static KxAudioManagerImpl *audioManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audioManager = [[KxAudioManagerImpl alloc] init];
    });
    return audioManager;
}

@end

@implementation KxAudioManagerImpl

- (id)init
{
    self = [super init];
    if (self) {
        
        _outData = (float *)calloc(MAX_FRAME_SIZE*MAX_CHAN, sizeof(float));
        _outputVolume = 0.5;
    }
    return self;
}

- (void)dealloc
{
    if (_outData) {
        
        free(_outData);
        _outData = NULL;
    }
}

#pragma mark - private

// Debug: dump the current frame data. Limited to 20 samples.

#define dumpAudioSamples(prefix, dataBuffer, samplePrintFormat, sampleCount, channelCount) \
{ \
NSMutableString *dump = [NSMutableString stringWithFormat:prefix]; \
for (int i = 0; i < MIN(MAX_SAMPLE_DUMPED, sampleCount); i++) \
{ \
for (int j = 0; j < channelCount; j++) \
{ \
[dump appendFormat:samplePrintFormat, dataBuffer[j + i * channelCount]]; \
} \
[dump appendFormat:@"\n"]; \
} \
NSLog(@"-------->>>>>>>>>> %@", dump); \
}

#define dumpAudioSamplesNonInterleaved(prefix, dataBuffer, samplePrintFormat, sampleCount, channelCount) \
{ \
NSMutableString *dump = [NSMutableString stringWithFormat:prefix]; \
for (int i = 0; i < MIN(MAX_SAMPLE_DUMPED, sampleCount); i++) \
{ \
for (int j = 0; j < channelCount; j++) \
{ \
[dump appendFormat:samplePrintFormat, dataBuffer[j][i]]; \
} \
[dump appendFormat:@"\n"]; \
} \
NSLog(@"-------->>>>>>>>>> %@", dump); \
}

- (BOOL)checkAudioRoute {
    // check the current audio route.
    AVAudioSessionRouteDescription* routeDes = [AVAudioSession sharedInstance].currentRoute;
    if (!routeDes) {
        NSLog(@"------->>>>>>>>>> couldn't check audio route");
        return NO;
    }
    
    NSArray<AVAudioSessionPortDescription *> *portDes = routeDes.outputs;
    if (!portDes || portDes.count == 0) {
        NSLog(@"------->>>>>>>>>> couldn't check audio route");
        return NO;
    }
    
    _audioRoute = portDes.firstObject.portName;
    NSLog(@"-------->>>>>>>>>> AudioRoute: %@", _audioRoute);
    return YES;
}

/**
 * setup audio session && audio unit
 */
- (BOOL) setupAudio {
    
    //------------- setup the audio session
    NSError *error = nil;
    BOOL result = NO;
    
    result = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!result || error) {
        NSLog(@"--------->>>>>>>> Couldn't set audio category");
        return NO;
    }

    // add event notis
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInterrupt:) name:AVAudioSessionInterruptionNotification object:nil];

    // monitor the outputVolume
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:kOutputVolumeKVOCtx];
    
    
#if !TARGET_IPHONE_SIMULATOR
    // Set the buffer size, this will affect the number of samples that get rendered every time the audio callback is fired
    // A small number will get you lower latency audio, but will make your processor work harder
    // Here, setup the bufferDuration to 23.2ms (which is the aac frame duration) for 44.1 khz sampleRate,
    // means the the audio unit render callback will invoks every 23.2ms.
    Float32 preferredBufferDuration = 0.0232;
    
    error = nil;
    result = [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferredBufferDuration error:&error];
    if (!result || error) {
        NSLog(@"------->>>>>>>>>> Couldn't set the preferred buffer duration");
    }
#endif
    
    
    // active the audio session
    error = nil;
    result = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!result || error) {
        NSLog(@"------->>>>>>>>>> Couldn't activate the audio session");
        return NO;
    }
    
    //
    [self checkSessionProperties];
    
    
    //---------- set audio unit
    
    // audio component desc
    AudioComponentDescription description = {0};
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = kAudioUnitSubType_RemoteIO;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent component = AudioComponentFindNext(NULL, &description);
    if (checkError(AudioComponentInstanceNew(component, &_audioUnit),
                   "Couldn't create the output audio unit")) {
        return NO;
    }
    
    UInt32 size;
    
    // Check the output stream format
    size = sizeof(AudioStreamBasicDescription);
    if (checkError(AudioUnitGetProperty(_audioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input,
                                        0,
                                        &_outputFormat,
                                        &size),
                   "Couldn't get the hardware output stream format")) {
        return NO;
    }
    
    
    _outputFormat.mSampleRate = _samplingRate;
    if (checkError(AudioUnitSetProperty(_audioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input,
                                        0,
                                        &_outputFormat,
                                        size),
                   "Couldn't set the hardware output stream format")) {
    }
    
    _numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
    _numOutputChannels = _outputFormat.mChannelsPerFrame;
    
    NSLog(@"Current output bytes per sample: %u", (unsigned int)_numBytesPerSample);
    NSLog(@"Current output num channels: %u", (unsigned int)_numOutputChannels);
    
    // Slap a render callback on the unit
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = renderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    if (checkError(AudioUnitSetProperty(_audioUnit,
                                        kAudioUnitProperty_SetRenderCallback,
                                        kAudioUnitScope_Input,
                                        0,
                                        &callbackStruct,
                                        sizeof(callbackStruct)),
                   "Couldn't set the render callback on the audio unit")) {
        return NO;
    }
    
    if (checkError(AudioUnitInitialize(_audioUnit),
                   "Couldn't initialize the audio unit")) {
        return NO;
    }
    
    return YES;
}

- (BOOL) checkSessionProperties {
    [self checkAudioRoute];
    
    
    UInt32 newNumChannels = (UInt32)[AVAudioSession sharedInstance].outputNumberOfChannels;
    NSLog(@"-------->>>>>>>>>> We've got %d output channels", (unsigned int)newNumChannels);
    
    _samplingRate = [AVAudioSession sharedInstance].sampleRate;
    NSLog(@"-------->>>>>>>>>> Current sampling rate: %f", _samplingRate);
    
    _outputVolume = [AVAudioSession sharedInstance].outputVolume;
    NSLog(@"-------->>>>>>>>>> Current output volume: %f", _outputVolume);
    
    return YES;
}

- (BOOL) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData {
    
    // reset buffers
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    // get buffers filled when playing
    if (_playing && _outputBlock ) {
        
        // Collect data to render from the callbacks
        _outputBlock(_outData, numFrames, _numOutputChannels);
        
        // Put the rendered data into the output buffer
        if (_numBytesPerSample == 4) // then we've already got floats
        {
            float zero = 0.0;
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                
                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    vDSP_vsadd(_outData+iChannel, _numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
                }
            }
        }
        else if (_numBytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
        {
            //            dumpAudioSamples(@"Audio frames decoded by FFmpeg:\n",
            //                             _outData, @"% 12.4f ", numFrames, _numOutputChannels);
            
            float scale = (float)INT16_MAX;
            vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_numOutputChannels);
            
#ifdef DUMP_AUDIO_DATA
            NSLog(@"-------->>>>>>>>>> Buffer %u - Output Channels %u - Samples %u",
                        (uint)ioData->mNumberBuffers, (uint)ioData->mBuffers[0].mNumberChannels, (uint)numFrames);
#endif
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                
                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    vDSP_vfix16(_outData+iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
                }
#ifdef DUMP_AUDIO_DATA
                dumpAudioSamples(@"Audio frames decoded by FFmpeg and reformatted:\n",
                                 ((SInt16 *)ioData->mBuffers[iBuffer].mData),
                                 @"% 8d ", numFrames, thisNumChannels);
#endif
            }
            
        }
    }
    
    return noErr;
}

#pragma mark - public

- (BOOL) activateAudioSession {
    
    if (!_activated) {
        
        if ([self checkAudioRoute] &&
            [self setupAudio]) {
            
            _activated = YES;
        }
    }
    
    return _activated;
}

- (void) deactivateAudioSession {
    
    if (_activated) {
        
        [self pause];
        
        checkError(AudioUnitUninitialize(_audioUnit),
                   "Couldn't uninitialize the audio unit");
        
        /*
         fails with error (-10851) ?
         
         checkError(AudioUnitSetProperty(_audioUnit,
         kAudioUnitProperty_SetRenderCallback,
         kAudioUnitScope_Input,
         0,
         NULL,
         0),
         "Couldn't clear the render callback on the audio unit");
         */
        
        checkError(AudioComponentInstanceDispose(_audioUnit),
                   "Couldn't dispose the output audio unit");
        
        //--
        NSError* error = nil;
        BOOL result = [[AVAudioSession sharedInstance] setActive:NO error:&error];
        if (!result || error) {
            NSLog(@"--------->>>>>>>> Couldn't deactivate the audio session, err: %@", [error localizedDescription]);
        }

        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
        
        _activated = NO;
    }
}

- (void) pause {
    if (_playing) {
        _playing = checkError(AudioOutputUnitStop(_audioUnit), "Couldn't stop the output unit");
    }
}

- (BOOL) play {
    if (!_playing) {
        if ([self activateAudioSession]) {
            _playing = !checkError(AudioOutputUnitStart(_audioUnit), "Couldn't start the output unit");
        }
    }
    
    return _playing;
}


#pragma mark -- noti
- (void)audioRouteChanged:(NSNotification*)noti {
    if ([self checkAudioRoute]) {
        [self checkSessionProperties];
    }
}


- (void)audioInterrupt:(NSNotification*)noti {
    AVAudioSessionInterruptionType type = [[noti.userInfo objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        self.playAfterSessionEndInterruption = self.playing;
        [self pause];
    }
    
    if (type == AVAudioSessionInterruptionTypeEnded) {
        NSNumber *seccondReason = [[noti userInfo] objectForKey:AVAudioSessionInterruptionOptionKey];
        switch ([seccondReason integerValue]) {
            case AVAudioSessionInterruptionOptionShouldResume:
                if (self.playAfterSessionEndInterruption) {
                    self.playAfterSessionEndInterruption = NO;
                    [self play];
                }
                break;
            default:
                break;
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context == kOutputVolumeKVOCtx) {
        if ([keyPath isEqualToString:@"outputVolume"]) {
            self.outputVolume = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark - callbacks

static OSStatus renderCallback (void                        *inRefCon,
                                AudioUnitRenderActionFlags    * ioActionFlags,
                                const AudioTimeStamp         * inTimeStamp,
                                UInt32                        inOutputBusNumber,
                                UInt32                        inNumberFrames,
                                AudioBufferList                * ioData)
{
    //NSLog(@"----->>>>>>>> audio unit render callback");
    KxAudioManagerImpl *sm = (__bridge KxAudioManagerImpl *)inRefCon;
    return [sm renderFrames:inNumberFrames ioData:ioData];
}

static BOOL checkError(OSStatus error, const char *operation)
{
    if (error == noErr)
        return NO;
    
    char str[20] = {0};
    // see if it appears to be a 4-char-code
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    } else
        // no, format it as an integer
        sprintf(str, "%d", (int)error);
    
    NSLog(@"-------->>>>>>>>>> Error: %s (%s)\n", operation, str);
    
    //exit(1);
    
    return YES;
}

