//
//  FBMovieDefs.h
//  TinyVideo
//
//  Created by FB on 2017/10/16.
//  Copyright © 2017年 FB. All rights reserved.
//

#ifndef FBMovieDefs_h
#define FBMovieDefs_h


#pragma mark -- noti


static NSString* const kMoviePlayerDidPreparedNotification = @"did.prepared.noti";
/**
 *
 */
static NSString* const kMoviePlayerDidCompletedNotification = @"play.end.noti";
/**
 *
 */
static NSString* const kMoviePlayerBeginBuffNotification = @"buff.begin.noti";
/**
 *
 */
static NSString* const kMoviePlayerEndBuffNotification = @"buff.end.noti";


#pragma mark -- Keys for notification userInfo dictionaries --
/* keys for kMoviePlayerDidPreparedNotification */
/* Value is an NSNumber representing an FBMovieError */
static NSString* const kMoviePlayerDidPreparedResultKey = @"did.prepared.noti.key";



#pragma mark -- error
static NSErrorDomain const FBMovieErrorDomain = @"fb.movie.err";

typedef NS_ENUM(NSInteger, FBMovieError) {
    FBMovieErrorNone, //no error
    FBMovieErrorOpenStream, //open stream error
    FBMovieErrorStreamInfoNotFound,
    FBMovieErrorStreamsNotFound,//no video && audio streams found
    FBMovieErrorCodecNotFound,
    FBMovieErrorOpenCodec,
    FBMovieErrorAllocFrame,
    FBMovieErrorSetupScaler,
    FBMovieErrorResampler,
    FBMovieErrorUnsupported,
    FBMovieErrorUnknown
};

static NSString* errorMessage(FBMovieError errorCode) {
    switch (errorCode) {
        case FBMovieErrorNone:
            return @"";
            break;
        case FBMovieErrorOpenStream:
            return NSLocalizedString(@"Unable to open file", nil);
            break;
            
        case FBMovieErrorStreamInfoNotFound:
            return NSLocalizedString(@"Unable to find stream information", nil);
            break;
            
        case FBMovieErrorStreamsNotFound:
            return NSLocalizedString(@"Unable to find stream", nil);
            break;
            
        case FBMovieErrorCodecNotFound:
            return NSLocalizedString(@"Unable to find codec", nil);
            break;
            
        case FBMovieErrorOpenCodec:
            return NSLocalizedString(@"Unable to open codec", nil);
            break;
            
        case FBMovieErrorAllocFrame:
            return NSLocalizedString(@"Unable to allocate frame", nil);
            break;
            
        case FBMovieErrorSetupScaler:
            return NSLocalizedString(@"Unable to setup scaler", nil);
            break;
            
        case FBMovieErrorResampler:
            return NSLocalizedString(@"Unable to setup resampler", nil);
            break;
            
        case FBMovieErrorUnsupported:
            return NSLocalizedString(@"The ability is not supported", nil);
            break;
        default:
            return @"";
    }
}

static NSError* movieError(FBMovieError errorCode) {
    
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : errorMessage(errorCode) };
    return [NSError errorWithDomain:FBMovieErrorDomain
                               code:errorCode
                           userInfo:userInfo];
}



// main thread sync
#define fbmovie_gcd_main_sync_safe(block) \
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_sync(dispatch_get_main_queue(), block);\
    }
// main thread async
#define fbmovie_gcd_main_async_safe(block)\
    if ([NSThread isMainThread]) {\
        block();\
    } else {\
        dispatch_async(dispatch_get_main_queue(), block);\
    }


// weak / strong dance
#define weakify(type) __weak __typeof(type) weak##type = type;

#define strongify(type) do {\
__strong __typeof(type) type = weak##type;\
if (nil == type) {\
    return;\
}\
}while(0);

#endif /* FBMovieDefs_h */
