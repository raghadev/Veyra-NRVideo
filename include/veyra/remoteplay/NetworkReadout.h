// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <cstdint>
#include <optional>

namespace veyra::remoteplay {
// One reading of the PS5 transport counters: Chiaki's packet window and its video reorder
// statistics (patch 0006). The packet window may be reset by Chiaki's congestion control.
struct NetworkCounters {
    bool valid=false, adaptive=false;
    uint64_t packetReceived=0, packetLost=0;
    uint64_t gaps=0, fecSkips=0, timeoutSkips=0, lateFills=0, tooLateTimeout=0, tooLateFec=0, waitUsTotal=0;
    uint32_t waitUsMax=0, windowUs=0;
};

// What the PS5 stream panel shows. std::nullopt means not measured: the panel shows a dash.
struct NetworkReadout {
    bool valid=false, adaptive=false;
    std::optional<double> lossPercent, gapsPerSecond, fecSkipsPerSecond, timeoutSkipsPerSecond,
        waitMsPerSecond, waitMaxMs, windowMs;
    uint64_t tooLateTimeout=0, tooLateFec=0;
};

// Rates need a previous valid reading taken `seconds` earlier; a counter that went down (a new
// session) leaves the rates unmeasured for that reading instead of producing negative numbers.
NetworkReadout makeNetworkReadout(const NetworkCounters& now, const NetworkCounters* previous, double seconds);
} // namespace veyra::remoteplay
