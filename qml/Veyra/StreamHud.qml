// The stream's own numbers (Ctrl+Alt+Shift+S while streaming): what the host and the network contribute
// before the picture reaches the software's effect chain, for PC (Moonlight), Xbox and PS5 streams. The
// software's own processing time is on the performance readouts of the professional page; nothing here is
// invented: a value the stream does not report shows as a dash.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: hud
    objectName: "stream-hud"
    readonly property var ml: veyra.moonlight
    readonly property var xb: veyra.xbox
    readonly property bool xboxOn: !!xb && xb.state.streaming === true
    readonly property bool pcOn: !!ml && ml.state.streaming === true
    // PS5: how long the picture waited for missing video packets (Chiaki av-reorder patch); -1 = not measured.
    readonly property var ps: veyra.ps5Stream || ({})
    readonly property bool psOn: !xboxOn && !pcOn && ps.streaming === true
    readonly property var s: xboxOn ? (xb.state.stream || ({})) : pcOn ? (ml.state.stream || ({})) : ({})
    readonly property bool shown: (xboxOn || pcOn || psOn) && veyra.moonlightStatsVisible
    // Cut out of the native video window like the dialogs, so it is readable over the picture.
    readonly property bool videoCover: true
    property real coverRadius: 10

    function ms(v) { return v > 0 ? v.toFixed(1) + " ms" : "—" }
    function num(v) { return v > 0 ? v.toFixed(1) : "—" }
    // PS5 values: zero is a real measurement there, only a negative value means "not measured" (shown as "-").
    function msz(v) { return v >= 0 ? v.toFixed(1) + " ms" : "-" }
    function numz(v) { return v >= 0 ? v.toFixed(1) : "-" }
    function pct(v) { return v >= 0 ? v.toFixed(2) + "%" : "-" }
    function cnt(v) { return v >= 0 ? Math.round(v).toString() : "-" }

    visible: shown
    width: col.implicitWidth + 28
    height: col.implicitHeight + 24
    radius: 10
    color: Qt.rgba(0.04, 0.04, 0.05, 0.86)
    border.width: 1
    border.color: Theme.stroke2
    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 4
        Text {
            visible: !hud.psOn
            text: (hud.xboxOn ? "Xbox · " : "PC · ") + (s.width > 0 ? s.width + "×" + s.height : "") + " · " + (s.codec || "")
                + (s.hdr ? " HDR" : "") + " · " + (s.hardware ? qsTr("硬件解码") : qsTr("软件解码"))
            color: Theme.t1
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
        }
        Text {
            visible: hud.psOn
            text: "PS5 · " + (hud.ps.adaptive ? qsTr("丢包等待：自适应") : qsTr("丢包等待：固定 16 ms"))
            color: Theme.t1
            font.family: Theme.fontMono
            font.pixelSize: 12
            font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
        }
        Text {
            visible: hud.psOn
            text: qsTr("收 ") + hud.numz(hud.ps.receivedFps) + qsTr(" / 解 ") + hud.numz(hud.ps.decodedFps) + qsTr(" fps  ·  丢包 ") + hud.pct(hud.ps.lossPercent)
            color: Theme.t2
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            visible: hud.psOn
            text: qsTr("缺包 ") + hud.numz(hud.ps.gapsPerSecond) + qsTr("/s  ·  纠错即时恢复 ") + hud.numz(hud.ps.fecSkipsPerSecond)
                + qsTr("/s  ·  超时跳过 ") + hud.numz(hud.ps.timeoutSkipsPerSecond) + "/s"
            color: (hud.ps.timeoutSkipsPerSecond || 0) > 0 ? Theme.warn : Theme.t2
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            visible: hud.psOn
            text: qsTr("等待 ") + hud.msz(hud.ps.waitMsPerSecond) + qsTr("/s  ·  最长 ") + hud.msz(hud.ps.waitMaxMs)
                + qsTr("  ·  当前等待上限 ") + hud.msz(hud.ps.windowMs)
            color: Theme.t2
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            visible: hud.psOn
            text: qsTr("迟到包 ") + hud.cnt(hud.ps.tooLateTimeout) + qsTr("  ·  已被纠错覆盖 ") + hud.cnt(hud.ps.tooLateFec)
            color: (hud.ps.tooLateTimeout || 0) > 0 ? Theme.warn : Theme.t3
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            visible: !hud.xboxOn && !hud.psOn
            text: qsTr("主机 ") + hud.ms(s.hostMs) + qsTr("  ·  往返 ") + hud.ms(s.rttMs) + qsTr("  ·  接收 ") + hud.ms(s.receiveMs)
                + qsTr("  ·  排队 ") + hud.ms(s.queueMs) + qsTr("  ·  解码 ") + hud.ms(s.decodeMs)
                + qsTr("  ·  码率 ") + (s.videoMbps > 0 ? s.videoMbps.toFixed(1) + " Mbps" : "—")
            color: Theme.t2
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            visible: hud.xboxOn
            text: qsTr("往返 ") + hud.ms(s.rttMs) + qsTr("  ·  解码 ") + hud.ms(s.decodeMs) + qsTr("  ·  码率 ") + (s.videoMbps > 0 ? s.videoMbps.toFixed(1) + " Mbps" : "—")
            color: Theme.t2
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            visible: !hud.psOn
            text: hud.xboxOn
                ? qsTr("收 ") + hud.num(s.receivedFps) + qsTr(" / 解 ") + hud.num(s.decodedFps) + qsTr(" fps  ·  丢帧 ") + (s.dropped || 0) + qsTr("  ·  关键帧请求 ") + (s.keyframes || 0)
                : qsTr("收 ") + hud.num(s.receivedFps) + qsTr(" / 解 ") + hud.num(s.decodedFps) + qsTr(" fps  ·  包 ") + (s.packets || 0)
                  + qsTr("  ·  FEC 恢复 ") + (s.recovered || 0) + qsTr("  ·  未恢复 ") + (s.lost || 0) + qsTr("  ·  丢帧 ") + (s.dropped || 0)
            color: (s.lost || 0) > 0 ? Theme.warn : Theme.t2
            font.family: Theme.fontMono
            font.pixelSize: 11
        }
        Text {
            text: hud.xboxOn || hud.psOn ? qsTr("Ctrl+Alt+Shift+S 隐藏") :
                  veyra.moonlightCaptured ? qsTr("键盘鼠标已交给主机 · Ctrl+Alt+Shift+Z 释放 · +Q 断开") : qsTr("键盘鼠标未捕获 · 点击画面捕获")
            color: !hud.xboxOn && !hud.psOn && veyra.moonlightCaptured ? Theme.ok : Theme.t3
            font.family: Theme.fontUi
            font.pixelSize: 11
        }
    }
}
