// SUNKY-IOS: iPhone frontend for Butterscotch, ported from src/android/main.c.
//
// The iPhone app owns the screen and the frame loop. On its game thread, with an OpenGL ES 3
// context current and a framebuffer for the screen bound, it calls:
//   bs_ios_start(game, saves, screenFbo)  once
//   bs_ios_begin_frame(); bs_ios_step(w, h, dt)  every frame, then presents unless told not to
//   bs_ios_stop()  when the player quits
// Keys (GameMaker key codes, same as Windows VK codes), the pointer and widescreen come in through
// the other bs_ios_* functions. They are called on the game thread too (the app queues them).
#include "stdio_compat.h"
#include <stdint.h>
#include "string_compat.h"
#include <errno.h>
#include <sys/stat.h>
#define GLES_SILENCE_DEPRECATION 1
#include <OpenGLES/ES3/gl.h>

#include "common.h"
#include "data_win.h"
#include "runner.h"
#include "overlay_file_system.h"
#include "ma_audio_system.h"
#include "noop_audio_system.h"
#include "gl/gl_renderer.h"
#include "stb_ds.h"
#include "log.h"

static Runner* gRunner = nullptr;
static char* gCurrentDataWinPath = nullptr;
static char* gSavesPath = nullptr;
static GLuint gHostFramebuffer = 0;
static float gWidescreenAspect = 0.0f;
static float gCursorX = 0.0f;
static float gCursorY = 0.0f;
static int32_t gWindowW = 0;
static int32_t gWindowH = 0;
static int32_t gViewport[4];

void platformLog(const logType type, const char* format, va_list va) {
    const char* tag = type == LOG_TYPE_ERROR ? "error: " : type == LOG_TYPE_WARNING ? "warning: " : "";
    fputs("[bs] ", stderr);
    fputs(tag, stderr);
    vfprintf(stderr, format, va);
    size_t n = strlen(format);
    if (n == 0 || format[n - 1] != '\n') fputc('\n', stderr);
}

static bool iosGetWindowSize(int32_t* outW, int32_t* outH) {
    if (gWindowW <= 0 || gWindowH <= 0) return false;
    if (outW != nullptr) *outW = gWindowW;
    if (outH != nullptr) *outH = gWindowH;
    return true;
}

static void setWindowTitle(const char* title) {
    logInfo("Window title: %s", title ? title : "");
}

static char** extractRunnerArguments(char* rawArguments) {
    char* saveptr;
    char* copy = safeStrdup(rawArguments);
    char* token = strtok_r(copy, " \t\r\n", &saveptr);
    char** array = nullptr;
    while (token != nullptr) {
        arrput(array, safeStrdup(token));
        token = strtok_r(nullptr, " \t\r\n", &saveptr);
    }
    free(copy);
    return array;
}

