// Functions exported by the Rust runner (engine/ogmk, engine/ramen, engine/udon).
#import <Foundation/Foundation.h>
#include <stdbool.h>
#include <stdint.h>

int32_t sunky_run_game(const char *path);

void ramen_ios_key(uint32_t vk, bool down);
void ramen_ios_mouse_move(uint32_t x, uint32_t y);
void ramen_ios_mouse_button(uint32_t button, bool down);
void ramen_ios_resize(uint32_t w, uint32_t h);
void ramen_ios_request_close(void);
uint32_t ramen_ios_game_size(void);

void udon_ios_set_sample_rate(uint32_t rate);
void udon_ios_render(float *out, uint32_t frames);
void udon_ios_stop(void);

// Windows virtual-key codes the games use
enum {
    VK_RETURN = 0x0D, VK_ESCAPE = 0x1B, VK_SPACE = 0x20,
    VK_LEFT = 0x25, VK_UP = 0x26, VK_RIGHT = 0x27, VK_DOWN = 0x28,
};

// The games in this app (folder Games/ in the bundle)
typedef struct { const char *file; const char *title; const char *subtitle; } SunkyGame;
extern const SunkyGame kSunkyGames[];
extern const int kSunkyGameCount;

// Log file in Documents (stdout and stderr go there too)
void SunkyLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
NSString *SunkyDocuments(void);
