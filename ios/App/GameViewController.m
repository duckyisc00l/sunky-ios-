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
@property (nonatomic, strong) UIView *dpad, *jump, *start, *closeButton, *run;
@property (nonatomic) BOOL running;
@property (nonatomic) const SunkyGame *game;
@property (nonatomic, strong) UIImageView *stickKnob;
@property (nonatomic, strong) NSTimer *endWatch;
@property (nonatomic) int32_t firstRoom; // the warning screen with the PLAY button (-1 until known)
@property (nonatomic) BOOL padMode;      // a controller is in use: on-screen controls hidden
@end

typedef NS_ENUM(NSInteger, TouchRole) { RoleNone, RoleDpad, RoleJump, RoleStart, RoleGame, RoleClose, RoleRun };

@implementation GameViewController {
    NSMapTable<UITouch *, NSNumber *> *_roles;
    UITouch *_mouseTouch;
    BOOL _dirDown[4]; // left, up, right, down (from the D-pad)
    BOOL _padDir[4];  // from a game controller
    UITouch *_dpadTouch;
    CFTimeInterval _mouseDownAt;
    NSUInteger _mouseGeneration;
}

- (instancetype)initWithGame:(const SunkyGame *)game exe:(NSString *)exePath title:(NSString *)title {
    if ((self = [super init])) {
        _game = game;
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

    // Retro pixel-art controls (drawn by ci/controls.py), scaled up with hard pixels
    self.dpad = [self pixelImage:@"stick_base" scale:3.6];
    self.stickKnob = [self pixelImage:@"stick_knob" scale:3.6];
    self.stickKnob.alpha = 1;
    [self.dpad addSubview:self.stickKnob];
    self.jump = [self pixelImage:@"jump" scale:3.2];
    self.start = [self pixelImage:@"start" scale:3];
    self.closeButton = [self pixelImage:@"close" scale:3];
    self.run = [self pixelImage:@"run" scale:3];
    self.run.hidden = !(self.game && self.game->runKey);
    // single-game apps have no menu to go back to, so no quit button
    self.closeButton.hidden = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"] length] > 0;
    for (UIView *v in @[self.dpad, self.jump, self.start, self.closeButton, self.run]) [self.view addSubview:v];

    self.firstRoom = -1;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(controllerConnected:)
                                               name:GCControllerDidConnectNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(controllerDisconnected:)
                                               name:GCControllerDidDisconnectNotification object:nil];
    for (GCController *c in GCController.controllers) [self setUpController:c];
}

- (UIImage *)controlImage:(NSString *)name {
    NSString *path = [NSBundle.mainBundle pathForResource:name ofType:@"png" inDirectory:@"Controls"];
    return path ? [UIImage imageWithContentsOfFile:path] : nil;
}

- (UIImageView *)pixelImage:(NSString *)name scale:(CGFloat)scale {
    UIImage *img = [self controlImage:name];
    UIImageView *v = [[UIImageView alloc] initWithImage:img];
    v.frame = CGRectMake(0, 0, img.size.width * scale, img.size.height * scale);
    v.layer.magnificationFilter = kCAFilterNearest;
    v.alpha = 0.9;
    v.userInteractionEnabled = NO;
    return v;
}

- (void)showPressed:(UIView *)v name:(NSString *)name on:(BOOL)on {
    ((UIImageView *)v).image = [self controlImage:on ? [name stringByAppendingString:@"_on"] : name];
}

