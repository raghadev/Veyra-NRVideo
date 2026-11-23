// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <array>
#include <cstdint>
#include <memory>
#include <vector>

namespace veyra::remoteplay {
// While a PS5 session runs, ask Windows to keep each connected Wi-Fi adapter from scanning for other
// networks (the periodic scan causes latency spikes) and to use its media streaming mode. Microsoft
// documents both settings as per client and only valid while connected, and does not say what happens
// when the client handle closes, so everything changed is undone explicitly. Never blocks the session.
struct WifiInterface { std::array<std::uint8_t,16> guid{}; bool connected=false; };

class WifiApi { // edge: wlanapi.dll on Windows, a fake in the tests
public:
    virtual ~WifiApi()=default;
    virtual std::uint32_t open()=0; // 0 = success, otherwise a Win32 error code
    virtual std::uint32_t interfaces(std::vector<WifiInterface>& out)=0;
    virtual std::uint32_t setBackgroundScan(const WifiInterface&,bool enabled)=0;
    virtual std::uint32_t setMediaStreaming(const WifiInterface&,bool enabled)=0;
    virtual void close()=0;
};

enum class WifiTuningStatus { Applied, NoWifi, ApiUnavailable, Failed };
const char* toString(WifiTuningStatus status);

class WifiTuning { // constructing applies, destroying undoes; never throws
public:
    explicit WifiTuning(std::unique_ptr<WifiApi> api);
    ~WifiTuning();
    WifiTuning(const WifiTuning&)=delete;
    WifiTuning& operator=(const WifiTuning&)=delete;
    WifiTuningStatus status() const { return status_; }
    unsigned adjustedCount() const { return static_cast<unsigned>(adjusted_.size()); }
    std::uint32_t lastError() const { return lastError_; }
private:
    struct Adjusted { WifiInterface iface; bool scanDisabled=false, streamingEnabled=false; };
    std::unique_ptr<WifiApi> api_;
    std::vector<Adjusted> adjusted_;
    WifiTuningStatus status_=WifiTuningStatus::ApiUnavailable;
    std::uint32_t lastError_=0;
    bool opened_=false;
};

// Windows: wlanapi.dll loaded from System32 at run time. Other systems: nullptr (ApiUnavailable).
std::unique_ptr<WifiApi> makeSystemWifiApi();
} // namespace veyra::remoteplay
