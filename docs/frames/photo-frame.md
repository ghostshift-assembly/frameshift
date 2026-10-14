# Photo Frame — Matte IPS Reference

**Status:** independent prototype path; exact panel/controller unselected

The BOE MV270QHM-N40 preliminary P1 panel is the default manufacturer geometry
candidate for the [networked simulator](../architecture/container-frame-simulator.md).
Its controller match and procurement revision remain unqualified, so the donor
monitor and raw-panel prototype paths stay open.

## Purpose

Photo is the high-detail emissive medium: a large matte surface for photography
and generated art. It aims to look like framed art through restrained brightness,
matting, calibration, and thin mechanics, not by pretending an LCD is passive.

## Physical target

A 27-inch 16:9 QHD panel has roughly A2-like wall presence but not ISO A2
proportions. Passe-partout/frame design owns the aspect-ratio difference.

Requirements:

- matte/anti-glare IPS-class surface and wide viewing angle;
- no touch layer, speakers, camera, or smart-TV platform;
- QHD-class resolution preferred;
- exact active area, outline, panel depth, edge electronics, FPC, and backlight
  path documented;
- complete electronics distributed within the frame/rebate;
- removable backing and safe ventilation without a central computer box.

The BOE MV270QHM-N40 is geometry/interface evidence, not yet a purchase choice:
2560×1440, 596.736×335.664 mm active, approximately
608.8×355.3 mm nominal outline, a 9.3 mm typical body depth, matte/low-reflection,
LVDS, and separate backlight control. The front drawing marks 9.3±0.5 mm body
depth and a 12.8±0.5 mm protruding region; the rear drawing also marks 14.9 mm
regions. These are regional dimensions, not interchangeable complete installed
depths. The mechanical section names MV270FHM-N40 while the drawing title names
MV270QHM-N40; retain that document-scope conflict pending authoritative confirmation.
Figure 5 gives +1/−0.6 mm outline tolerances on both axes, yielding candidate
drawing bounds of 608.2–609.8 × 354.7–356.3 mm. The
[dimension record](../../data/illustrations/boe-mv270qhm-n40-p1/dimensions.json)
retains exact page/feature locators, basis and unresolved installed dimensions.
Source: [mirrored preliminary panel specification](https://www.panelook.com/upload/202311/MV270QHM-N40_Rev.P1_20190125_202311014949.pdf).

Wood geometry is calculated from the selected display, protection glass,
passe-partout, support and complete electronics/connection envelopes. Minimize
the complete installed thickness under the
[physical constraint contract](../architecture/physical-build-contract.md).
Glass, mat, retention, tolerances and service margins are explicit inputs;
missing controller, backlight-driver or connector dimensions cannot become a
guessed rear pocket. Regional protrusions, mating cables and the mounting gap
must appear in the result. An illustrative timber thickness is never a product
requirement or a proved minimum.

## Prototype options

### Donor-monitor mule

Choose a currently available matte QHD monitor with an external certified
supply. Record exact monitor and internal panel revisions before de-casing.
Retain the original controller, supply, shielding, and button board for the first
electrical test. Measure depth, hot spots, power, glare, and sleep behavior
before designing custom mechanics.

This is an expedient prototype, not permission to assume every unit under one
retail model contains the same panel.

### Raw-panel mule

Buy an exact panel only with a controller explicitly documented for that panel
revision, LVDS/eDP lane mapping, timing, voltage, connector, and backlight. Bench
test through a current-limited setup before mounting.

## Controller direction

The controller needs Wi-Fi/security/storage plus a way to hold and continuously
scan one still framebuffer into the exact panel timing controller. It does not
need desktop applications, video decoding, or a Linux development board.

MCU-class MIPI display parts such as ESP32-P4 show that thin high-resolution
controllers are plausible, but do not yet prove 2560×1440 LVDS/eDP compatibility.
An exact controller remains the primary technical blocker. Project-owned
firmware tooling is selected with the exact controller; vendor firmware can be
a qualified opaque component when its update and security behavior are documented.

## Power and cable design

The display and backlight require continuous power while visible. Zero visible
cable is a high-priority mount/industrial-design goal, not a promise of passive
operation. Prototype with the certified external supply. Later options include
a cable routed behind the frame, a low-voltage wall plate, or a powered mounting
contact, subject to safety and local installation rules.

Art rotation is a local framebuffer swap on a user-selected interval. A longer
artwork dwell has no demonstrated power saving while the backlight stays on;
brightness and scheduled off periods carry the energy policy. The candidate
advertises no energy-based dwell suggestion. See
[display timing](../architecture/display-timing.md).

Do not place exposed mains conversion in a wooden frame. Provide brightness and
scheduled-off settings, but maintain the current still and restore it after
power returns.

## Artifact and behavior

- One still artifact at exact negotiated dimensions and color profile.
- No video signal semantics in Frame Protocol, even if a controller internally
  scans HDMI/LVDS timing.
- Host applies crop, scale, color transform, and output sharpening.
- Frame boots directly to last verified art without exposing desktop UI, cursor,
  vendor logo, or progress screen.
- Network/control failure never intentionally blanks the current framebuffer.

## Required prototype evidence

- cold boot to retained art and power-loss recovery;
- idle/on/scheduled-off power at multiple brightness settings;
- steady-state temperature inside the actual backing/frame materials;
- luminance, black level, glare, uniformity, and viewing-angle observations;
- complete depth map including power/video connector bends;
- 24-hour still test for image retention or controller overlays;
- exact controller/panel compatibility record and replacement availability;
- no visible OS cursor, boot console, OSD, or motion behavior.
