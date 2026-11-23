// SPDX-License-Identifier: GPL-3.0-only
#include "veyra/remoteplay/WifiTuning.h"

namespace veyra::remoteplay {
const char* toString(WifiTuningStatus status) {
    switch(status){
    case WifiTuningStatus::Applied: return "applied";
    case WifiTuningStatus::NoWifi: return "no-connected-wifi";
    case WifiTuningStatus::ApiUnavailable: return "wlan-api-unavailable";
    case WifiTuningStatus::Failed: return "failed";
    }
    return "unknown";
}

WifiTuning::WifiTuning(std::unique_ptr<WifiApi> api):api_(std::move(api)) {
    if(!api_)return;
    try{
        lastError_=api_->open();
        if(lastError_)return; // ApiUnavailable
        opened_=true;
        std::vector<WifiInterface> list;
        lastError_=api_->interfaces(list);
        if(lastError_){status_=WifiTuningStatus::Failed;return;}
        bool connected=false;
        for(const auto& iface:list){
            if(!iface.connected)continue; // the settings exist only while connected
            connected=true;
            // Recorded before each call so a throwing driver call still leaves an exact undo list.
            adjusted_.push_back({iface});
            if(const auto e=api_->setBackgroundScan(iface,false))lastError_=e;else adjusted_.back().scanDisabled=true;
            if(const auto e=api_->setMediaStreaming(iface,true))lastError_=e;else adjusted_.back().streamingEnabled=true;
            if(!adjusted_.back().scanDisabled&&!adjusted_.back().streamingEnabled)adjusted_.pop_back();
        }
        status_=!connected?WifiTuningStatus::NoWifi:adjusted_.empty()?WifiTuningStatus::Failed:WifiTuningStatus::Applied;
    }catch(...){
        status_=WifiTuningStatus::Failed;
    }
}

WifiTuning::~WifiTuning() {
    for(auto it=adjusted_.rbegin();it!=adjusted_.rend();++it){
        if(it->streamingEnabled)try{(void)api_->setMediaStreaming(it->iface,false);}catch(...){}
        if(it->scanDisabled)try{(void)api_->setBackgroundScan(it->iface,true);}catch(...){}
    }
    if(opened_)try{api_->close();}catch(...){}
}
} // namespace veyra::remoteplay
