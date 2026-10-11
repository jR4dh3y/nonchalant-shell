// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   C O D E X   M A R K                                                    │
// │   openai's codex cloud · traced from the official artwork                │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Shapes

import qs.modules.widgets.desktop.impasto.theme

// The Codex mark (OpenAI's) as an outline, so it can be filled in any colour
// at any size, as `ClaudeMark` is. Traced from the official artwork with
// potrace; the prompt inside is cut out of the cloud (even-odd fill).
//
// Coordinates run 0 to 1 on both axes, y down.
Item {
    id: root

    property color color: Theme.indicator

    implicitWidth: 16
    implicitHeight: 16

    readonly property real side: Math.min(root.width, root.height)

    Shape {
        x: (root.width - root.side) / 2
        y: (root.height - root.side) / 2
        width: root.side
        height: root.side
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color
            fillRule: ShapePath.OddEvenFill
            scale: Qt.size(root.side, root.side)

            PathSvg {
                path: "M0.4078 0.0011 C0.3098 0.0114 0.2245 0.0795 0.1931 0.1727 L0.1878 "
                    + "0.1883 L0.1709 0.1941 C0.0259 0.2439 -0.0417 0.4106 0.0267 0.5489 "
                    + "C0.0352 0.5659 0.0500 0.5884 0.0609 0.6006 C0.0752 0.6167 0.0741 "
                    + "0.6131 0.0703 0.6322 C0.0503 0.7334 0.0944 0.8363 0.1820 0.8936 "
                    + "C0.2081 0.9108 0.2442 0.9250 0.2758 0.9306 C0.2975 0.9345 0.3470 "
                    + "0.9345 0.3648 0.9306 C0.3717 0.9291 0.3792 0.9275 0.3816 0.9270 "
                    + "C0.3850 0.9264 0.3878 0.9281 0.3980 0.9367 C0.4633 0.9927 0.5464 "
                    + "1.0127 0.6278 0.9922 C0.7105 0.9713 0.7725 0.9148 0.8044 0.8314 "
                    + "L0.8117 0.8122 L0.8283 0.8064 C0.9152 0.7758 0.9775 0.7037 0.9956 "
                    + "0.6136 C1.0003 0.5903 1.0006 0.5483 0.9963 0.5227 C0.9888 0.4773 "
                    + "0.9647 0.4284 0.9334 0.3950 C0.9297 0.3909 0.9266 0.3870 0.9266 0.3864 "
                    + "C0.9266 0.3858 0.9281 0.3778 0.9300 0.3688 C0.9350 0.3447 0.9350 "
                    + "0.2972 0.9300 0.2723 C0.9020 0.1327 0.7694 0.0441 0.6284 0.0713 "
                    + "L0.6145 0.0739 L0.5998 0.0617 C0.5445 0.0156 0.4759 -0.0061 0.4078 "
                    + "0.0011 Z M0.2833 0.3300 C0.2959 0.3337 0.3003 0.3402 0.3441 0.4172 "
                    + "C0.3928 0.5028 0.3922 0.5012 0.3869 0.5159 C0.3841 0.5236 0.3039 "
                    + "0.6589 0.2986 0.6647 C0.2833 0.6814 0.2527 0.6770 0.2423 0.6564 "
                    + "C0.2336 0.6391 0.2348 0.6361 0.2767 0.5653 L0.3127 0.5047 L0.2756 "
                    + "0.4398 C0.2444 0.3852 0.2384 0.3737 0.2378 0.3673 C0.2355 0.3422 "
                    + "0.2591 0.3228 0.2833 0.3300 Z M0.7445 0.6092 C0.7738 0.6227 0.7720 "
                    + "0.6636 0.7417 0.6748 C0.7388 0.6759 0.7019 0.6766 0.6308 0.6766 "
                    + "C0.5105 0.6766 0.5170 0.6772 0.5059 0.6641 C0.4936 0.6498 0.4944 "
                    + "0.6305 0.5078 0.6170 C0.5119 0.6130 0.5177 0.6089 0.5205 0.6080 "
                    + "C0.5236 0.6072 0.5687 0.6066 0.6320 0.6064 C0.7319 0.6062 0.7386 "
                    + "0.6066 0.7445 0.6092 Z "
            }
        }
    }
}
