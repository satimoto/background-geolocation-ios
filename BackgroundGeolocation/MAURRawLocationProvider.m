//
//  MAURRawLocationProvider.m
//  BackgroundGeolocation
//
//  Created by Marian Hello on 06/11/2017.
//  Copyright © 2017 mauron85. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MAURRawLocationProvider.h"
#import "MAURLocationManager.h"
#import "MAURLogging.h"

static NSString * const TAG = @"RawLocationProvider";
static NSString * const Domain = @"com.marianhello";

@implementation MAURRawLocationProvider {

    BOOL isStarted;
    BOOL didDeferredLocationError;
    MAURLocationManager *locationManager;
    
    MAURConfig *_config;
}

- (instancetype) init
{
    self = [super init];

    if (self) {
        isStarted = NO;
        didDeferredLocationError = NO;
    }

    return self;
}

- (void) onCreate {
    locationManager = [MAURLocationManager sharedInstance];
    locationManager.delegate = self;
}

- (BOOL) onConfigure:(MAURConfig*)config error:(NSError * __autoreleasing *)outError
{
    DDLogVerbose(@"%@ configure", TAG);
    _config = config;
    didDeferredLocationError = NO;

    locationManager.pausesLocationUpdatesAutomatically = [config pauseLocationUpdates];
    locationManager.activityType = [config decodeActivityType];
    locationManager.distanceFilter = config.distanceFilter.integerValue; // meters
    locationManager.desiredAccuracy = [config decodeDesiredAccuracy];

    return YES;
}

- (BOOL) onStart:(NSError * __autoreleasing *)outError
{
    DDLogInfo(@"%@ will start", TAG);

    if (!isStarted) {
        [locationManager stopMonitoringSignificantLocationChanges];
        isStarted = [locationManager start:outError];
    }

    return isStarted;
}

- (BOOL) onStop:(NSError * __autoreleasing *)outError
{
    DDLogInfo(@"%@ will stop", TAG);

    if (!isStarted) {
        return YES;
    }

    [locationManager stopMonitoringSignificantLocationChanges];
    if ([locationManager stop:outError]) {
        isStarted = NO;
        didDeferredLocationError = NO;
        return YES;
    }

    return NO;
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    DDLogDebug(@"%@ didUpdateLocations", TAG);

    if (!didDeferredLocationError) {
        CLLocationDistance deferredDistance = _config.distanceFilter.integerValue; // meters
        NSInteger deferredInterval = _config.interval.integerValue / 1000; // seconds
        [locationManager allowDeferredLocationUpdatesUntilTraveled:deferredDistance timeout:deferredInterval];
    }

    for (CLLocation *location in locations) {
        MAURLocation *bgloc = [MAURLocation fromCLLocation:location];
        [super.delegate onLocationChanged:bgloc];
    }
}

- (void) locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error
{
    if (error != nil) {
        didDeferredLocationError = YES;
        [self.delegate onError:error];
    }
}

- (void) onTerminate
{
    if (isStarted && !_config.stopOnTerminate) {
        [locationManager startMonitoringSignificantLocationChanges];
    }
}

- (void) onAuthorizationChanged:(MAURLocationAuthorizationStatus)authStatus
{
    [self.delegate onAuthorizationChanged:authStatus];
}

- (void) onError:(NSError*)error
{
    [self.delegate onError:error];
}

- (void) onPause:(CLLocationManager*)manager
{
    [self.delegate onLocationPause];
}

- (void) onResume:(CLLocationManager*)manager
{
    [self.delegate onLocationResume];
}

- (void) onDestroy {
    DDLogInfo(@"Destroying %@ ", TAG);
    [self onStop:nil];
}

- (void) dealloc
{
    //    locationController.delegate = nil;
}

@end

