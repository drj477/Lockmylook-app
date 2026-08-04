# LockMyLook — Design System (v0.1)

Reference: mockup showing 8 screens (Onboarding, Home, Wardrobe, Outfit
Suggestion, Outfit Calendar, AI Try-On, Profile). This doc extracts the
tokens and component patterns so the Flutter build can implement them
consistently without re-deriving them from the image each time.

---

## 1. Color Palette

| Token | Hex | Usage |
|---|---|---|
| `color.primary` | `#FF8E8E` | Primary buttons (Sign Up), active nav icon, section headers, highlight backgrounds, "today" marker |
| `color.primaryLight` | `#FFB6B6` | Gradient/background washes, card accents, secondary badges |
| `color.dark` | `#1E1A3A` | Primary CTA button (Log In), headings, bottom-nav active background circle, text on light backgrounds |
| `color.surface` | `#FFFFFF` | Card backgrounds, sheet backgrounds, input fields |
| `color.background` | `#F7F5F3` *(inferred, warm off-white)* | Screen background behind cards |
| `color.textPrimary` | `#1E1A3A` | Headings, primary body text |
| `color.textSecondary` | `#8A8894` *(inferred, mid-gray)* | Captions, labels, timestamps, placeholder text |
| `color.border` | `#EFEAE8` *(inferred, light neutral)* | Card borders, dividers, input borders |
| `color.favorite` | `#FF6B6B` *(inferred, slightly deeper coral)* | Heart/favorite icon when active |
| `color.success` | `#4CAF50` *(inferred — not in mockup, standard choice)* | Match-percentage badge, success states |

**Note on inferred values:** the mockup only specifies four swatches
(`#FFB6B6`, `#FF8E8E`, `#1E1A3A`, `#FFFFFF`). Background, text-secondary,
border, and semantic colors aren't shown at hex precision — the values
above are reasonable extrapolations in the same warm/neutral family, but
should be confirmed against the actual Figma/design file before locking
them the way the four core colors are locked.

### Gradient
Onboarding screen uses a diagonal wash from `primary` → `primaryLight` →
`background`, with a large soft blob shape in `dark` as a background
accent behind the profile illustration.

---

## 2. Typography

Mockup uses a clean geometric/rounded sans-serif (reads similarly to
**Poppins** or **Inter**) — confirm exact family with design source, but
Poppins is a safe default for this rounded, friendly aesthetic and has
good Flutter/Google Fonts support.

| Token | Size | Weight | Usage |
|---|---|---|---|
| `type.h1` | 28sp | Bold (700) | Brand wordmark ("WardrobeAI"), screen-level hero text |
| `type.h2` | 20sp | SemiBold (600) | Section titles ("My Wardrobe", "Outfit Suggestion") |
| `type.h3` | 16sp | SemiBold (600) | Card titles ("Office Look", item names) |
| `type.body` | 14sp | Regular (400) | Body copy, list items |
| `type.caption` | 12sp | Regular (400) | Sub-labels ("Formal", "Casual"), timestamps |
| `type.button` | 15sp | SemiBold (600) | Button labels |

---

## 3. Spacing Scale

8px base grid, consistent with the card/icon rhythm visible across screens.

| Token | Value |
|---|---|
| `space.xs` | 4px |
| `space.sm` | 8px |
| `space.md` | 16px |
| `space.lg` | 24px |
| `space.xl` | 32px |
| `screen.padding` | 20px horizontal margin, consistent across all screens |

---

## 4. Radius & Elevation

| Token | Value | Usage |
|---|---|---|
| `radius.sm` | 8px | Small chips, tags |
| `radius.md` | 12px | Item thumbnails within cards |
| `radius.lg` | 16px | Cards (wardrobe items, outfit cards, calendar entries) |
| `radius.pill` | 999px | Primary/secondary buttons, filter tabs, calendar date circles |
| `elevation.card` | soft shadow, ~4% opacity, 8px blur, 2px y-offset | All elevated cards |

---

