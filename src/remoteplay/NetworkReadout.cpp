// SPDX-License-Identifier: GPL-3.0-only
#include "veyra/remoteplay/NetworkReadout.h"

namespace veyra::remoteplay {
NetworkReadout makeNetworkReadout(const NetworkCounters& now, const NetworkCounters* previous, double seconds) {
    NetworkReadout out;
    if(!now.valid)return out;
    out.valid=true;
    out.adaptive=now.adaptive;
    out.tooLateTimeout=now.tooLateTimeout;
    out.tooLateFec=now.tooLateFec;
    out.waitMaxMs=static_cast<double>(now.waitUsMax)/1000.0;
    out.windowMs=static_cast<double>(now.windowUs)/1000.0;
    const uint64_t packets=now.packetReceived+now.packetLost;
    if(packets>0)out.lossPercent=100.0*static_cast<double>(now.packetLost)/static_cast<double>(packets);
    if(!previous||!previous->valid||!(seconds>0))return out;
    const auto& p=*previous;
    if(now.gaps<p.gaps||now.fecSkips<p.fecSkips||now.timeoutSkips<p.timeoutSkips||now.waitUsTotal<p.waitUsTotal)
        return out; // counters restarted: a new session, no rate for this reading
    const auto rate=[&](uint64_t a,uint64_t b){return static_cast<double>(a-b)/seconds;};
    out.gapsPerSecond=rate(now.gaps,p.gaps);
    out.fecSkipsPerSecond=rate(now.fecSkips,p.fecSkips);
    out.timeoutSkipsPerSecond=rate(now.timeoutSkips,p.timeoutSkips);
    out.waitMsPerSecond=rate(now.waitUsTotal,p.waitUsTotal)/1000.0;
    return out;
}
} // namespace veyra::remoteplay
