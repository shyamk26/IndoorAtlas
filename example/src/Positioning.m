#import <IndoorAtlas/IndoorAtlas.h>
#import <AudioToolbox/AudioServices.h>
#import "IDAAlertView.h"
#import "AppDelegate.h"

@interface AppDelegate () <IndoorAtlasPositionerDelegate, IndoorAtlasBackgroundCalibratorDelegate>
@property (nonatomic, strong) IndoorAtlasPositioner *IDAPositioner;
@property (nonatomic, strong) IndoorAtlasFloorplan *floorplan;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIView *circle;
@end

@implementation AppDelegate

#pragma mark Explicit position

/**
 * Explicit position by tapping floor plan example
 */
- (void)tapped:(UITapGestureRecognizer*)tap
{
    CGPoint point = [tap locationInView:self.imageView];
    [self.IDAPositioner submitExplicitPixelPosition:(IndoorAtlasPixel){point.x, point.y} withRadius:3.0f * self.IDAPositioner.floorplan.meterToPixelConversion];
}

#pragma mark IndoorAtlasBackgroundCalibratorDelegate methods

/**
 * Background calibrator state changed.
 *
 * The possible states are:
 *  - kIndoorAtlasBackgroundCalibratorStateStopped
 *  - kIndoorAtlasBackgroundCalibratorStateRunning
 */
- (void)indoorAtlasBackgroundCalibratorStateChanged:(IndoorAtlasBackgroundCalibratorState)state
{
    static NSString *map[] = {
        @"kIndoorAtlasBackgroundCalibratorStateStopped",
        @"kIndoorAtlasBackgroundCalibratorStateRunning",
    };
    NSLog(@"background calibrator state changed to %@ (%d)", map[state], state);
}

/**
 * Background calibrator quality indication.
 * Better quality will give better positioning performance.
 */
- (void)indoorAtlasBackgroundCalibratorQualityChanged:(IndoorAtlasCalibrationQuality)quality
{
    static NSString *map[] = {
        @"kIndoorAtlasQualityPoor",
        @"kIndoorAtlasQualityOk",
        @"kIndoorAtlasQualityExcellent",
    };
    NSLog(@"background calibrator quality: %@ (%d)", map[quality], quality);
}

#pragma mark IndoorAtlasPositionerDelegate methods

/**
 * Position packet handling from IndoorAtlasPositioner
 */
- (void)indoorAtlasPositioner:(IndoorAtlasPositioner*)positioner positionChanged:(IndoorAtlasPosition*)position
{
    (void)positioner;

    // You may also get metric and coordinate position from the packet.
    // The accuracy of coordinate position depends on the placement of floor plan image.
    NSLog(@"position changed to pixel point: %dx%d", position.pixelPoint.x, position.pixelPoint.y);

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:(self.circle.hidden ? 0.0f : 0.35f) animations:^{
        weakSelf.circle.center = CGPointMake(position.pixelPoint.x, position.pixelPoint.y);
    }];

    self.circle.hidden = NO;
}

/**
 * State packet handling from IndoorAtlasPositioner
 *
 * Possible states are:
 *    - kIndoorAtlasPositioningStateStopped
 *    - kIndoorAtlasPositioningStateConnecting
 *    - kIndoorAtlasPositioningStateReconnecting
 *    - kIndoorAtlasPositioningStateConnected
 *    - kIndoorAtlasPositioningStateLoading
 *    - kIndoorAtlasPositioningStateReady
 *    - kIndoorAtlasPositioningStateWaitingForFix
 *    - kIndoorAtlasPositioningStatePositioning
 *    - kIndoorAtlasPositioningStateBuffering
 *    - kIndoorAtlasPositioningStateHeavyBuffering
 *
 * 'Stopped' means that the positioner is disconnected from server.
 * 'Connecting' means that the positioner is connecting to the server.
 * 'Reconnecting' means that the positioner is reconnecting to the server.
 * 'Connected' means that the positioner is connected to the server.
 * 'Loading' means that the server is preparing for positioning.
 * 'Ready' means that map is ready on the server side.
 * 'WaitingForFix' means that positioner is waiting for first position.
 * 'Buffering' means that we have sent unsual amount of data which we have not recieved any response for.
 * 'Positioning' means that we are positioning.
 * 'HeavyBuffering' means that we have a lots of sent data which we have not recieved any response for.
 * 'HeavyBuffering' state will immediately change to 'Buffering' state when we receive one packet.
 */
