// Runs one game: the runner on its own thread, drawing into a GameView, with on-screen controls.
//
// Controls (landscape): a D-pad on the left (arrow keys), JUMP on the right (Space), START above it
// (Enter), and a close button at the top left. Tapping the game itself is a mouse click, for menus
// like the character select. Game controllers and hardware keyboards work too.
#import "GameViewController.h"
#import "GameView.h"
#import "Sunky.h"
#import <GameController/GameController.h>

// ---- Runner thread ----

@interface GameViewController ()
@property (nonatomic, copy) NSString *exePath;
@property (nonatomic, copy) NSString *title_;
@property (nonatomic, strong) GameView *gameView;
@property (nonatomic, strong) UIView *dpad, *jump, *start, *closeButton;
@property (nonatomic, strong) UIView *dpadKnob;
@property (nonatomic) BOOL running;
@end

typedef NS_ENUM(NSInteger, TouchRole) { RoleNone, RoleDpad, RoleJump, RoleStart, RoleGame, RoleClose };

@implementation GameViewController {
    NSMapTable<UITouch *, NSNumber *> *_roles;
    UITouch *_mouseTouch;
    BOOL _dirDown[4]; // left, up, right, down (from the D-pad)
    BOOL _padDir[4];  // from a game controller
    UITouch *_dpadTouch;
}

- (instancetype)initWithExe:(NSString *)exePath title:(NSString *)title {
    if ((self = [super init])) {
        _exePath = [exePath copy];
        _title_ = [title copy];
        _roles = [NSMapTable strongToStrongObjectsMapTable];
    }
    return self;
}

- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeAll; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskLandscape; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.view.multipleTouchEnabled = YES;
    self.gameView = [[GameView alloc] initWithFrame:self.view.bounds];
    self.gameView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.gameView.userInteractionEnabled = NO; // touches are handled by this controller's view
    [self.view addSubview:self.gameView];

    self.dpad = [self pad];
    self.dpadKnob = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    self.dpadKnob.backgroundColor = [UIColor colorWithWhite:1 alpha:0.45];
    self.dpadKnob.layer.cornerRadius = 22;
    self.dpadKnob.userInteractionEnabled = NO;
    [self.dpad addSubview:self.dpadKnob];
    for (NSString *arrow in @[@"◀", @"▲", @"▶", @"▼"]) {
        UILabel *l = [UILabel new];
        l.text = arrow;
        l.textColor = [UIColor colorWithWhite:1 alpha:0.7];
        l.font = [UIFont boldSystemFontOfSize:20];
        l.tag = 100 + [@[@"◀", @"▲", @"▶", @"▼"] indexOfObject:arrow];
        [l sizeToFit];
        [self.dpad addSubview:l];
    }
    self.jump = [self buttonWithTitle:@"JUMP" size:96];
    self.start = [self buttonWithTitle:@"START" size:64];
    self.closeButton = [self buttonWithTitle:@"✕" size:40];
    for (UIView *v in @[self.dpad, self.jump, self.start, self.closeButton]) [self.view addSubview:v];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(controllerConnected:)
                                               name:GCControllerDidConnectNotification object:nil];
    for (GCController *c in GCController.controllers) [self setUpController:c];
}

- (UIView *)pad {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 150, 150)];
    v.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    v.layer.cornerRadius = 75;
    v.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    v.layer.borderWidth = 2;
    v.userInteractionEnabled = NO;
    return v;
}

- (UIView *)buttonWithTitle:(NSString *)title size:(CGFloat)size {
    UILabel *b = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    b.text = title;
    b.textAlignment = NSTextAlignmentCenter;
    b.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    b.font = [UIFont boldSystemFontOfSize:size > 60 ? 18 : (size > 50 ? 13 : 18)];
    b.backgroundColor = [UIColor colorWithWhite:1 alpha:0.15];
    b.layer.cornerRadius = size / 2;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.35].CGColor;
    b.layer.borderWidth = 2;
    b.clipsToBounds = YES;
    b.userInteractionEnabled = NO;
    return b;
}