static bool startRunnerFromPath(const char* dataWinPath, const char* savesPath, char** gameArgs) {
    if (gRunner != nullptr) return false;
    if (mkdir(savesPath, 0777) != 0 && errno != EEXIST) {
        logWarn("Could not create saves dir %s: %s", savesPath, strerror(errno));
    }

    DataWin* dataWin = DataWin_parse(
        dataWinPath,
        (DataWinParserOptions) {
            .parseGen8 = true, .parseOptn = true, .parseLang = true, .parseExtn = true,
            .parseSond = true, .parseAgrp = true, .parseSprt = true, .parseBgnd = true,
            .parsePath = true, .parseScpt = true, .parseGlob = true, .parseShdr = true,
            .parseFont = true, .parseTmln = true, .parseObjt = true, .parseRoom = true,
            .parseTgin = true, .parseTpag = true, .parseCode = true, .parseVari = true,
            .parseFunc = true, .parseStrg = true, .parseTxtr = true, .parseAudo = true,
            .skipLoadingPreciseMasksForNonPreciseSprites = true,
            .loadType = DATAWINLOADTYPE_LOAD_IN_MEMORY_AHEAD_OF_TIME,
            .lazyLoadRooms = false,
            .eagerlyLoadedRooms = nullptr
        }
    );
    if (dataWin == nullptr) {
        logError("Failed to parse data.win at %s", dataWinPath);
        return false;
    }

    char* bundleDir = safeStrdup(dataWinPath);
    bsGetDirname(bundleDir);

    VMContext* vm = VM_create(dataWin);
    Renderer* renderer = GLRenderer_create();
    ((GLModernRenderer*) renderer)->hostFramebuffer = gHostFramebuffer;
    ((GLRenderer*) renderer)->textureFormat = GL_RGBA;
    OverlayFileSystem* overlayFs = OverlayFileSystem_create(bundleDir, savesPath);
    free(bundleDir);

    AudioSystem* audioSystem = (AudioSystem*) MaAudioSystem_create(dataWin);
    if (audioSystem == nullptr) {
        logWarn("MaAudioSystem_create returned NULL; falling back to silent audio");
        audioSystem = (AudioSystem*) NoopAudioSystem_create();
    }

    Runner* runner = Runner_create(dataWin, vm, renderer, (FileSystem*) overlayFs, audioSystem, 0);
    runner->osType = OS_WINDOWS;
    runner->setWindowTitle = setWindowTitle;
    runner->windowHasFocus = nullptr;
    runner->getWindowSize = iosGetWindowSize;
    if (gameArgs != nullptr) Runner_setGameArgs(runner, gameArgs, (int32_t) arrlen(gameArgs));

    Runner_initFirstRoom(runner);

    free(gCurrentDataWinPath);
    free(gSavesPath);
    gCurrentDataWinPath = safeStrdup(dataWinPath);
    gSavesPath = safeStrdup(savesPath);
    gRunner = runner;
    logInfo("Runner started OK");
    return true;
}

static void teardownRunner(void) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    gRunner = nullptr;
    runner->audioSystem->vtable->destroy(runner->audioSystem);
    runner->audioSystem = nullptr;
    runner->renderer->vtable->destroy(runner->renderer);
    DataWin* dataWin = runner->dataWin;
    VMContext* vm = runner->vmContext;
    Runner_free(runner);
    VM_free(vm);
    DataWin_free(dataWin);
}

static bool performGameChange(const char* workingDirectory, char* launchParameters) {
    char** newArguments = extractRunnerArguments(launchParameters);
    char* dataWinFilename = nullptr;
    size_t argCount = arrlen(newArguments);
    repeat(argCount, i) {
        if (strcmp(newArguments[i], "-game") == 0 && argCount - 1 > i) {
            dataWinFilename = newArguments[i + 1];
            break;
        }
    }
    bool ok = false;
    if (dataWinFilename != nullptr) {
        char* parentDir = safeStrdup(gCurrentDataWinPath);
        bsGetDirname(parentDir);
        size_t newPathLen = strlen(parentDir) + strlen(workingDirectory) + 1 + strlen(dataWinFilename) + 1;
        char* newPath = safeMalloc(newPathLen);
        snprintf(newPath, newPathLen, "%s%s/%s", parentDir, workingDirectory, dataWinFilename);
        free(parentDir);
        char** gameArgs = nullptr;
        arrput(gameArgs, safeStrdup("butterscotch"));
        repeat(arrlen(newArguments), i) arrput(gameArgs, safeStrdup(newArguments[i]));
        teardownRunner();
        char* saves = safeStrdup(gSavesPath);
        ok = startRunnerFromPath(newPath, saves, gameArgs);
        free(saves);
        free(newPath);
        repeat(arrlen(gameArgs), i) free(gameArgs[i]);
        arrfree(gameArgs);
    }
    repeat(arrlen(newArguments), i) free(newArguments[i]);
    arrfree(newArguments);
    return ok;
}

// ===[ API for the iPhone app ]===

bool bs_ios_start(const char* dataWinPath, const char* savesPath, uint32_t screenFbo) {
    if (gRunner != nullptr) return false;
    gHostFramebuffer = (GLuint) screenFbo;
    char** gameArgs = nullptr;
    arrput(gameArgs, safeStrdup("butterscotch"));
    bool ok = startRunnerFromPath(dataWinPath, savesPath, gameArgs);
    repeat(arrlen(gameArgs), i) free(gameArgs[i]);
    arrfree(gameArgs);
    return ok;
}

