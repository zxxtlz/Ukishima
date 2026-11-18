pragma Singleton
import QtQuick
import Quickshell

/**
 * Manual-palette hue math — the exact wallcolors.py `--hue` computation,
 * rendered locally in QML so a manual palette never has to touch the shared
 * `colors.json` file. The wallpaper palette (`Dyn`) stays the source for
 * dynamic modes on both the pill and the dock; a manual hue is a per-side
 * overlay computed here from that side's own hue flags. Dragging any theme
 * slider therefore recolours only the side that owns it — no shared-file
 * rewrite, no cross-side coupling.
 *
 * `build(hueDeg, sat, dark)` mirrors `tint()`/`lerp()`, the DARK/LIGHT step
 * tables and the text contrast floor in wallcolors.py and returns the same keys
 * Dyn exposes (surface ramp, primary pair, outline, text tiers), so consumers
 * swap a `Dyn.x` branch for a `PaletteHue.build(...).x` branch with the same
 * shape. The contrast helpers below are a direct port of the Python ones, so a
 * manual palette is exactly as legible as the wallpaper one.
 */
Singleton {
    id: root

    function tintHex(h, s, l) {
        var c = Qt.hsla(h, s, l, 1);
        function hx(x) { return ("0" + Math.round(x * 255).toString(16)).slice(-2); }
        return "#" + hx(c.r) + hx(c.g) + hx(c.b);
    }

    function lerp(x, x0, x1, y0, y1) {
        var t = Math.max(0, Math.min(1, (x - x0) / (x1 - x0)));
        return y0 + t * (y1 - y0);
    }

    function rgbOf(hex) {
        var h = String(hex).replace("#", "");
        return [parseInt(h.slice(0, 2), 16) / 255,
                parseInt(h.slice(2, 4), 16) / 255,
                parseInt(h.slice(4, 6), 16) / 255];
    }

    function toHex(r, g, b) {
        function hx(x) { return ("0" + Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16)).slice(-2); }
        return "#" + hx(r) + hx(g) + hx(b);
    }

    function lumOf(hex) {
        var c = root.rgbOf(hex);
        var lin = [];
        for (var i = 0; i < 3; i++)
            lin[i] = c[i] <= 0.03928 ? c[i] / 12.92 : Math.pow((c[i] + 0.055) / 1.055, 2.4);
        return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
    }

    function contrastOf(a, b) {
        var l1 = root.lumOf(a), l2 = root.lumOf(b);
        var lo = Math.min(l1, l2), hi = Math.max(l1, l2);
        return (hi + 0.05) / (lo + 0.05);
    }

    /**
     * Nudge a tinted tier until it clears `ratio` against `bg`, keeping its hue
     * and saturation. Mirrors wallcolors.py `ensure_contrast`: both directions
     * are tried and the one that reaches the ratio — or gets closest when the
     * background is mid-tone and no colour can — wins, so a mid-tone background
     * never sends the search the wrong way.
     */
    function ensureContrast(h, s, l, bg, ratio) {
        var hex = root.tintHex(h, s, l);
        if (root.contrastOf(hex, bg) >= ratio)
            return hex;
        var best = hex, bestC = root.contrastOf(hex, bg);
        var targets = [1.0, 0.0];
        for (var t = 0; t < targets.length; t++) {
            var target = targets[t];
            var lo, hi;
            if (target > l) { lo = l; hi = target; }
            else { lo = target; hi = l; }
            for (var i = 0; i < 30; i++) {
                var mid = (lo + hi) / 2;
                if (root.contrastOf(root.tintHex(h, s, mid), bg) >= ratio) {
                    if (target > l) hi = mid; else lo = mid;
                } else {
                    if (target > l) lo = mid; else hi = mid;
                }
            }
            var cand = root.tintHex(h, s, target > l ? hi : lo);
            var c = root.contrastOf(cand, bg);
            if (c > bestC) { bestC = c; best = cand; }
        }
        return best;
    }

    function build(hueDeg, sat, dark) {
        var hue = (((Math.round(hueDeg) % 360) + 360) % 360) / 360;
        sat = Math.max(0, Math.min(1, sat));
        var light = !dark;
        var ch = sat > 0.02;
        var ml = light ? 0.85 : 0.12;
        var ss = light ? Math.min(sat, 0.26)
            : Math.min(Math.max(sat, ch ? 0.30 : 0.0), 0.45);
        var as = ch ? (light ? Math.min(sat + 0.18, 0.85)
            : Math.min(Math.max(sat, 0.30) + 0.12, 0.82)) : 0.05;
        var base = light ? lerp(ml, 0.40, 0.66, 0.80, 0.93)
            : lerp(ml, 0.0, 0.40, 0.045, 0.20);
        var st = light ? [0.0, -0.045, -0.075, -0.115, -0.160, -0.340]
            : [0.0, 0.022, 0.038, 0.065, 0.100, 0.225];
        function T(s2, l2) { return root.tintHex(hue, s2, l2); }
        var pal = {
            surface: T(ss, base + st[0]),
            surface_container_low: T(ss, base + st[1]),
            surface_container: T(ss, base + st[2]),
            surface_container_high: T(ss, base + st[3]),
            surface_container_highest: T(ss, base + st[4]),
            outline_variant: T(ss, base + st[5]),
            primary: T(as, light ? 0.42 : 0.70),
            primary_container: T(Math.min(as + 0.08, 0.9), light ? 0.30 : 0.34),
            on_primary_container: T(Math.min(as, 0.45), light ? 0.55 : 0.86),
            outline: T(ss, base + (light ? -0.35 : 0.35))
        };
        // Text tiers, then the same contrast floor wallcolors.py applies against
        // the extreme surface, so a manual palette stays as legible as the
        // wallpaper one instead of blending the date/sub-copy into the body.
        var ref = pal.surface_container_highest;
        function TX(s2, l2, floor) { return root.ensureContrast(hue, s2, l2, ref, floor); }
        pal.cream = TX(light ? 0.18 : 0.05, light ? 0.20 : 0.90, 7.0);
        pal.bright = TX(light ? 0.20 : 0.03, light ? 0.10 : 0.97, 9.0);
        pal.subtle = TX(light ? 0.14 : 0.07, light ? 0.36 : 0.73, 4.5);
        pal.dim = TX(light ? 0.10 : 0.06, light ? 0.48 : 0.54, 4.5);
        pal.faint = TX(light ? 0.08 : 0.05, light ? 0.56 : 0.44, 3.0);
        pal.icon_dim = TX(light ? 0.12 : 0.07, light ? 0.28 : 0.81, 4.5);
        pal.tick_rest = TX(light ? 0.12 : 0.08, light ? 0.34 : 0.75, 3.5);
        return pal;
    }
}