/// Where the game picture is, in view points (same aspect fit as the runner).
- (CGRect)gameRect {
    uint32_t packed = ramen_ios_game_size();
    CGFloat gw = MAX(1, packed >> 16), gh = MAX(1, packed & 0xFFFF);
    CGSize b = self.view.bounds.size;
    CGFloat scale = MIN(b.width / gw, b.height / gh);
    // nearly the screen's shape already (Silly.TIFF's 16:9 screens): the engine zooms to fill the
    // width and trims top and bottom (same rule as render/opengl.rs), so taps must match
    if (b.width / b.height > gw / gh && (b.width / b.height) / (gw / gh) <= 1.23) scale = b.width / gw;
    CGFloat w = gw * scale, h = gh * scale;
    return CGRectMake((b.width - w) / 2, (b.height - h) / 2, w, h);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGSize b = self.view.bounds.size;
    // The notch is in the middle of the side edges, so the bottom corners are free to use:
    // controls sit in the corners, inside the black bars beside the game where there's room.
    CGFloat bottom = MAX(safe.bottom, 10);
    CGFloat dr = self.dpad.bounds.size.width / 2, jr = self.jump.bounds.size.width / 2;
    // In from the edges, where thumbs rest (not tucked into the corners)
    CGFloat inset = MIN(70, b.width * 0.08);
    self.dpad.center = CGPointMake(inset + dr, b.height - bottom - dr - 28);
    self.jump.center = CGPointMake(b.width - inset - jr, b.height - bottom - jr - 34);
    self.start.center = CGPointMake(self.jump.center.x, self.jump.center.y - jr - 34);
    self.closeButton.center = CGPointMake(MAX(safe.left, 8) + 20, MAX(safe.top, 8) + 20);
    if (!self.run.hidden) { // RUN sits left of JUMP; START moves above the pair
        self.run.center = CGPointMake(self.jump.center.x - jr - self.run.bounds.size.width / 2 - 6, self.jump.center.y + 14);
        self.start.center = CGPointMake(self.jump.center.x - 30, self.jump.center.y - jr - 34);
    }
    // In widescreen the game fills the screen, so the controls get a little more see-through
    CGFloat alpha = self.padMode ? 0 : SunkyWidescreen() ? 0.7 : 0.9;
    for (UIView *v in @[self.dpad, self.jump, self.start, self.run]) v.alpha = alpha;
    if (!_dpadTouch) self.stickKnob.center = CGPointMake(self.dpad.bounds.size.width / 2, self.dpad.bounds.size.height / 2);

}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.running) return;
    self.running = YES;
    UIApplication.sharedApplication.idleTimerDisabled = YES;
    [self.gameView makeCurrent];
    CGFloat s = self.gameView.contentScaleFactor;
    ramen_ios_resize((uint32_t)(self.gameView.bounds.size.width * s), (uint32_t)(self.gameView.bounds.size.height * s));
    ramen_ios_set_widescreen(SunkyWidescreen());
    __weak GameViewController *weakTimerSelf = self;
    self.endWatch = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) { [weakTimerSelf checkEnding]; }];
    NSString *path = self.exePath;
    BOOL isBS = [self isBS];
    NSString *saves = [SunkyDocuments() stringByAppendingPathComponent:@(self.game ? self.game->file : "game")];
    if (isBS) sunky_bs_set_widescreen(SunkyWidescreen() ? (float)(self.view.bounds.size.width / self.view.bounds.size.height) : 0);
    // Phone-friendly replacement art ("PRESS START" instead of "PRESS ENTER"), see engine overrides.rs
    NSString *art = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Art"];
    setenv("SUNKY_OVERRIDES", art.fileSystemRepresentation, 1);
    __weak GameViewController *weakSelf = self;
    NSThread *t = [[NSThread alloc] initWithBlock:^{
        SunkyLog(@"starting %@", path);
        int32_t code = isBS ? sunky_bs_run(path.fileSystemRepresentation, saves.fileSystemRepresentation)
                            : sunky_run_game(path.fileSystemRepresentation);
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
        if (p.count == 4) { // "sec:gtap:x:y" taps game pixel (x, y); "sec:tap:fx:fy" taps a fraction of the screen
            double at = [p[0] doubleValue];
            NSString *kind = p[1];
            CGFloat a = [p[2] doubleValue], b2 = [p[3] doubleValue];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CGPoint pt;
                if ([kind isEqualToString:@"gtap"]) {
                    CGRect r = [self gameRect];
                    uint32_t packed = ramen_ios_game_size();
                    pt = CGPointMake(r.origin.x + a / MAX(1, packed >> 16) * r.size.width, r.origin.y + b2 / MAX(1, packed & 0xFFFF) * r.size.height);
                } else {
                    pt = CGPointMake(a * self.view.bounds.size.width, b2 * self.view.bounds.size.height);
                }
                SunkyLog(@"test tap at %.0f,%.0f", pt.x, pt.y);
                [self sendMouse:pt];
                [self mouseButton:YES];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self mouseButton:NO]; });
            });
            continue;
        }
        if (p.count != 3) continue;
        double at = [p[0] doubleValue], hold = [p[2] doubleValue];
        uint32_t vk = (uint32_t)[p[1] intValue];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SunkyLog(@"test key %u down", vk);
            [self key:vk down:YES];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((at + hold) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self key:vk down:NO];
        });
    }
}