void bs_ios_stop(void) {
    teardownRunner();
    free(gCurrentDataWinPath);
    gCurrentDataWinPath = nullptr;
    free(gSavesPath);
    gSavesPath = nullptr;
}

/// Frames per second the current room wants (0 if unknown).
int32_t bs_ios_target_fps(void) {
    Runner* runner = gRunner;
    if (runner == nullptr || runner->currentRoom == nullptr) return 0;
    return (int32_t) runner->currentRoom->speed;
}

/// The room the game is in (-1 if none), for noticing the ending.
int32_t bs_ios_current_room(void) {
    Runner* runner = gRunner;
    if (runner == nullptr || runner->currentRoom == nullptr) return -1;
    return runner->currentRoomIndex;
}

/// Game picture inside the screen, in pixels (x, y, w, h), from the last frame.
void bs_ios_viewport(int32_t* out4) {
    repeat(4, i) out4[i] = gViewport[i];
}

void bs_ios_set_widescreen(float aspect) {
    gWidescreenAspect = aspect;
}

void bs_ios_begin_frame(void) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    RunnerKeyboard_beginFrame(runner->keyboard);
    RunnerMouse_beginFrame(runner->mouse);
}

void bs_ios_key(int32_t keyCode, bool down) {
    Runner* runner = gRunner;
    if (runner == nullptr || keyCode < 0 || keyCode >= GML_KEY_COUNT) return;
    if (down) RunnerKeyboard_onKeyDown(runner->keyboard, keyCode);
    else RunnerKeyboard_onKeyUp(runner->keyboard, keyCode);
}

/// Pointer position as a fraction of the screen (0..1).
void bs_ios_pointer(float x, float y) {
    gCursorX = x;
    gCursorY = y;
}

void bs_ios_mouse_button(int32_t button, bool down) {
    Runner* runner = gRunner;
    if (runner == nullptr) return;
    if (down) RunnerMouse_onButtonDown(runner->mouse, button);
    else RunnerMouse_onButtonUp(runner->mouse, button);
}

void bs_ios_suspend_audio(bool suspend) {
    if (gRunner == nullptr || gRunner->audioSystem == nullptr) return;
    if (suspend) gRunner->audioSystem->vtable->suspend(gRunner->audioSystem);
    else gRunner->audioSystem->vtable->resume(gRunner->audioSystem);
}

#define BS_IOS_CONTINUE 0
#define BS_IOS_SHOULD_EXIT 1
#define BS_IOS_CONTINUE_NO_PRESENT 2

