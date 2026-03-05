# Desktop Platform — UX Guidelines

Rules specific to native desktop applications (macOS, Windows, Linux). Apply these **in addition to** the universal principles in SKILL.md.

## Platform Conventions

Follow the host OS conventions — users expect desktop apps to behave like other apps on their system:

### macOS
- Menu bar at the top of the screen (not in the window)
- Cmd+, for Settings/Preferences
- Cmd+Q to quit, Cmd+W to close window
- Traffic light buttons (close/minimize/maximize) top-left
- Use SF Pro or system font for native feel
- Sheets and popovers instead of modal dialogs where possible
- Sidebar navigation is the dominant pattern
- Accent colors follow System Preferences

### Windows
- Title bar with minimize/maximize/close top-right
- Alt key activates menu bar, F10 for menu focus
- Ctrl+, or File → Settings for preferences
- Use Segoe UI or system font
- Ribbon or command bar for complex apps
- Settings page pattern (full page, not modal)

### Linux
- Follows GTK or Qt conventions depending on desktop environment
- Use system font and theme colors
- Respect system dark/light theme

## Window Management

- Remember window size and position across sessions
- Support standard resize behavior — set sensible minimum window dimensions
- Content should reflow gracefully when window is resized
- Support full-screen/maximize properly
- Multi-monitor: remember which monitor the window was on

## Keyboard-First Design

Desktop users expect comprehensive keyboard support:

- **Every action** should be reachable by keyboard
- Standard shortcuts: Cmd/Ctrl+S (save), Cmd/Ctrl+Z (undo), Cmd/Ctrl+Shift+Z (redo), Cmd/Ctrl+F (find), Cmd/Ctrl+N (new), Cmd/Ctrl+O (open)
- Show keyboard shortcuts in menu items and tooltips
- Support Tab/Shift+Tab for field navigation
- Arrow keys for list/tree navigation
- Escape to dismiss popups, cancel actions, deselect
- Enter/Return to confirm the primary action
- Space to toggle checkboxes, activate buttons

## Mouse Interactions

- Right-click context menus for common actions on items
- Double-click for primary action on list/tree items (open, edit)
- Drag and drop with visual feedback (cursor change, drop zone highlight, ghost preview)
- Hover tooltips for icons and truncated text (with ~500ms delay)
- Scroll: smooth scrolling, horizontal scroll with Shift+scroll wheel

## Typography

- Use platform system fonts for native feel
- Body text minimum **13–14px** (desktop screens are viewed at arm's length)
- Monospace for code, file paths, technical content
- Dense UI is acceptable — desktop users expect more information density than mobile

## Layout

- Sidebar + content area is the dominant pattern
- Toolbars for frequently-used actions
- Status bar at the bottom for non-critical information
- Splitter/resize handles between panels
- **Readable width**: constrain content areas to ~640–720px for text-heavy views even on wide screens
- Use available space for data-heavy views (tables, editors, canvases)

## Dialogs & Sheets

- Prefer sheets (attached to parent window) over modal dialogs on macOS
- Confirmation dialogs: primary action on the right (macOS) or left (Windows)
- Alert dialogs: clear title, concise message, action buttons with descriptive labels
- File dialogs: use the native system file picker, not a custom one
- Progress dialogs for long operations: show progress, allow cancel

## Notifications

- Use the system notification center for background/out-of-focus events
- In-app notifications (toast/banner) for in-context feedback
- Badge the dock/taskbar icon for unread counts
- Don't over-notify — respect user attention

## Desktop Anti-Patterns

- Custom title bars that break native window management
- Ignoring platform keyboard shortcuts (Cmd vs Ctrl)
- Web-style hamburger menus in desktop apps
- Missing right-click context menus
- Not remembering window state between sessions
- Requiring mouse for actions that should have keyboard shortcuts
- Custom scrollbars that don't match OS behavior
- Blocking the UI thread during I/O (frozen/unresponsive app)

## Desktop Self-Check

In addition to the universal self-check:
- [ ] Platform keyboard shortcuts work correctly
- [ ] Right-click context menus on interactive items
- [ ] Window position/size remembered across sessions
- [ ] System font and conventions followed
- [ ] Sidebar/content layout with sensible default widths
- [ ] All menu items have keyboard shortcuts shown
- [ ] Drag and drop has proper visual feedback
- [ ] System notification center used (not just in-app)
