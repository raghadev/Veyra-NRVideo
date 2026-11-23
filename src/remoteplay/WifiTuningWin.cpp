// SPDX-License-Identifier: GPL-3.0-only
// wlanapi.dll binding for WifiTuning. Loaded from System32 at run time, so a PC without the WLAN
// service (or without Wi-Fi) still opens the session; WifiTuning then reports ApiUnavailable.
#include "veyra/remoteplay/WifiTuning.h"
#ifdef _WIN32
#include <windows.h>
#include <wlanapi.h>
#include <cstring>
#endif

namespace veyra::remoteplay {
#ifdef _WIN32
namespace {
// GetProcAddress returns a generic FARPROC; going through void(*)() is the warning-free way to cast it.
template<class T> T proc(HMODULE dll,const char* name){return reinterpret_cast<T>(reinterpret_cast<void(*)()>(GetProcAddress(dll,name)));}
class WlanApi final : public WifiApi {
public:
    ~WlanApi() override { close(); if(dll_)FreeLibrary(dll_); }
    std::uint32_t open() override {
        dll_=LoadLibraryExW(L"wlanapi.dll",nullptr,LOAD_LIBRARY_SEARCH_SYSTEM32);
        if(!dll_){const DWORD e=GetLastError();return e?e:ERROR_MOD_NOT_FOUND;}
        open_=proc<decltype(open_)>(dll_,"WlanOpenHandle");
        close_=proc<decltype(close_)>(dll_,"WlanCloseHandle");
        enum_=proc<decltype(enum_)>(dll_,"WlanEnumInterfaces");
        set_=proc<decltype(set_)>(dll_,"WlanSetInterface");
        free_=proc<decltype(free_)>(dll_,"WlanFreeMemory");
        if(!open_||!close_||!enum_||!set_||!free_)return ERROR_PROC_NOT_FOUND;
        DWORD negotiated=0;
        return open_(2,nullptr,&negotiated,&handle_);
    }
    std::uint32_t interfaces(std::vector<WifiInterface>& out) override {
        PWLAN_INTERFACE_INFO_LIST list=nullptr;
        if(const DWORD e=enum_(handle_,nullptr,&list))return e;
        for(DWORD i=0;list&&i<list->dwNumberOfItems;++i){
            const auto& info=list->InterfaceInfo[i];
            WifiInterface w;
            static_assert(sizeof(GUID)==16);
            std::memcpy(w.guid.data(),&info.InterfaceGuid,sizeof(GUID));
            w.connected=info.isState==wlan_interface_state_connected;
            out.push_back(w);
        }
        if(list)free_(list);
        return 0;
    }
    std::uint32_t setBackgroundScan(const WifiInterface& w,bool enabled) override { return set(w,wlan_intf_opcode_background_scan_enabled,enabled); }
    std::uint32_t setMediaStreaming(const WifiInterface& w,bool enabled) override { return set(w,wlan_intf_opcode_media_streaming_mode,enabled); }
    void close() override { if(handle_&&close_)close_(handle_,nullptr); handle_=nullptr; }
private:
    std::uint32_t set(const WifiInterface& w,WLAN_INTF_OPCODE op,bool enabled) {
        GUID guid;std::memcpy(&guid,w.guid.data(),sizeof(GUID));
        BOOL value=enabled?TRUE:FALSE; // documented data type for both opcodes
        return set_(handle_,&guid,op,sizeof(value),&value,nullptr);
    }
    HMODULE dll_=nullptr;
    HANDLE handle_=nullptr;
    decltype(&WlanOpenHandle) open_=nullptr;
    decltype(&WlanCloseHandle) close_=nullptr;
    decltype(&WlanEnumInterfaces) enum_=nullptr;
    decltype(&WlanSetInterface) set_=nullptr;
    decltype(&WlanFreeMemory) free_=nullptr;
};
} // namespace
std::unique_ptr<WifiApi> makeSystemWifiApi() { return std::make_unique<WlanApi>(); }
#else
std::unique_ptr<WifiApi> makeSystemWifiApi() { return nullptr; }
#endif
} // namespace veyra::remoteplay
