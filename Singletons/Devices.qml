pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Single owner of screen vibrance (nvibrant) and external-monitor brightness
 * (ddcutil) for the mixer. The persisted vibrance percent is the source of
 * truth: loaded and re-applied once at startup so the tint survives a reboot,
 * and every later set both pushes to nvibrant and writes back the state file.
 * nvibrant takes one value per GPU port, so the connected ports are probed
 * once and the value is written only to those, rather than assuming ports 0-2.
 * DDC monitors come from `ddcutil detect` (one brightness fader each); the
 * setvcp/getvcp wire format lives here so every caller speaks it the same.
 * The internal laptop backlight (eDP, no DDC/CI) is driven separately via
 * brightnessctl and gated on /sys/class/backlight being present, so a desktop
 * exposes nothing.
 */
Singleton {
    id: root

    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ukishima/nvibrant-value"

    property int vibrance: 40

    /**
     * Physical output indexes reported by `nvibrant` that have a connected
     * display. nvibrant takes one value per GPU port in order, so the index of
     * the active monitor matters: writing `nvibrant 409 0 409` only touches
     * ports 0 and 2. We probe the ports once (no args lists every port and
     * marks connected ones "Success") and reuse that map for every later set.
     */
    property var vibPorts: []
    property bool vibPortsKnown: false
    property int pendingVibranceRaw: -1

    /**
     * DDC-capable monitors from `ddcutil detect`: [{ bus, label }] with label
     * taken from the DRM connector, falling back to the I2C bus number.
     */
    property var ddcMonitors: []

    /** True once an internal backlight has been found under /sys/class/backlight. */
    property bool backlightPresent: false

    /** Current internal-backlight level, 0..100. */
    property int backlightPct: 75

    /**
     * Loads the persisted vibrance percent and applies it once, so the saved
     * tint is restored on boot. Singletons init lazily, so a startup caller
     * must reference this for the restore to fire.
     */
    function restore() {
        var raw = vibState.text();
        var v = parseInt((raw || "40").trim());
        root.vibrance = isNaN(v) ? 40 : v;
        if (raw && raw.trim().length)
            applyVibrance(root.vibrance);
    }

    /**
     * Sets the screen vibrance to `pct` percent: pushes it to nvibrant and
     * persists it to the state file. `vibrance` mirrors the last set value.
     */
    function setVibrance(pct) {
        root.vibrance = Math.round(pct);
        applyVibrance(pct);
        saveVibrance(pct);
    }

    function applyVibrance(pct) {
        var raw = Math.round(Math.max(0, Math.min(100, pct)) * 1023 / 100);
        if (!root.vibPortsKnown) {
            root.pendingVibranceRaw = raw;
            return;
        }
        writeVibrance(raw);
    }

    /**
     * Applies an nvibrant raw value (-1024..1023) to every connected port and
     * zeroes the empty ports in between, as nvibrant requires positional args.
     */
    function writeVibrance(raw) {
        if (!root.vibPorts.length)
            return;
        var args = ["nvibrant"];
        var maxPort = Math.max.apply(null, root.vibPorts);
        for (var i = 0; i <= maxPort; i++)
            args.push(root.vibPorts.indexOf(i) >= 0 ? String(raw) : "0");
        Quickshell.execDetached(args);
    }

    function saveVibrance(pct) {
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" && printf "%s\n" "$2" > "$1"',
            "_", root.stateFile, String(Math.round(pct))]);
    }

    /**
     * Probes for brightness controls when the mixer opens. DDC (external-monitor)
     * detection only runs when more than one monitor is connected AND ddcutil is
     * installed — on a single-monitor machine ddcutil is never invoked, avoiding
     * redundant/duplicate faders for the one panel. The internal backlight is
     * probed regardless.
     */
    function detect() {
        var count = Quickshell.screens.length;
        if (count > 1) {
            ddcDetect.running = true;
        } else {
            ddcDetect.running = false;
            root.ddcMonitors = [];
        }
        blDetect.running = true;
    }

    function setBrightness(bus, pct) {
        Quickshell.execDetached(["timeout", "3", "ddcutil", "setvcp", "10",
            String(pct), "--bus", bus, "--noverify"]);
    }

    /**
     * Sets the internal laptop backlight to `pct` percent via brightnessctl.
     * No-op effect on machines without /sys/class/backlight (brightnessctl
     * simply finds no device), and inert when brightnessctl is absent.
     */
    function setBacklight(pct) {
        root.backlightPct = Math.round(Math.max(1, Math.min(100, pct)));
        Quickshell.execDetached(["brightnessctl", "set", root.backlightPct + "%"]);
    }

    /**
     * Parses a `ddcutil getvcp --brief` line, returning the current brightness
     * percent or -1 when no value is present.
     */
    function parseBrightness(text) {
        var m = text.match(/C\s+(\d+)\s+/);
        return m ? parseInt(m[1], 10) : -1;
    }

    /**
     * Discovers which physical GPU outputs have a display attached. Running
     * bare `nvibrant` clears vibrance on every port, so this happens once on
     * startup and the pending set is replayed as soon as the map is known.
     * Kicked off from onCompleted (not from applyVibrance) so a restore that
     * races the singleton's construction only has to queue its value.
     */
    Component.onCompleted: vibProbe.running = true

    Process {
        id: vibProbe
        command: ["nvibrant"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var ports = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var m = /\((\d+),[^)]*\)[^•]*•[^•]*•\s*Success/.exec(lines[i]);
                    if (m)
                        ports.push(parseInt(m[1], 10));
                }
                ports.sort((a, b) => a - b);
                root.vibPorts = ports;
                root.vibPortsKnown = true;
                if (root.pendingVibranceRaw >= 0) {
                    var raw = root.pendingVibranceRaw;
                    root.pendingVibranceRaw = -1;
                    root.writeVibrance(raw);
                }
            }
        }
    }

    Process {
        id: ddcDetect
        command: ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 || exit 0; ddcutil detect --brief"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var mons = [];
                var blocks = this.text.split(/\bDisplay \d+/);
                for (var i = 0; i < blocks.length; i++) {
                    var bus = /I2C bus:\s+\/dev\/i2c-(\d+)/.exec(blocks[i]);
                    var conn = /DRM connector:\s+card\d+-(\S+)/.exec(blocks[i]);
                    if (!bus)
                        continue;
                    var name = conn ? conn[1] : "BUS " + bus[1];
                    if (/^eDP/i.test(name))
                        continue;
                    mons.push({ bus: bus[1], label: name });
                }
                root.ddcMonitors = mons;
            }
        }
    }

    Process {
        id: blDetect
        command: ["sh", "-c", "dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); [ -n \"$dev\" ] || exit 0; max=$(cat /sys/class/backlight/$dev/max_brightness); cur=$(cat /sys/class/backlight/$dev/brightness); echo \"$(( cur * 100 / max ))\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim(), 10);
                if (!isNaN(v)) {
                    root.backlightPct = Math.max(1, Math.min(100, v));
                    root.backlightPresent = true;
                }
            }
        }
    }

    FileView {
        id: vibState
        path: root.stateFile
        blockLoading: true
        printErrors: false
    }
}
