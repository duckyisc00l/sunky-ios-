#import <UIKit/UIKit.h>
#import "Sunky.h"
@interface GameViewController : UIViewController
- (instancetype)initWithGame:(const SunkyGame *)game exe:(NSString *)exePath title:(NSString *)title;
@end
