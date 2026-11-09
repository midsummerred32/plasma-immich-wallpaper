import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: page

    property var configDialog
    property var wallpaperConfiguration
    property var parentLayout

    property string cfg_ServerUrl
    property string cfg_ServerUrlDefault
    property string cfg_ApiKey
    property string cfg_ApiKeyDefault
    property var cfg_SelectedAlbums: []
    property var cfg_SelectedAlbumsDefault: []
    property int cfg_Interval
    property int cfg_IntervalDefault
    property bool cfg_Shuffle
    property bool cfg_ShuffleDefault
    property int cfg_FillMode
    property int cfg_FillModeDefault
    property int cfg_Quality
    property int cfg_QualityDefault

    property string statusText: ""

    ListModel { id: albumList }

    function isSelected(id) {
        for (var i = 0; i < cfg_SelectedAlbums.length; ++i) {
            if (cfg_SelectedAlbums[i] === id) return true
        }
        return false
    }

    function setSelected(id, on) {
        var list = []
        for (var i = 0; i < cfg_SelectedAlbums.length; ++i) {
            if (cfg_SelectedAlbums[i] !== id) list.push(cfg_SelectedAlbums[i])
        }
        if (on) list.push(id)
        cfg_SelectedAlbums = list
    }

    function selectAll(on) {
        var list = []
        if (on) {
            for (var i = 0; i < albumList.count; ++i) list.push(albumList.get(i).albumId)
        }
        cfg_SelectedAlbums = list
    }

    function loadAlbums() {
        albumList.clear()
        var base = (cfg_ServerUrl || "").replace(/\/+$/, "")
        if (!base || !cfg_ApiKey) {
            statusText = "Enter your Immich server URL and API key."
            return
        }
        statusText = "Loading…"
        var xhr = new XMLHttpRequest()
        xhr.open("GET", base + "/api/albums")
        xhr.setRequestHeader("x-api-key", cfg_ApiKey)
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                var data = []
                try { data = JSON.parse(xhr.responseText) } catch (e) {}
                data.sort(function (a, b) { return a.albumName.localeCompare(b.albumName) })
                for (var i = 0; i < data.length; ++i) {
                    albumList.append({
                        albumId: data[i].id,
                        albumName: data[i].albumName,
                        assetCount: data[i].assetCount
                    })
                }
                statusText = data.length + " albums found"
            } else if (xhr.status === 0) {
                statusText = "Could not reach the server (check the URL; self-signed HTTPS certificates won't work)."
            } else if (xhr.status === 401) {
                statusText = "The API key was rejected (401)."
            } else if (xhr.status === 403) {
                statusText = "The API key lacks permission (403). It needs album and asset read permissions."
            } else {
                statusText = "Server returned HTTP " + xhr.status
            }
        }
        xhr.send()
    }

    Timer {
        interval: 400
        running: true
        onTriggered: if (page.cfg_ServerUrl && page.cfg_ApiKey) page.loadAlbums()
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true

        QQC2.TextField {
            Kirigami.FormData.label: "Immich server URL:"
            Layout.fillWidth: true
            placeholderText: "http://192.168.1.10:2283"
            text: page.cfg_ServerUrl
            onTextEdited: page.cfg_ServerUrl = text
        }

        QQC2.TextField {
            Kirigami.FormData.label: "API key:"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            text: page.cfg_ApiKey
            onTextEdited: page.cfg_ApiKey = text
        }

        RowLayout {
            QQC2.Button {
                text: "Load albums"
                icon.name: "view-refresh"
                onClicked: page.loadAlbums()
            }
            QQC2.Label {
                text: page.statusText
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                opacity: 0.8
            }
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: "Change picture every (minutes):"
            from: 1
            to: 1440
            value: page.cfg_Interval
            onValueModified: page.cfg_Interval = value
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "Order:"
            text: "Shuffle"
            checked: page.cfg_Shuffle
            onToggled: page.cfg_Shuffle = checked
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Positioning:"
            model: ["Crop to fill", "Fit (letterbox)", "Stretch"]
            currentIndex: page.cfg_FillMode
            onActivated: page.cfg_FillMode = currentIndex
        }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Image quality:"
            model: ["Preview (fast; size set in Immich settings)", "Full size (larger downloads)"]
            currentIndex: page.cfg_Quality
            onActivated: page.cfg_Quality = currentIndex
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Kirigami.Heading {
            level: 3
            text: "Albums"
            Layout.fillWidth: true
        }
        QQC2.Button { text: "Select all"; onClicked: page.selectAll(true) }
        QQC2.Button { text: "None"; onClicked: page.selectAll(false) }
    }

    QQC2.Frame {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 14
        padding: 0

        ListView {
            anchors.fill: parent
            clip: true
            model: albumList
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            delegate: QQC2.CheckDelegate {
                required property string albumId
                required property string albumName
                required property int assetCount
                width: ListView.view.width
                text: albumName + "  (" + assetCount + ")"
                checked: page.isSelected(albumId)
                onToggled: page.setSelected(albumId, checked)
            }

            QQC2.Label {
                anchors.centerIn: parent
                visible: albumList.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No albums loaded yet.\nEnter your server and key, then click “Load albums”."
            }
        }
    }
}
