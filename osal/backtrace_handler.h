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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_OSAL_BACKTRACE_HANDLER_H
#define FOUNDATION_ACE_ADAPTER_IOS_OSAL_BACKTRACE_HANDLER_H

#include <cstdint>

namespace OHOS::Ace::Platform {

/**
 * Installs async-signal-safe crash handlers (SIGSEGV/SIGABRT/SIGBUS/SIGILL/
 * SIGFPE) that dump a frame-pointer based native backtrace. Idempotent. Invoke
 * once from the iOS engine init (StageApplication +initApplication:).
 *
 * This is the iOS counterpart of the FP-chain crash handler. Key differences
 * vs the other-platform build:
 *  - No /proc/self/maps on Darwin; the loaded-image table is pre-cached at init
 *    via the dyld API (_dyld_image_count / _dyld_get_image_*). dyld is NOT
 *    async-signal-safe, so caching happens in normal context, not in the handler.
 *  - Each frame prints "<image>+0x<vaddr>" where vaddr = runtime_pc - the
 *    image's ASLR slide (the static/unslid address). Feed it to atos:
 *      atos -arch arm64 -o <image_binary_or_dsym> 0x<vaddr>
 *  - Output goes to write(STDERR_FILENO) (fd 2 -> syslog/Console.app); os_log is
 *    not async-signal-safe and is avoided inside the handler.
 *
 * The FP chain (x29) is walked only on arm64; on other ABIs only the signal is
 * reported. Frames that omit the frame pointer (JIT/JS, some libs) terminate
 * the chain. The pre-existing (system) handler is saved and chained to, so iOS
 * still produces its own crash log.
 */
void InitBacktraceHandler();

/**
 * Dumps the FP chain from the given frame pointer, using the same
 * async-signal-safe path as the crash handler. Intended for diagnostics/tests.
 * @param fp frame pointer to start walking from. No-op when fp == 0.
 */
void DumpBacktraceFromFp(uintptr_t fp);

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_OSAL_BACKTRACE_HANDLER_H
