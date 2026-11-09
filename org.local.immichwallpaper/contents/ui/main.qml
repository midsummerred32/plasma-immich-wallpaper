import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

WallpaperItem {
    id: root

    contextualActions: [
        PlasmaCore.Action {
            text: "Previous Photo"
            icon.name: "media-skip-backward"
            onTriggered: {
                root.previous()
                slideTimer.restart()
            }
        },
        PlasmaCore.Action {
            text: "Next Photo"
            icon.name: "media-skip-forward"
            onTriggered: {
                root.advance()
                slideTimer.restart()   // restart the countdown after a manual skip
            }
        }
    ]

    // ---- configuration -------------------------------------------------
    readonly property string serverUrl: (configuration.ServerUrl || "").replace(/\/+$/, "")
    readonly property string apiKey: configuration.ApiKey || ""
    readonly property var albumIds: configuration.SelectedAlbums || []
    readonly property bool shuffleEnabled: configuration.Shuffle
    readonly property string sizeParam: configuration.Quality === 1 ? "fullsize" : "preview"

    readonly property int qtFillMode: {
        switch (configuration.FillMode) {
        case 1: return Image.PreserveAspectFit
        case 2: return Image.Stretch
        default: return Image.PreserveAspectCrop
        }
    }

    // ---- state ---------------------------------------------------------
    property var images: []          // asset ids
    property int cursor: -1
    property string currentId: ""
    property bool showTop: false
    property string statusText: ""
    property int refreshToken: 0
    property int showTicket: 0
    property int failCount: 0

    onServerUrlChanged: refreshTimer.restart()
    onApiKeyChanged: refreshTimer.restart()
    onAlbumIdsChanged: refreshTimer.restart()
    onShuffleEnabledChanged: refreshTimer.restart()
    Component.onCompleted: refreshTimer.restart()

    // ---- Immich API ------------------------------------------------------
    function getJson(path, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", serverUrl + path)
        xhr.setRequestHeader("x-api-key", apiKey)
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try { cb(null, JSON.parse(xhr.responseText)) }
                catch (e) { cb("Bad response from server", null) }
            } else {
                cb(xhr.status === 0 ? "Cannot reach server" : "HTTP " + xhr.status, null)
            }
        }
        xhr.send()
    }

    function postJson(path, body, cb) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", serverUrl + path)
        xhr.setRequestHeader("x-api-key", apiKey)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200 || xhr.status === 201) {
                try { cb(null, JSON.parse(xhr.responseText)) }
                catch (e) { cb("Bad response from server", null) }
            } else {
                cb(xhr.status === 0 ? "Cannot reach server" : "HTTP " + xhr.status, null)
            }
        }
        xhr.send(JSON.stringify(body))
    }

    property var debugLog: []
    function dbg(s) { var d = debugLog.slice(); d.push(s); debugLog = d }

    // Newer Immich versions no longer return assets from GET /albums/{id},
    // so list an album's photos through the metadata search (paged), with
    // fallbacks for odd server versions.
    function searchAssets(albumId, withType, page, token, collected, done) {
        var body = { albumIds: [albumId], size: 1000, page: page }
        if (withType) body.type = "IMAGE"
        postJson("/api/search/metadata", body, function (err, data) {
            if (token !== refreshToken) return
            if (err) { dbg("search: " + err); done(err); return }
            var block = data.assets || {}
            var items = block.items || []
            if (items.length === 0 && page === 1) {
                dbg("search" + (withType ? " (IMAGE)" : "") + ": 0 items, reply=" + JSON.stringify(data).substring(0, 160))
            }
            for (var k = 0; k < items.length; ++k) {
                var a = items[k]
                if (withType || !a.type || a.type === "IMAGE") collected.push(a.id)
            }
            var next = block.nextPage ? parseInt(block.nextPage) : 0
            if (next > page && next < 200) {
                searchAssets(albumId, withType, next, token, collected, done)
            } else {
                done("")
            }
        })
    }

    function loadAlbumAssets(albumId, token, collected, done) {
        searchAssets(albumId, true, 1, token, collected, function (err) {
            if (err || collected.length > 0) { done(err); return }
            searchAssets(albumId, false, 1, token, collected, function (err2) {
                if (err2 || collected.length > 0) { done(err2); return }
                getJson("/api/albums/" + albumId, function (err3, data) {
                    if (token !== refreshToken) return
                    if (err3) { dbg("album endpoint: " + err3); done(err3); return }
                    var assets = data.assets || []
                    dbg("album endpoint: " + assets.length + " assets")
                    for (var k = 0; k < assets.length; ++k) {
                        if (!assets[k].type || assets[k].type === "IMAGE") collected.push(assets[k].id)
                    }
                    done("")
                })
            })
        })
    }

    // ---- album list handling ----------------------------------------------
    function shuffleArray(a) {
        for (var i = a.length - 1; i > 0; --i) {
            var j = Math.floor(Math.random() * (i + 1))
            var t = a[i]; a[i] = a[j]; a[j] = t
        }
    }

    function refresh() {
        var token = ++refreshToken
        if (!serverUrl || !apiKey) {
            images = []; statusText = "Set your Immich server and API key in the wallpaper settings."
            return
        }
        if (albumIds.length === 0) {
            images = []; statusText = "No albums selected.\nRight-click the desktop → Configure Desktop and Wallpaper."
            return
        }
        statusText = "Loading albums…"
        debugLog = []
        var pending = albumIds.length
        var seen = {}
        var ordered = []
        var lastError = ""
        for (var i = 0; i < albumIds.length; ++i) {
            (function (albumId) {
                var collected = []
                loadAlbumAssets(albumId, token, collected, function (err) {
                    if (token !== refreshToken) return
                    if (err) lastError = err
                    for (var k = 0; k < collected.length; ++k) {
                        if (!seen[collected[k]]) {
                            seen[collected[k]] = true
                            ordered.push(collected[k])
                        }
                    }
                    if (--pending === 0) finishRefresh(ordered, lastError)
                })
            })(albumIds[i])
        }
    }

    function finishRefresh(list, err) {
        if (list.length === 0) {
            images = []
            statusText = (err ? ("Immich error: " + err) : "No photos found in the selected albums.") + (debugLog.length > 0 ? "\n" + debugLog.join(" | ") : "")
            return
        }
        statusText = "Found " + list.length + " photos, loading…"
        if (shuffleEnabled) shuffleArray(list)
        images = list
        var idx = list.indexOf(currentId)
        if (idx < 0) {
            cursor = -1
            advance()
        } else {
            cursor = idx
        }
    }

    function advance() {
        if (images.length === 0) return
        cursor = (cursor + 1) % images.length
        show(images[cursor])
    }

    function previous() {
        if (images.length === 0) return
        cursor = (cursor - 1 + images.length) % images.length
        show(images[cursor])
    }

    property string pendingSize: "preview"

    function imageUrl(assetId, size) {
        return serverUrl + "/api/assets/" + assetId + "/thumbnail?size=" + size
               + "&apiKey=" + encodeURIComponent(apiKey)
    }

    function show(assetId, sizeOverride) {
        currentId = assetId
        pendingSize = sizeOverride || sizeParam
        var uri = imageUrl(assetId, pendingSize)
        // Bottom layer is always opaque; the top layer fades in/out over it.
        var target = showTop ? imgBottom : imgTop
        if (target.source.toString() === uri) {
            showTop = (target === imgTop)
            return
        }
        target.reveal = true
        target.source = uri
    }

    function imageFailed() {
        if (pendingSize === "fullsize") {      // older servers: fall back to preview
            show(currentId, "preview")
            return
        }
        statusText = "Found " + images.length + " photos but could not load them from\n"
                     + serverUrl + "\nCheck that the API key allows reading/viewing assets."
        if (++failCount < 5) advance()
    }

    Timer {
        id: refreshTimer
        interval: 600
        onTriggered: root.refresh()
    }

    // pick up newly added photos
    Timer {
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        id: slideTimer
        interval: Math.max(1, configuration.Interval) * 60 * 1000
        repeat: true
        running: root.images.length > 1
        onTriggered: root.advance()
    }

    // ---- rendering -------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "#1b1b1b"
    }

    Image {
        id: imgBottom
        property bool reveal: false
        anchors.fill: parent
        asynchronous: true
        cache: false
        autoTransform: true
        fillMode: root.qtFillMode
        sourceSize.width: Math.max(root.width, root.height) * Screen.devicePixelRatio
        onStatusChanged: {
            if (status === Image.Ready && reveal) {
                reveal = false
                root.failCount = 0
                root.statusText = ""
                root.showTop = false
            } else if (status === Image.Error && reveal) {
                reveal = false
                root.imageFailed()
            }
        }
    }

    Image {
        id: imgTop
        property bool reveal: false
        anchors.fill: parent
        asynchronous: true
        cache: false
        autoTransform: true
        fillMode: root.qtFillMode
        sourceSize.width: Math.max(root.width, root.height) * Screen.devicePixelRatio
        opacity: root.showTop ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
        onStatusChanged: {
            if (status === Image.Ready && reveal) {
                reveal = false
                root.failCount = 0
                root.statusText = ""
                root.showTop = true
            } else if (status === Image.Error && reveal) {
                reveal = false
                root.imageFailed()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.statusText !== "" && imgTop.status !== Image.Ready && imgBottom.status !== Image.Ready
        color: "#aaaaaa"
        font.pointSize: 14
        text: root.statusText
        width: parent.width * 0.8
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
