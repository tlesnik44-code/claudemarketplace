# Mobile Platform — UX Guidelines

Rules specific to native mobile applications (iOS, Android). Apply these **in addition to** the universal principles in SKILL.md.

## Platform Conventions

### iOS (Apple Human Interface Guidelines)
- Navigation bar at top with back button (chevron, left side)
- Tab bar at bottom for 3–5 primary destinations
- Swipe-from-left-edge to go back
- Large title style for primary screens, inline title for detail screens
- SF Pro (system font) — don't override unless brand requires it
- Haptic feedback for significant actions
- Pull-to-refresh for lists and feeds
- Use sheets (half/full) instead of new screens for secondary flows
- Destructive actions in red, always with confirmation
- Respect Dynamic Type (user font size preferences)
- Respect Safe Area insets (notch, home indicator, status bar)

### Android (Material Design)
- Top app bar with navigation icon (back arrow or hamburger)
- Bottom navigation bar for 3–5 primary destinations
- FAB (Floating Action Button) for the single most important action
- Material You theming — adapt to user's wallpaper colors (Android 12+)
- Roboto (system font) unless brand requires otherwise
- Navigation drawer for 5+ destinations
- Snackbar for undoable actions, dialog for confirmations
- Respect edge-to-edge display and system bar insets

## Touch Design

- **Minimum touch target: 44x44pt (iOS) / 48x48dp (Android)**
- Adequate spacing between targets (at least 8px gap)
- Thumb-friendly zones: most-used actions in bottom 2/3 of screen
- Reachability: critical actions within one-handed reach
- No hover states — everything must work with tap alone
- Long press for secondary actions (always discoverable through another path too)

## Gesture Support

- **Swipe**: natural for lists (delete, archive), cards (dismiss), navigation (back)
- **Pull to refresh**: standard for feeds and lists
- **Pinch to zoom**: images and maps only, not text
- **Long press**: secondary actions, previews, context menus
- All gestures must have visible button alternatives
- Provide visual affordances (peek edges, dots, handles)

## Navigation Patterns

| Items | Pattern |
|-------|---------|
| 2–5 primary destinations | Bottom tab bar |
| 5+ destinations | Tab bar (top 4–5) + "More" tab, or navigation drawer |
| Hierarchical content | Push navigation (stack) |
| Peer content | Swipeable tabs or segmented control |
| Modal flows | Sheet or full-screen modal with close/cancel |
| Settings/profile | Accessible from tab bar or gear icon |

## Typography

- Body text minimum **14px** (iOS points / Android sp)
- Support Dynamic Type (iOS) and font scaling (Android)
- Test at largest and smallest system font sizes
- Title sizes: 17–34pt range for iOS, 20–28sp for Android

## Layout

- Single column is the default — avoid side-by-side layouts on phones
- Cards for grouping related content
- Lists with clear dividers for scannable content
- Edge-to-edge design: content spans full width, respecting safe areas
- Pull-down or bottom sheet for filters and options
- On tablets: consider split view (master-detail) in landscape

## Forms on Mobile

- Use appropriate keyboard types: email, number, phone, URL
- Auto-advance to next field where possible
- Show/hide password toggle
- Date/time: use native pickers, never text input
- Minimize typing — use pickers, toggles, and segmented controls
- Sticky submit button at bottom (above keyboard when keyboard is visible)
- Dismiss keyboard on tap outside

## Loading & Feedback

- Skeleton screens for content loading
- Pull-to-refresh indicator for manual refresh
- Haptic feedback for confirmations (iOS Taptic, Android vibration)
- Activity indicator in navigation bar for background operations
- Toast/snackbar for quick success messages (auto-dismiss 3–4s)
- Never block the entire screen with a modal spinner

## Offline & Connectivity

- Show offline state clearly but non-intrusively (banner, not modal)
- Cache content for offline reading where possible
- Queue actions for sync when connection returns
- Show sync status (last updated timestamp)
- Degrade gracefully — don't crash or show blank screens

## Mobile Anti-Patterns

- Tiny touch targets (< 44pt)
- Placing critical actions at the top of screen (out of thumb reach)
- Desktop-style hover menus or tooltips
- Requiring pinch to zoom on text content
- Custom gesture-only interactions without button alternatives
- Full-screen loading spinners that block interaction
- Not respecting safe area insets (content under notch/home bar)
- Ignoring system font size preferences
- Deep navigation hierarchies (more than 3–4 levels)
- Alert dialogs for non-critical information

## Mobile Self-Check

In addition to the universal self-check:
- [ ] All touch targets ≥ 44pt (iOS) / 48dp (Android)
- [ ] Critical actions in thumb-friendly zone (bottom 2/3)
- [ ] Native keyboard types for all input fields
- [ ] Safe area insets respected (notch, home indicator)
- [ ] Pull-to-refresh on scrollable lists
- [ ] Gestures have button alternatives
- [ ] Works at largest and smallest system font sizes
- [ ] Offline state handled gracefully
- [ ] Platform navigation patterns followed (tab bar, push nav)
