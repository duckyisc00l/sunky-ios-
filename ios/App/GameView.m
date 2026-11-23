#define GLES_SILENCE_DEPRECATION 1
#import "GameView.h"
#import "Sunky.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/gl.h>
#import <QuartzCore/QuartzCore.h>

static __weak GameView *gCurrent;
static EAGLContext *gContext;
static GLuint gFbo, gColor;
static CAEAGLLayer *gLayer;
static GLint gScreenW, gScreenH;

void sunky_gl_screen_size(int32_t *w, int32_t *h) { *w = gScreenW; *h = gScreenH; }

@implementation GameView
+ (Class)layerClass { return [CAEAGLLayer class]; }
+ (GameView *)current { return gCurrent; }

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
        layer.opaque = YES;
        layer.drawableProperties = @{ kEAGLDrawablePropertyRetainedBacking: @NO,
                                      kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8 };
        self.contentScaleFactor = UIScreen.mainScreen.nativeScale;
        self.backgroundColor = UIColor.blackColor;
        self.multipleTouchEnabled = YES;
    }
    return self;
}
- (void)makeCurrent {
    gCurrent = self;
    gLayer = (CAEAGLLayer *)self.layer;
}
@end

// ---- Called by the runner (engine/ogmk/gm8emulator/src/render/opengl/eagl.rs), on its thread ----

uint32_t sunky_gl_setup(void) {
    gContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!gContext || ![EAGLContext setCurrentContext:gContext]) { SunkyLog(@"gl: no ES3 context"); return 0; }
    glGenFramebuffers(1, &gFbo);
    glBindFramebuffer(GL_FRAMEBUFFER, gFbo);
    glGenRenderbuffers(1, &gColor);
    glBindRenderbuffer(GL_RENDERBUFFER, gColor);
    __block BOOL ok = NO;
    // The layer must be laid out; storage can be allocated from this thread.
    ok = [gContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:gLayer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, gColor);
    GLint w = 0, h = 0;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &w);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &h);
    gScreenW = w; gScreenH = h;
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    SunkyLog(@"gl: screen %dx%d, storage %d, status 0x%x, %s", w, h, ok, status, glGetString(GL_VERSION));
    if (status != GL_FRAMEBUFFER_COMPLETE) return 0;
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    ramen_ios_resize((uint32_t)w, (uint32_t)h);
    return gFbo;
}

void sunky_gl_present(void) {
    glBindRenderbuffer(GL_RENDERBUFFER, gColor);
    [gContext presentRenderbuffer:GL_RENDERBUFFER];
}

void sunky_gl_teardown(void) {
    if (!gContext) return;
    [EAGLContext setCurrentContext:gContext];
    glDeleteFramebuffers(1, &gFbo);
    glDeleteRenderbuffers(1, &gColor);
    gFbo = gColor = 0;
    [EAGLContext setCurrentContext:nil];
    gContext = nil;
}
