#import <UIKit/UIKit.h>
// A view backed by a CAEAGLLayer. The runner thread draws into it through sunky_gl_* (GameView.m).
@interface GameView : UIView
+ (GameView *)current;
- (void)makeCurrent;
@end
