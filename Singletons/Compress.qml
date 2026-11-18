pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live progress of a running compress10mb job. The compressor keeps
 * ~/.cache/compress10mb/status.json fresh (a daemon thread touches it once a
 * second), and this singleton hands that state to the pill: a determinate bar,
 * the file being worked on and a percentage.
 *
 * The file is rewritten by rename, which can outlive a QFileSystemWatcher, so a
 * slow poll runs alongside `watchChanges`. `active` is derived, not read
 * directly: a job killed with SIGKILL never gets to publish its final state, and
 * the `updated` heartbeat is what lets the badge disappear instead of sticking
 * around forever.
 */
Singleton {
    id: root

    readonly property bool running: adapter.active
    readonly property bool ok: adapter.ok
    readonly property real percent: Math.max(0, Math.min(100, adapter.percent))
    readonly property string label: adapter.label
    readonly property string phase: adapter.phase
    readonly property int index: adapter.index
    readonly property int total: adapter.total
    readonly property real updated: adapter.updated

    /** Wall clock in seconds, refreshed once a second for the staleness check. */
    property real now: Date.now() / 1000
    readonly property bool active: running && (now - updated) < 10

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = Date.now() / 1000
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/compress10mb/status.json"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool active: false
            property bool ok: false
            property real percent: 0
            property string label: ""
            property string phase: ""
            property int index: 0
            property int total: 0
            property real updated: 0
        }
    }

    /** The rename that publishes each update defeats the inotify watch, so poll. */
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: file.reload()
    }
}