/// Where the game picture is, in view points (same aspect fit as the runner).
- (CGRect)gameRect {
    uint32_t packed = ramen_ios_game_size();
    CGFloat gw = MAX(1, packed >> 16), gh = MAX(1, packed & 0xFFFF);
    CGSize b = self.view.bounds.size;
    CGFloat scale = MIN(b.width / gw, b.height / gh);
    CGFloat w = gw * scale, h = gh * scale;
    return CGRectMake((b.width - w) / 2, (b.height - h) / 2, w, h);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize b = self.view.bounds.size;
    CGFloat side = MAX(safe.left, 12), right = MAX(safe.right, 12), bottom = MAX(safe.bottom, 12);
    self.dpad.center = CGPointMake(side + 85, b.height - bottom - 85);
    self.jump.center = CGPointMake(b.width - right - 60, b.height - bottom - 70);
    self.start.center = CGPointMake(b.width - right - 40, self.jump.center.y - 100);
    self.closeButton.center = CGPointMake(side + 24, MAX(safe.top, 8) + 24);
    CGFloat c = 75;
    [self.dpad viewWithTag:100].center = CGPointMake(18, c);
    [self.dpad viewWithTag:101].center = CGPointMake(c, 18);
    [self.dpad viewWithTag:102].center = CGPointMake(150 - 18, c);
    [self.dpad viewWithTag:103].center = CGPointMake(c, 150 - 18);
    if (!_dpadTouch) self.dpadKnob.center = CGPointMake(c, c);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.running) return;
    self.running = YES;
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    [self.gameView makeCurrent];
    CGFloat s = self.gameView.contentScaleFactor;
    ramen_ios_resize((uint32_t)(self.gameView.bounds.size.width * s), (uint32_t)(self.gameView.bounds.size.height * s));
    NSString *path = self.exePath;
    __weak GameViewController *weakSelf = self;
    NSThread *t = [[NSThread alloc] initWithBlock:^{
        SunkyLog(@"starting %@", path);
        int32_t code = sunky_run_game(path.fileSystemRepresentation);
        udon_ios_stop();
        SunkyLog(@"game ended with code %d", code);
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf gameEnded:code]; });
    }];
    t.stackSize = 64 * 1024 * 1024; // GML scripts can recurse deeply
    [self scheduleTestKeys];
    t.qualityOfService = NSQualityOfServiceUserInteractive;
    [t start];
}

// Test hook for the Simulator run (ci/sim.sh): -sunkyAutoKeys "sec:vk:hold,..." presses keys on a timer.
- (void)scheduleTestKeys {
    NSString *spec = [NSUserDefaults.standardUserDefaults stringForKey:@"sunkyAutoKeys"];
    for (NSString *item in [spec componentsSeparatedByString:@","]) {
        NSArray *p = [item componentsSeparatedByString:@":"];
        if (p.count != 3) continue;
        double at = [p[0] doubleValue], hold = [p[2] doubleValue];
        uint32_t vk = (uint32_t)[p[1] intValue];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SunkyLog(@"test key %u down", vk);
            ramen_ios_key(vk, true);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((at + hold) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ramen_ios_key(vk, false);
        });
    }
}