- (void)checkEnding {
    if (!self.game) return;
    int32_t room = [self isBS] ? sunky_bs_current_room() : sunky_current_room();
    if (self.firstRoom < 0 && room >= 0) self.firstRoom = room;
    if (SunkyIsFinished(self.game)) return;
    for (int i = 0; i < 4 && self.game->endRooms[i] >= 0; i++) {
        if (room == self.game->endRooms[i]) {
            SunkySetFinished(self.game);
            SunkyLog(@"reached the ending (room %d)", room);
            [self showFinishedBanner];
            return;
        }
    }
}

- (void)showFinishedBanner {
    UILabel *b = [UILabel new];
    b.text = [NSString stringWithFormat:@"  ✓ FINISHED: %@  ", self.title_];
    b.font = [UIFont systemFontOfSize:20 weight:UIFontWeightHeavy];
    b.textColor = UIColor.whiteColor;
    b.backgroundColor = [UIColor colorWithRed:0.1 green:0.65 blue:0.25 alpha:0.95];
    b.layer.cornerRadius = 14;
    b.clipsToBounds = YES;
    [b sizeToFit];
    b.frame = CGRectInset(b.frame, 0, -8);
    b.center = CGPointMake(self.view.bounds.size.width / 2, -40);
    b.userInteractionEnabled = NO;
    [self.view addSubview:b];
    CGFloat y = MAX(self.view.safeAreaInsets.top, 10) + b.bounds.size.height / 2;
    [UIView animateWithDuration:0.4 animations:^{ b.center = CGPointMake(b.center.x, y); } completion:^(BOOL f) {
        [UIView animateWithDuration:0.4 delay:4 options:0 animations:^{ b.alpha = 0; } completion:^(BOOL f2) { [b removeFromSuperview]; }];
    }];
}

