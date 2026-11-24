#import "AppDelegate.h"
#import "MenuViewController.h"
#import "Audio.h"
#import "Sunky.h"

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    [SunkyAudio start];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = UIColor.blackColor;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[MenuViewController new]];
    nav.navigationBarHidden = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
- (void)applicationWillResignActive:(UIApplication *)application {
    SunkySetPaused(YES); // the game waits (no drawing in the background) and goes quiet
    [SunkyAudio pause];
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    SunkySetPaused(NO);
    [SunkyAudio resume];
}
- (UIInterfaceOrientationMask)application:(UIApplication *)app supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}
@end