## 5. Components

### 5.1 Buttons
- **Primary (dark):** `color.dark` background, white text, `radius.pill`, full-width on auth screens. Used for the single most important action ("Log In", "Try On This Outfit").
- **Secondary (coral):** `color.primary` background, white text, `radius.pill`. Used for the alternative action ("Sign Up", "View Outfit").
- **Icon-only social buttons:** white circle, `color.border` outline, centered icon (Google, Apple, Email) — used in a row on Onboarding.
- **Small action button:** `color.primary` background, white icon, circular, floating in bottom-nav (the center "+" button on Home/Wardrobe/Outfits).

### 5.2 Cards
- **Wardrobe item card:** white surface, `radius.lg`, item image top (rounded top corners), name + category label below, heart-favorite icon top-right corner overlay.
- **Outfit suggestion card:** larger white card, header row (title + match-percentage pill badge in `color.success`-tinted background), garment images arranged horizontally, "Items in this outfit" list below with thumbnail + name + tag, primary CTA button at the bottom.
- **Calendar day entry card:** white card per planned day, small thumbnail row of the day's outfit pieces, time label top-right.

### 5.3 Navigation
- **Bottom nav bar:** 4–5 items (Home, Wardrobe, [+ floating action], Outfits, Profile), active item shown in `color.primary` with icon+label; center action is a raised circular coral button breaking the bar line.
- **Top header:** back-chevron (when nested) + screen title, optional trailing icon (filter, notification bell, settings gear).

### 5.4 Avatars / Family Members
- Circular avatar, `color.primaryLight` ring/background for the "Add" placeholder, name label centered beneath each. Horizontal scrollable row on Home ("Family Wardrobe").

### 5.5 Badges
- **Match-percentage badge:** pill shape, light green background, dark green text, e.g. "92% Match".
- **Notification-count badge:** small coral circle with white number, top-right of an icon (e.g. Family Members "4").
- **Category tag:** plain caption-weight gray text under an item name (e.g. "Formal", "Casual", "Accessories") — not a filled chip.

### 5.6 Filter Tabs
Horizontal scrollable pill row under a header (All / Tops / Bottoms /
Shoes / Accessories on Wardrobe screen) — active pill filled `color.primary`
with white text, inactive pills white/outline with `color.textSecondary`.

### 5.7 Calendar
Month header with chevron navigation, 7-column day grid, selected day
shown as a filled `color.primary` circle, day-of-week labels in
`type.caption`.

### 5.8 AI Try-On Strip
Full-bleed model photo, horizontal thumbnail strip of swappable garment
options below (selected one gets a coral border), two-button footer
("Change Clothes" secondary outline / "Save Look" primary coral).

---

## 6. Screen Inventory (from mockup)

1. **Onboarding / Auth** — logo, tagline, Log In (dark) + Sign Up (coral) buttons, social login row, T&C footer
2. **Home** — greeting header, search bar, "Today's Recommendation" hero card, Quick Actions grid (4 icons), Family Wardrobe avatar row, bottom nav
3. **My Wardrobe** — filter tabs, 2-column item grid, favorite hearts, bottom nav
4. **Outfit Suggestion** — match badge, garment layout, itemized list, "Try On This Outfit" CTA
5. **Outfit Calendar** — month grid, per-day planned outfit cards
6. **AI Try-On** — full-body model preview, swappable garment strip, Change/Save footer
7. **Profile / Account** — avatar + name + membership badge, settings list (My Profile, Family Members w/ count badge, Preferences, Subscription, Help & Support, Logout)

---

## 7. Open Items Before Flutter Implementation

- [ ] Confirm exact font family (currently assuming Poppins/Inter-style geometric sans)
- [ ] Confirm background/neutral/semantic hex values — only 4 colors were given precisely
- [ ] Confirm icon set (currently reads as a rounded line-icon family, e.g. Phosphor or Feather style)
- [ ] Get spacing/radius values from the actual design file if available (Figma), rather than the visual estimates above
