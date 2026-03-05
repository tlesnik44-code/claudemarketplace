# Mixed Platforms — Designing for Desktop + Mobile Together

Guidelines for apps that target both desktop and mobile (native or cross-platform). Apply these **in addition to** the universal principles in SKILL.md and the relevant platform-specific references.

## Core Philosophy

Design **one coherent experience** that adapts to each platform, not a desktop app squeezed onto mobile or a mobile app stretched to desktop. Users expect platform-native behavior on each device.

## Shared vs. Divergent Patterns

### Keep Consistent Across Platforms
- **Information architecture** — same content hierarchy, same terminology
- **Color palette and brand** — identical colors, icons, and visual identity
- **Core workflows** — the same task should follow the same conceptual steps
- **Data model** — same data, same sync, same state
- **Terminology and labels** — "Save", "Projects", "Settings" mean the same thing everywhere

### Adapt Per Platform
- **Navigation structure** — sidebar on desktop, tab bar on mobile
- **Input methods** — keyboard shortcuts on desktop, gestures on mobile
- **Information density** — more visible at once on desktop, progressive disclosure on mobile
- **Touch targets** — 32px on desktop, 44px+ on mobile
- **Interaction patterns** — right-click on desktop, long-press on mobile
- **Typography scale** — slightly larger base on mobile for readability at close distance
- **Dialogs** — sheets/popovers on mobile, modal dialogs on desktop

## Layout Strategy

### Desktop (≥ 1024px)
- Sidebar + content + optional detail panel (3-column)
- Toolbars and menu bars for actions
- Persistent navigation visible at all times
- Dense tables, data grids, split views
- Drag and drop between panels

### Tablet (768–1024px)
- Collapsible sidebar + content (2-column)
- Toolbar actions may move to overflow menu
- Master-detail in landscape, stack in portrait
- Touch-friendly targets but desktop-like density

### Phone (< 768px)
- Single column, full-width
- Bottom tab bar for primary navigation
- Stack everything vertically
- Sheets and bottom drawers for secondary content
- Large touch targets, generous spacing

## Navigation Mapping

| Desktop | Mobile Equivalent |
|---------|------------------|
| Sidebar with sections | Bottom tab bar (top 4–5 items) |
| Top menu bar | Hamburger or navigation drawer |
| Right-click context menu | Long-press menu or swipe actions |
| Toolbar buttons | Top-right action buttons or FAB |
| Breadcrumbs | Back button / navigation stack |
| Hover tooltips | Long-press preview or info button |
| Keyboard shortcut | No direct equivalent (maybe gesture) |
| Drag and drop | Long-press + drag, or move-to menu |
| Multi-select with Ctrl/Cmd+click | Edit mode with checkboxes |

## Input Adaptation

### Text Input
- Desktop: standard text fields, Tab to advance
- Mobile: keyboard type hints (email, number, url), auto-advance, dismiss keyboard on tap outside

### Selection
- Desktop: dropdown/select, multi-select with Shift/Ctrl+click
- Mobile: picker wheels (iOS), bottom sheet selection list, checkboxes for multi-select

### Actions
- Desktop: right-click context menus, keyboard shortcuts, toolbar buttons
- Mobile: swipe actions on list items, bottom action sheets, FAB

## Sync & State

- Real-time or near-real-time sync between devices
- Show last-synced timestamp
- Handle conflicts gracefully (last-write-wins with undo, or merge UI)
- Offline support on mobile is critical; desktop can be more lenient
- Same account, same data, seamless transition between devices

## Feature Parity Decisions

Not every feature needs to exist on every platform. Decide intentionally:

| Approach | When to Use |
|----------|-------------|
| **Full parity** | Core features that define the product |
| **Desktop-only** | Bulk operations, complex editing, admin features |
| **Mobile-only** | Camera input, location-based features, quick capture |
| **Adapted** | Same feature, different UI (desktop table → mobile cards) |

Document feature parity decisions — don't leave them implicit.

## Design Process

1. **Start with the core user flow** — platform-agnostic
2. **Design desktop and mobile in parallel** — not one then the other
3. **Share a design system** — same tokens (colors, spacing, type scale), different components
4. **Test on real devices** — simulators miss touch feel, screen glare, one-handed use
5. **Don't design for "responsive" like web** — native apps need platform-specific navigation and interaction patterns, not just reflowing columns

## Mixed Platform Anti-Patterns

- Identical UI on desktop and mobile (ignoring platform conventions)
- Desktop-first design that's "adapted" for mobile as an afterthought
- Different terminology or IA between platforms
- Features that only work on one platform without clear reason
- Hover-dependent interactions with no mobile alternative
- Desktop-density layouts squeezed onto mobile screens
- Mobile-style hamburger menus on desktop (use a sidebar)
- Ignoring platform keyboard shortcuts on desktop because "mobile doesn't have them"

## Mixed Platform Self-Check

In addition to the universal and platform-specific self-checks:
- [ ] Same IA and terminology across platforms
- [ ] Navigation adapts to platform (sidebar on desktop, tab bar on mobile)
- [ ] Touch targets are platform-appropriate (32px desktop, 44px+ mobile)
- [ ] Input methods adapted (keyboard shortcuts on desktop, gestures on mobile)
- [ ] Feature parity decisions are documented and intentional
- [ ] Tested on actual devices, not just simulators/resizing windows
- [ ] Data syncs correctly between platforms
- [ ] No hover-only interactions without mobile alternative