- (void)indoorAtlasPositioner:(IndoorAtlasPositioner*)positioner stateChanged:(IndoorAtlasPositionerState*)state
{
    static NSString *map[] = {
        @"kIndoorAtlasPositioningStateStopped",
        @"kIndoorAtlasPositioningStateConnecting",
        @"kIndoorAtlasPositioningStateReconnecting",
        @"kIndoorAtlasPositioningStateConnected",
        @"kIndoorAtlasPositioningStateLoading",
        @"kIndoorAtlasPositioningStateReady",
        @"kIndoorAtlasPositioningStateWaitingForFix",
        @"kIndoorAtlasPositioningStatePositioning"
        @"kIndoorAtlasPositioningStateBuffering",
        @"kIndoorAtlasPositioningStateHeavyBuffering",
    };

    if (state.error) {
        NSLog(@"state changed to %@ (%d) because of error %@", map[state.state], state.state, state.error);
    } else {
        NSLog(@"state changed to %@ (%d)", map[state.state], state.state);
    }

    if (state.state == kIndoorAtlasPositioningStateStopped) {
        self.circle.hidden = YES;

        if (positioner.floorplan == self.floorplan) {
            // Start again from calibration if positioning stopped and floor plan was not changed
            [self performSelector:@selector(startPositioningWithFloorplan:) withObject:positioner.floorplan afterDelay:1.0f];
        }

        [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    } else {
        // It is good idea to disable idle timer when positioning.
        // This prevents the screen from dimming.
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    }

    // Color indicates the state of connection.
    self.circle.backgroundColor = (state.state == kIndoorAtlasPositioningStateBuffering ? [UIColor yellowColor] : (state.state == kIndoorAtlasPositioningStateHeavyBuffering ? [UIColor redColor] : [UIColor blueColor]));
}

#pragma mark IndoorAtlas API Usage

/**
 * Step 2: Create positioner and start positioning
 */
- (void)startPositioningWithFloorplan:(IndoorAtlasFloorplan*)floorplan
{
    [self.IDAPositioner stop];

    IDAAlertView *alert = [[IDAAlertView alloc] initWithTitle:nil message:@"Press 'Start' to start positioning" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Start", nil];

    __weak typeof(self) weakSelf = self;
    [alert addBlock:^{
        weakSelf.IDAPositioner = [IndoorAtlas positionerForFloorplan:floorplan];
        weakSelf.IDAPositioner.delegate = weakSelf;
        [weakSelf.IDAPositioner start];
    } forButtonIndex:alert.firstOtherButtonIndex];

    [alert show];
}

/**
 * Step 1: Fetch floor plan and image with ID
 * These methods are just wrappers around server requests.
 * You will need api key and secret to fetch resources.
 */
- (void)fetchFloorplanWithId:(NSString*)floorplanId
{
    __weak typeof(self) weakSelf = self;
   [IndoorAtlas fetchFloorplanWithId:floorplanId completion:^(IndoorAtlasFloorplan *floorplan, NSError *error) {
       if (error) {
           NSLog(@"opps, there was error during floorplan fetch: %@", error);
           [weakSelf performSelector:@selector(fetchFloorplanWithId:) withObject:floorplanId afterDelay:2.0f];
           return;
       }

       NSLog(@"fetched floorplan with id: %@", floorplanId);

       [IndoorAtlas fetchFloorplanImage:floorplan completion:^(NSData *data, NSError *error) {
           if (error) {
               NSLog(@"opps, there was error during floorplan image fetch: %@", error);
               return;
           }

           UIImage *image = [UIImage imageWithData:data];

           float scale = 1.0f;
           if (floorplan.width > floorplan.height) {
               scale = fmin(1.0, fmin(weakSelf.window.bounds.size.width / floorplan.height, weakSelf.window.bounds.size.height / floorplan.width));
           } else {
               scale = fmin(1.0, fmin(weakSelf.window.bounds.size.width / floorplan.width, weakSelf.window.bounds.size.height / floorplan.height));
           }

           CGAffineTransform t = CGAffineTransformMakeScale(scale, scale);
           if (floorplan.width > floorplan.height)
               t = CGAffineTransformRotate(t, M_PI_2);

           weakSelf.imageView.transform = CGAffineTransformIdentity;
           weakSelf.imageView.image = image;
           weakSelf.imageView.frame = CGRectMake(0, 0, floorplan.width, floorplan.height);
           weakSelf.imageView.transform = t;
           weakSelf.imageView.center = weakSelf.window.center;

           // 0.5 meters in pixels
           float size = floorplan.meterToPixelConversion * 0.5f;
           weakSelf.circle.transform = CGAffineTransformMakeScale(size, size);
       }];

       weakSelf.floorplan = floorplan;
       [weakSelf startPositioningWithFloorplan:floorplan];
   }];
}

/**
 * Authenticate to IndoorAtlas services
 */
- (void)authenticateAndFetchFloorplan
{
    // Implementing this delegate allows you to listen to background calibrator events
    [IndoorAtlasBackgroundCalibrator setDelegate:self];

    // Get SDK version
    NSLog(@"SDK Version: %@", [IndoorAtlas versionString]);

    if (kAPIKey.length <= 0 || kAPISecret.length <= 0) {
        NSLog(@"Set API key and secret in AppDelegate.h before running this example.");
        return;
    }

    // Set IndoorAtlas API key and secret
    [IndoorAtlas setApiKey:kAPIKey andSecret:kAPISecret];

    if (kFloorplanId.length <= 0) {
        NSLog(@"Set floor plan id in AppDelegate.h before running this example.");
        return;
    }

    // Fetch floor plan
    [self fetchFloorplanWithId:kFloorplanId];
}

#pragma mark AppDelegate boilerplate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    (void)application; (void)launchOptions;

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [UIViewController new];
    self.window.backgroundColor = [UIColor colorWithRed:0.0f / 255.0f green:165.0f / 255.0f blue:245.0f / 255.0f alpha:1.0f];
    [self.window makeKeyAndVisible];

    self.imageView = [UIImageView new];
    [self.window addSubview:self.imageView];

    self.imageView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self.imageView addGestureRecognizer:tap];

    self.circle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    self.circle.backgroundColor = [UIColor blueColor];
    self.circle.hidden = YES;
    [self.imageView addSubview:self.circle];

    [self authenticateAndFetchFloorplan];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    (void)application;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    (void)application;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    (void)application;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    (void)application;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    (void)application;
}

@end

/* vim: set ts=8 sw=4 tw=0 ft=objc :*/
