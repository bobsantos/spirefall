# Mobile Sizing Details

## Current Constants (UIManager.gd)
| Constant | Value | Physical dp (at 0.375) | Meets 48dp? |
|---|---|---|---|
| MOBILE_BUTTON_MIN | 64x64 | 24x24 | NO |
| MOBILE_TOWER_BUTTON_MIN | 150x100 | 56x37.5 | Width yes, height NO |
| MOBILE_ACTION_BUTTON_MIN_HEIGHT | 56 | 21 | NO |
| MOBILE_START_WAVE_MIN | 160x64 | 60x24 | Width yes, height NO |
| MOBILE_TOPBAR_HEIGHT | 72 | 27 | NO |
| MOBILE_BUILD_MENU_HEIGHT | 140 | 52.5 | Barely OK as container |
| MOBILE_FONT_SIZE_BODY | 16 | 6 | Marginal |
| MOBILE_FONT_SIZE_LABEL | 14 | 5.25 | Too small |
| MOBILE_FONT_SIZE_TITLE | 24 | 9 | Marginal |

## Recommended Minimums (128px = 48dp)
- Buttons: 128px height minimum
- Top bar: 128px height minimum (or restructure to two rows)
- Font body: 32px minimum (12dp)
- Font label: 28px minimum (10.5dp)
- Grid cells during placement: auto-zoom to 2x so 64px = 48dp

## Components with _apply_mobile_sizing()
- HUD.gd: top bar height, button sizes, font sizes
- BuildMenu.gd: panel height, button sizes, font sizes, element dots, thumbnails
- TowerInfoPanel.gd: button heights, font sizes, panel width, close button
- WavePreviewPanel.gd: font sizes only (no position/size changes)
- PauseMenu.gd: button sizes, font sizes, panel padding
- GameOverScreen.gd: (not examined in detail)
- CodexPanel.gd: (not examined in detail)
- DraftPickPanel.gd: (not examined in detail)
- ModeSelect.gd: card sizing

## Components WITHOUT mobile adjustments
- WavePreviewPanel position (stuck in top-right)
- Floating gold text (16px fixed)
- Damage numbers (via DamageNumberManager autoload)
- Grid cell visual size
- Camera zoom defaults