/// Runs one game frame and draws it into the screen framebuffer (winW x winH pixels).
int32_t bs_ios_step(int32_t winW, int32_t winH, float deltaTime) {
    Runner* runner = gRunner;
    if (runner == nullptr) return BS_IOS_SHOULD_EXIT;
    runner->deltaTime = deltaTime * 1000000;
    if (runner->shouldExit) return BS_IOS_SHOULD_EXIT;

    if (runner->pendingWorkingDirectory != nullptr && runner->pendingLaunchParameters != nullptr) {
        char* nextWorkingDirectory = runner->pendingWorkingDirectory;
        char* nextLaunchParameters = runner->pendingLaunchParameters;
        runner->pendingWorkingDirectory = nullptr;
        runner->pendingLaunchParameters = nullptr;
        bool ok = performGameChange(nextWorkingDirectory, nextLaunchParameters);
        free(nextWorkingDirectory);
        free(nextLaunchParameters);
        return ok ? BS_IOS_CONTINUE : BS_IOS_SHOULD_EXIT;
    }

    Runner_step(runner);

    if (0.0f > deltaTime) deltaTime = 0.0f;
    if (deltaTime > 0.1f) deltaTime = 0.1f;
    runner->audioSystem->vtable->update(runner->audioSystem, deltaTime);

    if (winW < 1) winW = 1;
    if (winH < 1) winH = 1;
    gWindowW = winW;
    gWindowH = winH;

    Gen8* gen8 = &runner->dataWin->gen8;
    if (!runner->appSurfaceEnabled) {
        runner->applicationWidth = winW;
        runner->applicationHeight = winH;
        runner->usingAppSurface = false;
    } else {
        if (runner->applicationWidth <= 0 || runner->applicationHeight <= 0) {
            runner->applicationWidth = (int32_t) gen8->defaultWindowWidth;
            runner->applicationHeight = (int32_t) gen8->defaultWindowHeight;
        }
        runner->usingAppSurface = true;
    }

    int32_t gameW = runner->applicationWidth;
    int32_t gameH = runner->applicationHeight;

    runner->widescreenExtraWidth = 0;
    runner->widescreenExtraHeight = 0;
    // SUNKY-IOS: a level too narrow to fill the wider picture (Sunky the Game 2's tall areas) stays
    // at its normal shape, with bars, instead of showing grey past its edges
    bool roomTooNarrow = false;
    if (gWidescreenAspect > 0 && runner->currentRoom != nullptr && runner->viewsEnabled && gameW > 0 && gameH > 0) {
        GMLCamera* cam = Runner_getCameraForView(runner, 0);
        if (cam != nullptr && cam->viewWidth > 0) {
            float wideW = (float) cam->viewWidth * gWidescreenAspect / ((float) gameW / (float) gameH);
            if ((float) runner->currentRoom->width < wideW) roomTooNarrow = true;
        }
    }
    (void) roomTooNarrow; // SUNKY-IOS: narrow levels are widened too now; their sky continues past the edges
    if (gWidescreenAspect > 0 && runner->usingAppSurface && gameW > 0 && gameH > 0) {
        float nativeAspect = (float) gameW / (float) gameH;
        if (gWidescreenAspect > nativeAspect) {
            int32_t targetW = (int32_t) ((float) gameH * gWidescreenAspect + 0.5f);
            if (targetW > gameW) {
                runner->widescreenExtraWidth = targetW - gameW;
                gameW = targetW;
            }
        }
    }

    {
        // SUNKY-IOS test log: what widescreen decided, once per room
        static int32_t lastRoom = -999;
        int32_t rid = runner->currentRoomIndex;
        if (rid != lastRoom && runner->currentRoom != nullptr) {
            lastRoom = rid;
            GMLCamera* cam = Runner_getCameraForView(runner, 0);
            fprintf(stderr, "wide: room %d %ux%u views %d appsurf %d/%d game %dx%d extra %d aspect %.3f cam %dx%d port %dx%d win %dx%d\n",
                rid, runner->currentRoom->width, runner->currentRoom->height, runner->viewsEnabled,
                runner->appSurfaceEnabled, runner->usingAppSurface, gameW, gameH, runner->widescreenExtraWidth, gWidescreenAspect,
                cam ? cam->viewWidth : -1, cam ? cam->viewHeight : -1, runner->views[0].portWidth, runner->views[0].portHeight, winW, winH);
        }
    }
    glBindFramebuffer(GL_FRAMEBUFFER, gHostFramebuffer);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    Runner_drawPre(runner, winW, winH);
    Runner_beginFrame(runner, gameW, gameH, winW, winH, winW, winH);
    Runner_updateMousePosition(runner, winW, winH, gCursorX * winW, gCursorY * winH);
    Runner_drawViews(runner, gameW, gameH, false);
    runner->renderer->vtable->endFrameInit(runner->renderer);
    Runner_drawPost(runner, winW, winH);
    runner->renderer->vtable->endFrameEnd(runner->renderer);
    Runner_drawGUI(runner, winW, winH, gameW, gameH);

    gViewport[0] = (int32_t) runner->viewportX;
    gViewport[1] = (int32_t) runner->viewportY;
    gViewport[2] = (int32_t) runner->viewportW;
    gViewport[3] = (int32_t) runner->viewportH;

    bool shouldPresent = (runner->pendingRoom == -1);
    Runner_handlePendingRoomChange(runner);
    return shouldPresent ? BS_IOS_CONTINUE : BS_IOS_CONTINUE_NO_PRESENT;
}
