// Bowshot: a performance record in the game log. Every DM_PERF_LOG seconds (10 by default, 0 = off) of presented frames, one line:
//   [dm] perf: 10.0 s, 598 frames, 59.8 fps avg, 1% low 41.2 fps, worst 48.1 ms, 3 over 25 ms, 0 dropped, GPU avg 9.3 ms p95 13.1 ms
// It is what a player's performance report reads (README, "Share your results"): the average frame rate, the frame rate of the slowest 1 % of frames, and the GPU time.
// The graphics layer hands over each on-screen present interval (hle_nvn.c, taken 8 presents late) and each frame's GPU time (also 8 frames late): dm_perf_present and
// dm_perf_gpu, weak no-ops there. A window is counted in presented time, not wall time, so a pause or a covered window (front_mac.m: its display link then fires about
// once a second) shows as a few very slow frames, not as a window that never closes. Fixed bins, no sort, no allocation: this runs on the game's present path, which can be on
// a guest stack. The numbers are only worth taking while the game window is visible and the game is being played; menus and loading screens are in them too.
#include "dm.h"
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#define BIN_MS 0.5
#define NBIN 200   // 0 to 100 ms in half milliseconds; anything slower is counted in the last bin

typedef struct { unsigned n; double sum, worst; unsigned bin[NBIN]; } hist;

static pthread_mutex_t g_mu = PTHREAD_MUTEX_INITIALIZER;
static hist g_iv, g_gpu;   // presented intervals (ms), GPU times (ms)
static unsigned g_dropped, g_over25;
static double g_window_ms = -1;   // -1 = DM_PERF_LOG not read yet

static void hist_add(hist *h, double ms) {
    int b = (int)(ms / BIN_MS); if (b < 0) b = 0; if (b >= NBIN) b = NBIN - 1;
    h->bin[b]++; h->n++; h->sum += ms; if (ms > h->worst) h->worst = ms;
}

// The upper edge of the bin holding the q-quantile (0..1) of the samples counted from the fast end.
static double hist_quantile(const hist *h, double q) {
    unsigned want = (unsigned)(q * h->n + 0.999999); if (want < 1) want = 1;
    unsigned seen = 0;
    for (int b = 0; b < NBIN; b++) { seen += h->bin[b]; if (seen >= want) return (b + 1) * BIN_MS; }
    return NBIN * BIN_MS;
}

static void window_close(void) {
    if (g_iv.n) {
        double avg_fps = g_iv.n * 1000.0 / g_iv.sum, p99 = hist_quantile(&g_iv, 0.99), low_fps = 1000.0 / p99;
        if (g_gpu.n) LOG("perf: %.1f s, %u frames, %.1f fps avg, 1%% low %.1f fps, worst %.1f ms, %u over 25 ms, %u dropped, GPU avg %.1f ms p95 %.1f ms",
                         g_iv.sum / 1000.0, g_iv.n, avg_fps, low_fps, g_iv.worst, g_over25, g_dropped, g_gpu.sum / g_gpu.n, hist_quantile(&g_gpu, 0.95));
        else LOG("perf: %.1f s, %u frames, %.1f fps avg, 1%% low %.1f fps, worst %.1f ms, %u over 25 ms, %u dropped, GPU n/a",
                 g_iv.sum / 1000.0, g_iv.n, avg_fps, low_fps, g_iv.worst, g_over25, g_dropped);
    }
    memset(&g_iv, 0, sizeof g_iv); memset(&g_gpu, 0, sizeof g_gpu); g_dropped = g_over25 = 0;
}

static int enabled(void) {
    if (g_window_ms < 0) {
        const char *e = getenv("DM_PERF_LOG"); double s = e && *e ? atof(e) : 10;
        g_window_ms = s > 0 ? (s < 1 ? 1 : s) * 1000.0 : 0;
    }
    return g_window_ms > 0;
}

// iv_ms: the on-screen interval to the previous present; -1 = a frame the system never showed (merged into a later one), 0 = no reading.
void dm_perf_present(double iv_ms) {
    pthread_mutex_lock(&g_mu);
    if (enabled()) {
        if (iv_ms < 0) g_dropped++;
        else if (iv_ms > 0) {
            hist_add(&g_iv, iv_ms); if (iv_ms > 25.0) g_over25++;
            if (g_iv.sum >= g_window_ms) window_close();
        }
    }
    pthread_mutex_unlock(&g_mu);
}

void dm_perf_gpu(double gpu_ms) {
    if (gpu_ms < 0) return;
    pthread_mutex_lock(&g_mu);
    if (enabled()) hist_add(&g_gpu, gpu_ms);
    pthread_mutex_unlock(&g_mu);
}
