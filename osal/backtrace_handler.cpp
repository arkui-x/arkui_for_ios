/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "backtrace_handler.h"

#include <cerrno>
#include <csignal>
#include <cstdint>
#include <sys/ucontext.h>
#include <unistd.h>

#include <atomic>

#include <mach-o/dyld.h>

// Engine log. Only used from the normal (non-signal) context, e.g. inside
// InitBacktraceHandler(). NEVER call LOG* from within the signal handler:
// HILOG/os_log route through IPC/locks/malloc and are not async-signal-safe.
#include "base/log/log.h"

// iOS port note: /proc/self/maps does not exist on Darwin; the image table is
// pre-cached via the dyld API at init time.

namespace OHOS::Ace::Platform {
namespace {

// ---------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------
constexpr uint32_t MAX_STACK_DEPTH = 64;
constexpr uintptr_t INSTRUCTION_LENGTH = 4; // aarch64 fixed-width instruction
constexpr size_t MAX_IMAGES = 1024;
constexpr size_t MAX_NAME_LEN = 128;
constexpr size_t DUMP_BUF_SIZE = 8192;
constexpr size_t ALT_STACK_SIZE = 64 * 1024;
constexpr int DECIMAL_BASE = 10; // base for decimal formatting
constexpr int HEX_SHIFT = 4;     // bits per hex digit

// ---------------------------------------------------------------------------
// Loaded-image table (pre-cached from dyld at init; read-only in the handler)
// ---------------------------------------------------------------------------
struct ImageRecord {
    uintptr_t loadAddr; // runtime load address = vmaddr + slide
    intptr_t slide;     // ASLR slide
    char name[MAX_NAME_LEN];
};

ImageRecord g_images[MAX_IMAGES];
size_t g_imageCount = 0;

void LoadImages()
{
    g_imageCount = 0;
    const uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count && g_imageCount < MAX_IMAGES; ++i) {
        const char* name = _dyld_get_image_name(i);
        // The Mach-O header sits at the image's runtime load address; the slide
        // is its ASLR offset. (dyld has no _dyld_get_image_vmaddr/_slide; the
        // real APIs are _dyld_get_image_header and _dyld_get_image_vmaddr_slide.)
        const struct mach_header* header = _dyld_get_image_header(i);
        if (name == nullptr || header == nullptr) {
            continue;
        }
        ImageRecord& img = g_images[g_imageCount];
        img.loadAddr = reinterpret_cast<uintptr_t>(header);
        img.slide = _dyld_get_image_vmaddr_slide(i);
        size_t nameIdx = 0;
        for (; nameIdx + 1 < MAX_NAME_LEN && name[nameIdx] != '\0'; ++nameIdx) {
            img.name[nameIdx] = name[nameIdx];
        }
        img.name[nameIdx] = '\0';
        ++g_imageCount;
    }
}

// Returns the image whose load address is the largest one <= addr (images do
// not overlap, so that is the image containing addr). Heuristic: a PC in a gap
// between images would be attributed to the lower image; rare for code PCs.
const ImageRecord* FindImage(uintptr_t addr)
{
    const ImageRecord* bestImg = nullptr;
    for (size_t i = 0; i < g_imageCount; ++i) {
        const ImageRecord& img = g_images[i];
        if (img.loadAddr <= addr && (bestImg == nullptr || img.loadAddr > bestImg->loadAddr)) {
            bestImg = &img;
        }
    }
    return bestImg;
}

// ---------------------------------------------------------------------------
// Output buffer + async-signal-safe append helpers (zero allocation)
// ---------------------------------------------------------------------------
struct DumpBuffer {
    char data[DUMP_BUF_SIZE];
    size_t len;
};

void AppendCh(DumpBuffer& buf, char ch)
{
    if (buf.len < DUMP_BUF_SIZE - 1) {
        buf.data[buf.len++] = ch;
    }
}

void AppendLit(DumpBuffer& buf, const char* text)
{
    while (*text != '\0') {
        AppendCh(buf, *text++);
    }
}

void AppendStrN(DumpBuffer& buf, const char* text, size_t len)
{
    for (size_t i = 0; i < len; ++i) {
        if (text[i] == '\0') {
            break;
        }
        AppendCh(buf, text[i]);
    }
}

void AppendHex(DumpBuffer& buf, uintptr_t value)
{
    static const char* digits = "0123456789abcdef";
    char tmp[2 * sizeof(uintptr_t)];
    int i = 0;
    if (value == 0) {
        AppendCh(buf, '0');
        return;
    }
    while (value != 0) {
        tmp[i++] = digits[value & 0xf];
        value >>= HEX_SHIFT;
    }
    while (i > 0) {
        AppendCh(buf, tmp[--i]);
    }
}

void AppendHex0x(DumpBuffer& buf, uintptr_t value)
{
    AppendLit(buf, "0x");
    AppendHex(buf, value);
}

void AppendDec(DumpBuffer& buf, uint32_t value)
{
    char tmp[10];
    int i = 0;
    if (value == 0) {
        AppendCh(buf, '0');
        return;
    }
    while (value != 0) {
        tmp[i++] = '0' + (value % DECIMAL_BASE);
        value /= DECIMAL_BASE;
    }
    while (i > 0) {
        AppendCh(buf, tmp[--i]);
    }
}

// Signed-decimal variant for values that may legitimately be negative on Darwin,
// e.g. siginfo_t::si_code (SI_USER / SI_TKILL for SIGABRT raised by
// abort()/raise()/pthread_kill()). AppendDec only formats the unsigned magnitude.
void AppendDecSigned(DumpBuffer& buf, int32_t value)
{
    uint32_t magnitude;
    if (value < 0) {
        AppendCh(buf, '-');
        // Negate without UB: -(value + 1) + 1 is safe even for INT32_MIN.
        magnitude = static_cast<uint32_t>(-(value + 1)) + 1U;
    } else {
        magnitude = static_cast<uint32_t>(value);
    }
    AppendDec(buf, magnitude);
}

// Writes the whole buffer to stderr (async-signal-safe). Resets buf.len to 0 so
// DumpBacktrace can flush frame-by-frame (a later re-fault must not discard the
// already-collected frames held in this buffer).
void FlushDump(DumpBuffer& buf)
{
    // write(2) is async-signal-safe; on iOS fd 2 reaches syslog/Console.app.
    ssize_t written = 0;
    while (written < static_cast<ssize_t>(buf.len)) {
        ssize_t bytes = write(STDERR_FILENO, buf.data + written, buf.len - written);
        if (bytes > 0) {
            written += bytes;
        } else if (bytes < 0 && errno == EINTR) {
            continue;
        } else {
            break;
        }
    }
    buf.len = 0;
}

// ---------------------------------------------------------------------------
// Frame printing: "<image>+0x<vaddr>" where vaddr = pc - slide (static/unslid
// address consumable by `atos`).
// ---------------------------------------------------------------------------
void PrintFrame(DumpBuffer& buf, uint32_t idx, uintptr_t pc)
{
    AppendLit(buf, "  #");
    AppendDec(buf, idx);
    AppendLit(buf, " pc=");
    AppendHex0x(buf, pc);
    const ImageRecord* img = FindImage(pc);
    if (img != nullptr) {
        AppendLit(buf, " ");
        AppendStrN(buf, img->name, MAX_NAME_LEN);
        AppendLit(buf, "+0x");
        AppendHex(buf, pc - static_cast<uintptr_t>(img->slide));
    }
    AppendCh(buf, '\n');
}

// ---------------------------------------------------------------------------
// Frame-pointer chain walk + dump
// ---------------------------------------------------------------------------
void DumpSignalHeader(DumpBuffer& buf, int sig, siginfo_t* info)
{
    AppendLit(buf, "\n================ ArkUI-x native crash ================\n");
    AppendLit(buf, "Fatal signal ");
    AppendDec(buf, static_cast<uint32_t>(sig));
    AppendLit(buf, " (");
    switch (sig) {
        case SIGSEGV: AppendLit(buf, "SIGSEGV"); break;
        case SIGABRT: AppendLit(buf, "SIGABRT"); break;
        case SIGBUS:  AppendLit(buf, "SIGBUS"); break;
        case SIGILL:  AppendLit(buf, "SIGILL"); break;
        case SIGFPE:  AppendLit(buf, "SIGFPE"); break;
        default:      AppendLit(buf, "?"); break;
    }
    AppendLit(buf, "), si_code ");
    AppendDecSigned(buf, info ? info->si_code : 0);
    if (info != nullptr && info->si_addr != nullptr) {
        AppendLit(buf, ", fault addr ");
        AppendHex0x(buf, reinterpret_cast<uintptr_t>(info->si_addr));
    }
    AppendCh(buf, '\n');
}

void DumpBacktrace(DumpBuffer& buf, uintptr_t fp, uintptr_t faultPc)
{
    AppendLit(buf, "Backtrace (frame-pointer chain):\n");

#if defined(__arm64__)
    uint32_t idx = 0;

    // #0 = the faulting instruction itself (the crashing function).
    if (faultPc != 0) {
        PrintFrame(buf, idx++, faultPc);
    }

    if (fp == 0) {
        AppendLit(buf, "  fp == 0, cannot walk the chain\n");
        return;
    }

    // No stack-range bound on iOS (no /proc/self/maps); rely on the 16-byte
    // alignment check, the monotonic-up check, and the depth cap to stop a
    // corrupted chain.
    for (; idx < MAX_STACK_DEPTH; ++idx) {
        // arm64 stack frames are 16-byte aligned; a corrupted fp or one that
        // came from a frame-pointer-omitting function (JIT/JS, some libs) is
        // usually mis-aligned. Stop the walk instead of dereferencing it,
        // which would re-fault inside the handler.
        if (fp == 0 || (fp & 0xf) != 0) {
            break;
        }
        // [fp + 0] = saved x29 (previous frame), [fp + 8] = saved x30 (LR).
        uintptr_t lr = *reinterpret_cast<uintptr_t*>(fp + 8);
        uintptr_t next = *reinterpret_cast<uintptr_t*>(fp);
        uintptr_t callSite = (lr != 0) ? lr - INSTRUCTION_LENGTH : 0;
        if (callSite == 0) {
            break; // bottom-of-stack frame: saved LR is 0 (no caller), stop.
        }
        PrintFrame(buf, idx, callSite);
        // Flush each frame as soon as it is printed. If a later dereference
        // re-faults, g_inHandler's re-entrancy guard skips the final FlushDump,
        // so buffering frames until the end would lose them all; per-frame
        // flushing preserves everything already walked.
        FlushDump(buf);
        if (next <= fp) {
            break; // stack grows down: previous fp must be higher
        }
        fp = next;
    }
#else
    (void)fp;
    (void)faultPc;
    AppendLit(buf, "  FP-chain walk is only implemented on arm64\n");
#endif
}

// ---------------------------------------------------------------------------
// Signal handler
// ---------------------------------------------------------------------------
std::atomic<bool> g_installed { false };
std::atomic<bool> g_inHandler { false };
struct sigaction g_savedHandlers[NSIG];

void ForwardToPrevious(int sig, siginfo_t* info, void* context)
{
    const struct sigaction& prev = g_savedHandlers[sig];
    if (prev.sa_flags & SA_SIGINFO) {
        if (prev.sa_sigaction != nullptr) {
            prev.sa_sigaction(sig, info, context);
            return;
        }
    } else if (prev.sa_handler != SIG_DFL && prev.sa_handler != SIG_IGN &&
               prev.sa_handler != SIG_ERR) {
        prev.sa_handler(sig);
        return;
    }

    // SIG_DFL / SIG_IGN: restore prior disposition and re-raise so iOS still
    // produces its own crash log.
    sigaction(sig, &prev, nullptr);
    if (prev.sa_handler != SIG_IGN) {
        sigset_t mask;
        sigemptyset(&mask);
        sigaddset(&mask, sig);
        sigprocmask(SIG_UNBLOCK, &mask, nullptr);
        raise(sig);
    }
}

void CrashHandler(int sig, siginfo_t* info, void* context)
{
    bool expected = false;
    if (!g_inHandler.compare_exchange_strong(expected, true)) {
        ForwardToPrevious(sig, info, context);
        return;
    }

    uintptr_t fp = 0;
    uintptr_t faultPc = 0;
#if defined(__arm64__)
    if (context != nullptr) {
        // Darwin arm64 ucontext. The thread-state member is `__ss` on current
        // SDKs (older ones used `ss`); toggle __ss <-> ss if this errors.
        auto* uc = static_cast<ucontext_t*>(context);
        fp = uc->uc_mcontext->__ss.__fp;  // saved x29 of the interrupted frame
        faultPc = uc->uc_mcontext->__ss.__pc;
    }
#endif

    DumpBuffer dump {};
    DumpSignalHeader(dump, sig, info);
    DumpBacktrace(dump, fp, faultPc);
    AppendLit(dump, "======================================================\n");
    FlushDump(dump);

    g_inHandler.store(false);

    ForwardToPrevious(sig, info, context);
}

// ---------------------------------------------------------------------------
// Installation (runs in normal context)
// ---------------------------------------------------------------------------
void InstallAltStack()
{
    // sigaltstack is per-thread on Darwin. This protects ONLY the thread that
    // calls InitBacktraceHandler (the init/main thread). Other threads have no
    // alternate stack: a stack-overflow crash on them runs CrashHandler on the
    // already-exhausted stack, which faults again when allocating DumpBuffer
    // and the kernel terminates with no dump. Registering sigaltstack for every
    // framework-spawned thread requires a creation-time hook and is left as a
    // follow-up. (Ordinary SEGV/ABRT on any thread still works - only the
    // stack-overflow case is affected.)
    static char altStack[ALT_STACK_SIZE];
    stack_t sigStack {};
    sigStack.ss_sp = altStack;
    sigStack.ss_size = sizeof(altStack);
    sigStack.ss_flags = 0;
    if (sigaltstack(&sigStack, nullptr) != 0) {
        // Registration failed; the init thread also falls back to its normal
        // stack for stack-overflow crashes. Ordinary SEGV/ABRT are unaffected.
    }
}

} // namespace

void InitBacktraceHandler()
{
    bool expected = false;
    if (!g_installed.compare_exchange_strong(expected, true)) {
        return;
    }

    LoadImages(); // pre-cache dyld image table (dyld is not async-signal-safe)

    InstallAltStack();

    struct sigaction sa {};
    sa.sa_sigaction = CrashHandler;
    sa.sa_flags = SA_SIGINFO | SA_ONSTACK;
    sigemptyset(&sa.sa_mask);

    const int handledSignals[] = { SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGFPE };
    for (int sig : handledSignals) {
        struct sigaction old {};
        if (sigaction(sig, &sa, &old) == 0) {
            g_savedHandlers[sig] = old;
        }
    }

    LOGI("ArkUI-x backtrace handler installed.");
}

void DumpBacktraceFromFp(uintptr_t fp)
{
    bool expected = false;
    if (!g_inHandler.compare_exchange_strong(expected, true)) {
        return;
    }
    DumpBuffer dump {};
    DumpBacktrace(dump, fp, 0);
    AppendLit(dump, "(end of manual backtrace)\n");
    FlushDump(dump);
    g_inHandler.store(false);
}

} // namespace OHOS::Ace::Platform
