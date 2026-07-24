# AgriConnect — App Theme & Color System

A minimalist, green-forward theme built for a freshness-aware agricultural marketplace connecting farmers, buyers, and truck drivers.

## Brand

| Token | Hex | Usage |
|---|---|---|
| Primary | `#228B22` | Core brand green — main buttons, active states, key brand moments |
| On Primary | `#FFFFFF` | Text/icons placed on top of Primary |
| Primary Container | `#228B22` | Containers/cards carrying primary emphasis |
| On Primary Container | `#1A2E1A` | Text/icons on Primary Container |
| Secondary | `#D2B48C` | Warm tan — earthy accent, secondary actions |
| On Secondary | `#FFFFFF` | Text/icons on Secondary |
| Secondary Container | `#D2B48C` | Containers carrying secondary emphasis |
| On Secondary Container | `#1A2E1A` | Text/icons on Secondary Container |
| Accent | `#E67E22` | Orange accent — highlights, callouts, CTAs that need to pop |
| On Accent | `#FFFFFF` | Text/icons on Accent |
| Accent Container | `#E67E22` | Containers carrying accent emphasis |
| On Accent Container | `#1A2E1A` | Text/icons on Accent Container |

## Surfaces & Content

| Token | Hex | Usage |
|---|---|---|
| Background | `#F4F7F2` | App background (default/selected) |
| On Background | `#1A2E1A` | Text/icons on Background |
| Secondary Background | `#E8EFE4` | Alternate/subtle background layer |
| Surface | `#FFFFFF` | Cards, sheets, elevated surfaces |
| On Surface | `#1A2E1A` | Text/icons on Surface |
| Surface Variant | `#F0F4EF` | Muted surface variant |
| On Surface Variant | `#5D6B5D` | Text/icons on Surface Variant |
| Primary Text | `#1A2E1A` | Main body/heading text color |
| Secondary Text | `#5D6B5D` | De-emphasized text |
| Hint | `#A0ACA0` | Placeholder / hint text |
| Outline | `#D1DED1` | Borders, dividers on components |
| Divider | `#E2E8E2` | Hairline separators |

## Status Colors

| Token | Hex | Usage |
|---|---|---|
| Success | `#2E7D32` | Confirmed transactions, positive freshness scans |
| On Success | `#FFFFFF` | Text/icons on Success |
| Warning | `#F9A825` | Freshness degrading, action needed soon |
| On Warning | `#FFFFFF` | Text/icons on Warning |
| Error | `#C62828` | Failed payment, expired/rejected produce |
| On Error | `#FFFFFF` | Text/icons on Error |
| Info | `#0277BD` | Informational banners, dispatch/SMS notices |
| On Info | `#FFFFFF` | Text/icons on Info |

## Utility

| Token | Hex | Usage |
|---|---|---|
| Transparent | `#000000` (alpha 0) | No-fill / overlay base |
| Full Contrast | `#000000` | Maximum contrast text/icons where needed |

## Design Notes

- **Palette logic:** Green (Primary) signals freshness and agriculture; tan (Secondary) evokes soil/harvest; orange (Accent) draws attention to time-sensitive actions — fitting for a freshness-scanning marketplace.
- **Light, airy surfaces:** Background and Surface tones stay near-white/soft-green, keeping the UI feeling clean and minimal rather than heavy or saturated.
- **Status colors** map directly to marketplace events: Success for completed escrow/payment, Warning for produce nearing spoilage, Error for failed transactions, Info for dispatch/SMS notifications.
- Consistent with the minimalist, green + white direction and floating icon-only tab bar planned for the Flutter build.
