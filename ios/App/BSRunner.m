// Runs a GameMaker Studio game (Sunky the Game 2) on Butterscotch (engine/butterscotch/src/ios).
// Same shape as the OpenGMK games: the app calls sunky_bs_run on a game thread and it returns when
// the game ends. Input arrives from the main thread and is applied on the game thread each frame.
#define GLES_SILENCE_DEPRECATION 1
#import <Foundation/Foundation.h>
#import <OpenGLES/ES3/gl.h>
#import <QuartzCore/QuartzCore.h>
#import "Sunky.h"
#include <os/lock.h>
#include <stdatomic.h>

// Butterscotch iPhone frontend (engine/butterscotch/src/ios/main.c)
bool bs_ios_start(const char *dataWinPath, const char *savesPath, uint32_t screenFbo);
void bs_ios_stop(void);
int32_t bs_ios_target_fps(void);
int32_t bs_ios_current_room(void);
void bs_ios_set_widescreen(float aspect);
void bs_ios_begin_frame(void);
void bs_ios_key(int32_t keyCode, bool down);
void bs_ios_pointer(float x, float y);
void bs_ios_mouse_button(int32_t button, bool down);
int32_t bs_ios_step(int32_t winW, int32_t winH, float deltaTime);

// From GameView.m
uint32_t sunky_gl_setup(void);
void sunky_gl_present(void);
void sunky_gl_teardown(void);
void sunky_gl_screen_size(int32_t *w, int32_t *h);

typedef struct { int kind; int a; int b; float x, y; } BSEvent; // kind: 0 key, 1 pointer, 2 button
#define BS_QUEUE 256
static BSEvent gQueue[BS_QUEUE];
static int gQueueLen;
static os_unfair_lock gLock = OS_UNFAIR_LOCK_INIT;
static atomic_bool gQuit;
static atomic_int gRoom = -1;
static _Atomic float gWide;

static void push(BSEvent e) {
    os_unfair_lock_lock(&gLock);
    if (gQueueLen < BS_QUEUE) gQueue[gQueueLen++] = e;
    os_unfair_lock_unlock(&gLock);
}

void sunky_bs_key(uint32_t vk, bool down) { push((BSEvent){0, (int)vk, down, 0, 0}); }
void sunky_bs_pointer(float nx, float ny) { push((BSEvent){1, 0, 0, nx, ny}); }
void sunky_bs_button(bool down) { push((BSEvent){2, 0, down, 0, 0}); }
void sunky_bs_quit(void) { atomic_store(&gQuit, true); }
int32_t sunky_bs_current_room(void) { return atomic_load(&gRoom); }
void sunky_bs_set_widescreen(float aspect) { atomic_store(&gWide, aspect); }

int32_t sunky_bs_run(const char *dataWinPath, const char *savesPath) {
    atomic_store(&gQuit, false);
    atomic_store(&gRoom, -1);
    os_unfair_lock_lock(&gLock); gQueueLen = 0; os_unfair_lock_unlock(&gLock);
    uint32_t fbo = sunky_gl_setup();
    if (!fbo) return 1;
    if (!bs_ios_start(dataWinPath, savesPath, fbo)) { sunky_gl_teardown(); return 1; }
    int32_t w = 0, h = 0;
    sunky_gl_screen_size(&w, &h);
    SunkyLog(@"butterscotch: started, screen %dx%d", w, h);
    CFTimeInterval last = CACurrentMediaTime();
    while (!atomic_load(&gQuit)) {
        @autoreleasepool {
            bs_ios_begin_frame();
            BSEvent events[BS_QUEUE];
            os_unfair_lock_lock(&gLock);
            int n = gQueueLen;
            memcpy(events, gQueue, sizeof(BSEvent) * n);
            gQueueLen = 0;
            os_unfair_lock_unlock(&gLock);
            for (int i = 0; i < n; i++) {
                if (events[i].kind == 0) bs_ios_key(events[i].a, events[i].b);
                else if (events[i].kind == 1) bs_ios_pointer(events[i].x, events[i].y);
                else bs_ios_mouse_button(1, events[i].b); // GameMaker numbers mouse buttons from 1 (mb_left)
            }
            bs_ios_set_widescreen(atomic_load(&gWide));
            CFTimeInterval now = CACurrentMediaTime();
            int32_t r = bs_ios_step(w, h, (float)(now - last));
            last = now;
            atomic_store(&gRoom, bs_ios_current_room());
            if (r == 1) break;
            if (r == 0) sunky_gl_present();
            // pace to the room speed (GameMaker games run at a fixed frame rate)
            int fps = bs_ios_target_fps();
            if (fps <= 0 || fps > 240) fps = 60;
            CFTimeInterval spent = CACurrentMediaTime() - now;
            double wait = 1.0 / fps - spent;
            if (wait > 0) [NSThread sleepForTimeInterval:wait];
        }
    }
    bs_ios_stop();
    sunky_gl_teardown();
    SunkyLog(@"butterscotch: stopped");
    return 0;
}