- (void)gameEnded:(int32_t)code {
    UIApplication.sharedApplication.idleTimerDisabled = NO;
    if (code == 0) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"The game stopped"
        message:@"Something went wrong. The details are in log.txt (Files app → On My iPhone → Sunky)."
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)askToClose {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Quit %@?", self.title_]
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Keep playing" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Quit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        ramen_ios_request_close();
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

// ---- Keys ----

static const uint32_t kDirVK[4] = { VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN };

- (void)setDir:(int)i down:(BOOL)down {
    BOOL was = _dirDown[i] || _padDir[i];
    _dirDown[i] = down;
    BOOL now = _dirDown[i] || _padDir[i];
    if (was != now) ramen_ios_key(kDirVK[i], now);
}

- (void)setPadDir:(int)i down:(BOOL)down {
    BOOL was = _dirDown[i] || _padDir[i];
    _padDir[i] = down;
    BOOL now = _dirDown[i] || _padDir[i];
    if (was != now) ramen_ios_key(kDirVK[i], now);
}

- (void)updateDpadWithPoint:(CGPoint)p {
    CGPoint c = CGPointMake(75, 75);
    CGFloat dx = p.x - c.x, dy = p.y - c.y;
    CGFloat dist = hypot(dx, dy);
    BOOL want[4] = {NO, NO, NO, NO};
    if (dist > 18) {
        // 8 directions: a 45° slice each, so diagonals press two arrows
        double angle = atan2(-dy, dx) * 180 / M_PI; // 0 = right, 90 = up
        if (angle < 0) angle += 360;
        want[2] = angle < 67.5 || angle > 292.5;   // right
        want[1] = angle > 22.5 && angle < 157.5;   // up
        want[0] = angle > 112.5 && angle < 247.5;  // left
        want[3] = angle > 202.5 && angle < 337.5;  // down
    }
    for (int i = 0; i < 4; i++) [self setDir:i down:want[i]];
    CGFloat r = MIN(dist, 50);
    self.dpadKnob.center = dist > 0 ? CGPointMake(c.x + dx / dist * r, c.y + dy / dist * r) : c;
}

// ---- Touches ----

- (TouchRole)roleForPoint:(CGPoint)p {
    CGPoint inPad = [self.view convertPoint:p toView:self.dpad];
    if (hypot(inPad.x - 75, inPad.y - 75) < 110) return RoleDpad; // generous, so thumbs don't slip off
    if (hypot(p.x - self.jump.center.x, p.y - self.jump.center.y) < 70) return RoleJump;
    if (hypot(p.x - self.start.center.x, p.y - self.start.center.y) < 45) return RoleStart;
    if (CGRectContainsPoint(CGRectInset(self.closeButton.frame, -10, -10), p)) return RoleClose;
    if (CGRectContainsPoint([self gameRect], p)) return RoleGame;
    return RoleNone;
}

- (void)sendMouse:(CGPoint)p {
    CGRect r = [self gameRect];
    uint32_t packed = ramen_ios_game_size();
    CGFloat gw = packed >> 16, gh = packed & 0xFFFF;
    CGFloat x = (p.x - r.origin.x) / r.size.width * gw, y = (p.y - r.origin.y) / r.size.height * gh;
    ramen_ios_mouse_move((uint32_t)MAX(0, MIN(gw - 1, x)), (uint32_t)MAX(0, MIN(gh - 1, y)));
}

- (void)highlight:(UIView *)v on:(BOOL)on {
    v.backgroundColor = [UIColor colorWithWhite:1 alpha:on ? 0.4 : 0.15];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        CGPoint p = [t locationInView:self.view];
        TouchRole role = [self roleForPoint:p];
        switch (role) {
            case RoleDpad:
                if (_dpadTouch) { role = RoleNone; break; }
                _dpadTouch = t;
                [self updateDpadWithPoint:[t locationInView:self.dpad]];
                break;
            case RoleJump: ramen_ios_key(VK_SPACE, true); [self highlight:self.jump on:YES]; break;
            case RoleStart: ramen_ios_key(VK_RETURN, true); [self highlight:self.start on:YES]; break;
            case RoleGame:
                if (_mouseTouch) { role = RoleNone; break; }
                _mouseTouch = t;
                [self sendMouse:p];
                ramen_ios_mouse_button(0, true);
                break;
            case RoleClose: [self askToClose]; role = RoleNone; break;
            default: break;
        }
        [_roles setObject:@(role) forKey:t];
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        TouchRole role = [[_roles objectForKey:t] integerValue];
        if (role == RoleDpad) [self updateDpadWithPoint:[t locationInView:self.dpad]];
        else if (role == RoleGame) [self sendMouse:[t locationInView:self.view]];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UITouch *t in touches) {
        TouchRole role = [[_roles objectForKey:t] integerValue];
        switch (role) {
            case RoleDpad:
                _dpadTouch = nil;
                for (int i = 0; i < 4; i++) [self setDir:i down:NO];
                self.dpadKnob.center = CGPointMake(75, 75);
                break;
            case RoleJump: ramen_ios_key(VK_SPACE, false); [self highlight:self.jump on:NO]; break;
            case RoleStart: ramen_ios_key(VK_RETURN, false); [self highlight:self.start on:NO]; break;
            case RoleGame: _mouseTouch = nil; ramen_ios_mouse_button(0, false); break;
            default: break;
        }
        [_roles removeObjectForKey:t];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesEnded:touches withEvent:event];
}

