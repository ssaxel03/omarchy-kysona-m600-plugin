import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Bar widget and popup for the Kysona M600 2.4 GHz receiver battery.
// Data comes from battery.py (hidraw); UPower does not expose this dongle.
Panel {
  id: root
  moduleName: "axel.kysona-m600"
  ipcTarget: "axel.kysona-m600"

  readonly property string helperPath: String(Qt.resolvedUrl("battery.py")).replace(/^file:\/\//, "")

  property var battery: ({})
  readonly property bool available: battery.available === true
  readonly property int percentage: available ? Math.max(0, Math.min(100, Number(battery.percentage))) : 0
  readonly property bool charging: available && battery.charging === true
  readonly property double voltage: available ? Number(battery.voltage) : 0
  readonly property string errorText: available ? "" : String(battery.error || "")

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function glyph() {
    if (!available) return "󰁺"
    var discharge = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰂅"]
    var charge = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
    var index = Math.max(0, Math.min(9, Math.floor(percentage / 10)))
    return charging ? charge[index] : discharge[index]
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
    if (parsed.available === true) {
      var value = Number(parsed.percentage)
      if (!isFinite(value) || value < 0 || value > 100) return
      parsed.percentage = value
    }
    battery = parsed
  }

  Process {
    id: probe
    command: ["python3", root.helperPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function(text) { root.apply(text) }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (opened) root.refresh()

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph()
    labelText: root.available && !button.vertical ? Commons.I18n.formatNumber(root.percentage) + "%" : ""
    slotSize: Style.bar.iconSlot * (root.available && !button.vertical ? 2 : 1)
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
            text: root.available ? Commons.I18n.formatNumber(root.percentage) + "%" : "—"
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
            width: root.available ? Math.max(track.height, track.width * root.percentage / 100) : 0

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
            text: "2.4 GHz USB receiver"
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
