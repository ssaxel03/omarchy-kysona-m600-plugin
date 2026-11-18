import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Bar widget and popup for the Kysona M600 2.4 GHz receiver battery.
// Data comes from battery.py (hidraw); UPower does not expose this dongle.
Panel {
  id: root
  moduleName: "ssaxel03.kysona-m600"
  ipcTarget: "ssaxel03.kysona-m600"

  readonly property string helperPath: String(Qt.resolvedUrl("battery.py")).replace(/^file:\/\//, "")

  property var battery: ({})
  readonly property bool available: battery.available === true
  readonly property bool charging: available && battery.charging === true
  readonly property double voltage: available ? Number(battery.voltage) : 0
  readonly property string errorText: available ? "" : String(battery.error || "")
  readonly property string mouseGlyph: "󰍽"

  // Smoothed level shown in the bar and panel. Raw readings are kept in
  // `battery` but never jump the display during a plug/unplug settling window.
  property real displayLevel: -1
  property int previousCharging: -1
  property real chargeStartTime: 0
  property real unplugStartTime: 0
  property real lastLevelChange: 0
  readonly property int voltageLevel: Math.max(0, Math.min(100, Math.round(displayLevel)))

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function glyph() {
    return mouseGlyph
  }

  function stateLabel() {
    if (!available) return strings.t("mouseBattery.unavailable")
    return charging ? strings.t("mouseBattery.charging") : strings.t("mouseBattery.discharging")
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  function apply(raw) {
    var parsed
    try {
      parsed = JSON.parse(String(raw || "").trim())
    } catch (error) {
      return
    }
    if (!parsed || typeof parsed !== "object") return

    var now = Date.now()
    var chargingNow = parsed.available === true && parsed.charging === true
    var nextLevel = -1
    if (parsed.available === true && parsed.voltageLevel !== undefined) {
      var value = Number(parsed.voltageLevel)
      if (isFinite(value) && value >= 0 && value <= 100) nextLevel = value
    }

    if (previousCharging === -1) {
      // First reading after the shell starts: show it immediately.
      if (nextLevel >= 0) {
        displayLevel = nextLevel
        lastLevelChange = now
      }
      previousCharging = chargingNow ? 1 : 0
      battery = parsed
      return
    }

    if (chargingNow && previousCharging === 0) chargeStartTime = now
    if (!chargingNow && previousCharging === 1) unplugStartTime = now
    previousCharging = chargingNow ? 1 : 0

    var plugGrace = chargingNow && now - chargeStartTime < 6000
    var unplugGrace = !chargingNow && now - unplugStartTime < 2000

    if (nextLevel >= 0 && !plugGrace && !unplugGrace) {
      if (displayLevel < 0) {
        displayLevel = nextLevel
        lastLevelChange = now
      } else if (now - lastLevelChange >= 15000) {
        var delta = nextLevel - displayLevel
        if (Math.abs(delta) <= 1) {
          displayLevel = nextLevel
        } else {
          displayLevel += delta > 0 ? 1 : -1
        }
        lastLevelChange = now
      }
    }

    battery = parsed
  }

  Process {
    id: probe
    command: ["python3", root.helperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (opened) root.refresh()

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.available
      ? root.mouseGlyph + " " + Commons.I18n.formatNumber(root.voltageLevel) + "%"
        + (root.charging ? " 󰂆" : "")
      : root.mouseGlyph + " —"
    fontSize: Style.font.body
    keepSpace: true
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)
    content: PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.glyph()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: strings.t("mouseBattery.title")
              textFormat: Text.PlainText
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.stateLabel().toUpperCase()
              textFormat: Text.PlainText
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            text: root.available ? Commons.I18n.formatNumber(root.voltageLevel) + "%" : "—"
            textFormat: Text.PlainText
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: fill
            anchors.left: track.left
            anchors.verticalCenter: track.verticalCenter
            height: track.height
            radius: track.radius
            color: root.bar.foreground
            width: root.available ? Math.max(track.height, track.width * root.voltageLevel / 100) : 0

            Behavior on width {
              NumberAnimation {
                duration: Style.duration(220)
                easing.type: Easing.OutCubic
              }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            text: strings.t("mouseBattery.device")
            textFormat: Text.PlainText
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            width: (parent.width - parent.spacing) / 2
          }
          Text {
            text: "Kysona M600"
            textFormat: Text.PlainText
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            width: (parent.width - parent.spacing) / 2
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            text: strings.t("mouseBattery.connection")
            textFormat: Text.PlainText
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            width: (parent.width - parent.spacing) / 2
          }
          Text {
            text: battery.source === "wired"
              ? strings.t("mouseBattery.connectionWired")
              : strings.t("mouseBattery.connectionWireless")
            textFormat: Text.PlainText
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            width: (parent.width - parent.spacing) / 2
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            text: strings.t("mouseBattery.voltage")
            textFormat: Text.PlainText
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            width: (parent.width - parent.spacing) / 2
          }
          Text {
            text: root.available ? Commons.I18n.formatNumber(root.voltage, 2) + " V" : "—"
            textFormat: Text.PlainText
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            width: (parent.width - parent.spacing) / 2
            horizontalAlignment: Text.AlignRight
          }
        }

        Text {
          visible: !root.available
          text: root.errorText || strings.t("mouseBattery.hint")
          textFormat: Text.PlainText
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }
      }
    }
  }
}