// ---- Game controllers ----

- (void)controllerConnected:(NSNotification *)n { [self setUpController:n.object]; }

- (void)setUpController:(GCController *)c {
    GCExtendedGamepad *pad = c.extendedGamepad;
    if (!pad) return;
    SunkyLog(@"controller connected: %@", c.vendorName);
    __weak GameViewController *weakSelf = self;
    GCControllerDirectionPadValueChangedHandler dir = ^(GCControllerDirectionPad *d, float x, float y) {
        [weakSelf setPadDir:0 down:x < -0.5];
        [weakSelf setPadDir:2 down:x > 0.5];
        [weakSelf setPadDir:1 down:y > 0.5];
        [weakSelf setPadDir:3 down:y < -0.5];
    };
    pad.dpad.valueChangedHandler = dir;
    pad.leftThumbstick.valueChangedHandler = dir;
    pad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL pressed) { ramen_ios_key(VK_SPACE, pressed); };
    pad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL pressed) { ramen_ios_key(VK_SPACE, pressed); };
    pad.buttonMenu.pressedChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL pressed) { ramen_ios_key(VK_RETURN, pressed); };
}

// ---- Hardware keyboards ----

- (BOOL)canBecomeFirstResponder { return YES; }

- (uint32_t)vkForPress:(UIPress *)p API_AVAILABLE(ios(13.4)) {
    switch (p.key.keyCode) {
        case UIKeyboardHIDUsageKeyboardLeftArrow: return VK_LEFT;
        case UIKeyboardHIDUsageKeyboardRightArrow: return VK_RIGHT;
        case UIKeyboardHIDUsageKeyboardUpArrow: return VK_UP;
        case UIKeyboardHIDUsageKeyboardDownArrow: return VK_DOWN;
        case UIKeyboardHIDUsageKeyboardSpacebar: return VK_SPACE;
        case UIKeyboardHIDUsageKeyboardReturnOrEnter: return VK_RETURN;
        case UIKeyboardHIDUsageKeyboardEscape: return VK_ESCAPE;
        default: {
            NSString *ch = p.key.charactersIgnoringModifiers.uppercaseString;
            if (ch.length == 1) {
                unichar u = [ch characterAtIndex:0];
                if ((u >= 'A' && u <= 'Z') || (u >= '0' && u <= '9')) return u;
            }
            return 0;
        }
    }
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    if (@available(iOS 13.4, *)) {
        for (UIPress *p in presses) { uint32_t vk = [self vkForPress:p]; if (vk) { ramen_ios_key(vk, true); handled = YES; } }
    }
    if (!handled) [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    if (@available(iOS 13.4, *)) {
        for (UIPress *p in presses) { uint32_t vk = [self vkForPress:p]; if (vk) { ramen_ios_key(vk, false); handled = YES; } }
    }
    if (!handled) [super pressesEnded:presses withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self pressesEnded:presses withEvent:event];
}

@end