- (void)gameEnded:(int32_t)code {
    [self.endWatch invalidate];
    UIApplication.sharedApplication.idleTimerDisabled = NO;
    if (code == 0) {
        [self.navigationController popViewControllerAnimated:self.closeButton.hidden ? NO : YES];
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
    if (self.presentedViewController) return; // already asking (or a game pop-up is up)
    UIAlertController *a = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Quit %@?", self.title_]
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Keep playing" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Quit" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        if ([self isBS]) sunky_bs_quit(); else ramen_ios_request_close();
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

// ---- Input goes to whichever engine runs this game ----

- (BOOL)isBS { return self.game && self.game->engine == 1; }

- (void)key:(uint32_t)vk down:(BOOL)down {
    if ([self isBS]) sunky_bs_key(vk, down); else ramen_ios_key(vk, down);
}

- (uint32_t)jumpKey { return (self.game && self.game->jumpKey) ? (uint32_t)self.game->jumpKey : VK_SPACE; }

- (void)mouseButton:(BOOL)down {
    if ([self isBS]) sunky_bs_button(down); else ramen_ios_mouse_button(0, down);
}

// ---- Keys ----

static const uint32_t kDirVK[4] = { VK_LEFT, VK_UP, VK_RIGHT, VK_DOWN };

- (void)setDir:(int)i down:(BOOL)down {
    BOOL was = _dirDown[i] || _padDir[i];
    _dirDown[i] = down;
    BOOL now = _dirDown[i] || _padDir[i];
    if (was != now) [self key:kDirVK[i] down:now];
}

- (void)setPadDir:(int)i down:(BOOL)down {
    BOOL was = _dirDown[i] || _padDir[i];
    _padDir[i] = down;
    BOOL now = _dirDown[i] || _padDir[i];
    if (was != now) [self key:kDirVK[i] down:now];
}

- (void)updateDpadWithPoint:(CGPoint)p {
    CGFloat half = self.dpad.bounds.size.width / 2;
    CGFloat dx = p.x - half, dy = p.y - half;
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
    [self showDpad:want];
    // the knob follows the thumb, up to the edge of the well
    CGFloat travel = half * 0.55;
    CGFloat r = MIN(dist, travel);
    self.stickKnob.center = dist > 0 ? CGPointMake(half + dx / dist * r, half + dy / dist * r) : CGPointMake(half, half);
}

- (void)showDpad:(BOOL *)dirs {
    // joystick: the knob is moved in updateDpadWithPoint; just light it up while pushed
    BOOL any = dirs[0] || dirs[1] || dirs[2] || dirs[3];
    self.stickKnob.image = [self controlImage:any ? @"stick_knob_on" : @"stick_knob"];
}

// ---- Touches ----

- (TouchRole)roleForPoint:(CGPoint)p {
    CGPoint inPad = [self.view convertPoint:p toView:self.dpad];
    CGFloat half = self.dpad.bounds.size.width / 2;
    if (hypot(inPad.x - half, inPad.y - half) < half + 30) return RoleDpad; // generous, so thumbs don't slip off
    if (hypot(p.x - self.jump.center.x, p.y - self.jump.center.y) < self.jump.bounds.size.width / 2 + 16) return RoleJump;
    if (CGRectContainsPoint(CGRectInset(self.start.frame, -12, -12), p)) return RoleStart;
    if (!self.run.hidden && hypot(p.x - self.run.center.x, p.y - self.run.center.y) < self.run.bounds.size.width / 2 + 12) return RoleRun;
    if (!self.closeButton.hidden && CGRectContainsPoint(CGRectInset(self.closeButton.frame, -10, -10), p)) return RoleClose;
    if ([self isBS] || CGRectContainsPoint([self gameRect], p)) return RoleGame;
    return RoleNone;
}

- (void)sendMouse:(CGPoint)p {
    if ([self isBS]) { // Butterscotch maps screen fractions to the game itself
        CGSize b = self.view.bounds.size;
        sunky_bs_pointer(p.x / MAX(1, b.width), p.y / MAX(1, b.height));
        return;
    }
    CGRect r = [self gameRect];
    uint32_t packed = ramen_ios_game_size();
    CGFloat gw = packed >> 16, gh = packed & 0xFFFF;
    CGFloat x = (p.x - r.origin.x) / r.size.width * gw, y = (p.y - r.origin.y) / r.size.height * gh;
    ramen_ios_mouse_move((uint32_t)MAX(0, MIN(gw - 1, x)), (uint32_t)MAX(0, MIN(gh - 1, y)));
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.padMode) [self setPadMode:NO]; // back to touch: show the controls again
    for (UITouch *t in touches) {
        CGPoint p = [t locationInView:self.view];
        TouchRole role = [self roleForPoint:p];
        switch (role) {
            case RoleDpad:
                if (_dpadTouch) { role = RoleNone; break; }
                _dpadTouch = t;
                [self updateDpadWithPoint:[t locationInView:self.dpad]];
                break;
            case RoleJump: [self key:[self jumpKey] down:YES]; [self showPressed:self.jump name:@"jump" on:YES]; break;
            case RoleRun: [self key:(uint32_t)self.game->runKey down:YES]; [self showPressed:self.run name:@"run" on:YES]; break;
            case RoleStart: [self key:VK_RETURN down:YES]; [self showPressed:self.start name:@"start" on:YES]; break;
            case RoleGame:
                if (_mouseTouch) { role = RoleNone; break; }
                _mouseTouch = t;
                [self sendMouse:p];
                [self mouseButton:YES];
                _mouseDownAt = CACurrentMediaTime();
                _mouseGeneration++;
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
            case RoleDpad: {
                _dpadTouch = nil;
                for (int i = 0; i < 4; i++) [self setDir:i down:NO];
                self.stickKnob.image = [self controlImage:@"stick_knob"];
                [UIView animateWithDuration:0.08 animations:^{
                    self.stickKnob.center = CGPointMake(self.dpad.bounds.size.width / 2, self.dpad.bounds.size.height / 2);
                }];
                break;
            }
            case RoleJump: [self key:[self jumpKey] down:NO]; [self showPressed:self.jump name:@"jump" on:NO]; break;
            case RoleRun: [self key:(uint32_t)self.game->runKey down:NO]; [self showPressed:self.run name:@"run" on:NO]; break;
            case RoleStart: [self key:VK_RETURN down:NO]; [self showPressed:self.start name:@"start" on:NO]; break;
            case RoleGame: {
                // Some buttons only react while the mouse is held, so keep every tap down for a few frames.
                _mouseTouch = nil;
                CFTimeInterval wait = 0.1 - (CACurrentMediaTime() - _mouseDownAt);
                NSUInteger gen = _mouseGeneration;
                if (wait <= 0) { [self mouseButton:NO]; break; }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (gen == self->_mouseGeneration && !self->_mouseTouch) [self mouseButton:NO];
                });
                break;
            }
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

- (void)controllerDisconnected:(NSNotification *)n {
    BOOL any = NO;
    for (GCController *c in GCController.controllers) if (c != n.object && c.extendedGamepad) any = YES;
    if (!any) [self setPadMode:NO];
}

// With a controller in use the on-screen joystick and buttons get out of the way; touching the
// screen brings them back.
- (void)setPadMode:(BOOL)on {
    _padMode = on;
    BOOL single = [[NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"] length] > 0;
    [UIView animateWithDuration:0.2 animations:^{
        for (UIView *v in @[self.dpad, self.jump, self.start, self.run]) v.alpha = on ? 0 : SunkyWidescreen() ? 0.7 : 0.9;
        self.closeButton.alpha = on || single ? 0 : 0.9;
    }];
}

/// The spot of each game's PLAY button on its warning screen, in game pixels (GameMaker 8 games),
/// or as screen fractions for Sunky the Game 2. A controller can't click, so A/Menu presses it.
- (BOOL)tapPlayButton {
    if (!self.game || self.firstRoom < 0) return NO;
    int32_t room = [self isBS] ? sunky_bs_current_room() : sunky_current_room();
    if (room != self.firstRoom) return NO;
    const char *f = self.game->file;
    CGPoint gp = CGPointZero;
    if (!strcmp(f, "p1")) gp = CGPointMake(320, 432);
    else if (!strcmp(f, "p2") || !strcmp(f, "p3")) gp = CGPointMake(528, 393);
    else if (!strcmp(f, "tiff")) gp = CGPointMake(448, 352);
    CGPoint pt;
    if ([self isBS]) {
        pt = CGPointMake(0.5 * self.view.bounds.size.width, 0.72 * self.view.bounds.size.height);
    } else if (gp.x > 0) {
        CGRect r = [self gameRect];
        uint32_t packed = ramen_ios_game_size();
        pt = CGPointMake(r.origin.x + gp.x / MAX(1, packed >> 16) * r.size.width, r.origin.y + gp.y / MAX(1, packed & 0xFFFF) * r.size.height);
    } else {
        return NO; // this game starts with a key press instead
    }
    SunkyLog(@"controller: pressing PLAY at %.0f,%.0f", pt.x, pt.y);
    [self sendMouse:pt];
    [self mouseButton:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self mouseButton:NO]; });
    return YES;
}

- (void)setUpController:(GCController *)c {
    GCExtendedGamepad *pad = c.extendedGamepad;
    if (!pad) return;
    SunkyLog(@"controller connected: %@", c.vendorName);
    // the on-screen controls hide once the controller is actually used, not just because one is paired
    __weak GameViewController *weakSelf = self;
    GCControllerDirectionPadValueChangedHandler dir = ^(GCControllerDirectionPad *d, float x, float y) {
        if ((fabsf(x) > 0.5f || fabsf(y) > 0.5f) && !weakSelf.padMode) [weakSelf setPadMode:YES];
        [weakSelf setPadDir:0 down:x < -0.5];
        [weakSelf setPadDir:2 down:x > 0.5];
        [weakSelf setPadDir:1 down:y > 0.5];
        [weakSelf setPadDir:3 down:y < -0.5];
    };
    pad.dpad.valueChangedHandler = dir;
    pad.leftThumbstick.valueChangedHandler = dir;
    // A and X jump; B and Y run (or jump, in games without a run button)
    GCControllerButtonValueChangedHandler jump = ^(GCControllerButtonInput *b, float v, BOOL pressed) {
        GameViewController *me = weakSelf;
        if (pressed && !me.padMode) [me setPadMode:YES];
        if (pressed && [me tapPlayButton]) return;
        [me key:[me jumpKey] down:pressed];
    };
    GCControllerButtonValueChangedHandler run = ^(GCControllerButtonInput *b, float v, BOOL pressed) {
        GameViewController *me = weakSelf;
        if (pressed && !me.padMode) [me setPadMode:YES];
        uint32_t k = (me.game && me.game->runKey) ? (uint32_t)me.game->runKey : [me jumpKey];
        [me key:k down:pressed];
    };
    pad.buttonA.valueChangedHandler = jump;
    pad.buttonX.valueChangedHandler = jump;
    pad.buttonB.valueChangedHandler = run;
    pad.buttonY.valueChangedHandler = run;
    pad.leftShoulder.valueChangedHandler = run;
    pad.rightShoulder.valueChangedHandler = run;
    // Menu / Start: the game's START (Enter), or PLAY on the warning screen
    pad.buttonMenu.valueChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL pressed) {
        GameViewController *me = weakSelf;
        if (pressed && !me.padMode) [me setPadMode:YES];
        if (pressed && [me tapPlayButton]) return;
        [me key:VK_RETURN down:pressed];
    };
    // Options / Select / View: back to the game list (all-in-one app only)
    if (pad.buttonOptions) pad.buttonOptions.valueChangedHandler = ^(GCControllerButtonInput *b, float v, BOOL pressed) {
        GameViewController *me = weakSelf;
        if (pressed && [[NSBundle.mainBundle objectForInfoDictionaryKey:@"SunkyOnly"] length] == 0) [me askToClose];
    };
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
        for (UIPress *p in presses) { uint32_t vk = [self vkForPress:p]; if (vk) { [self key:vk down:YES]; handled = YES; } }
    }
    if (!handled) [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    BOOL handled = NO;
    if (@available(iOS 13.4, *)) {
        for (UIPress *p in presses) { uint32_t vk = [self vkForPress:p]; if (vk) { [self key:vk down:NO]; handled = YES; } }
    }
    if (!handled) [super pressesEnded:presses withEvent:event];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self pressesEnded:presses withEvent:event];
}

@end
