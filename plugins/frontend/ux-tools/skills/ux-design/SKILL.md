---
name: ux-design
description: >
  Enforce professional UX/UI design quality in any frontend project.
  Use when creating new pages, views, layouts, forms, or multi-component interfaces.
  Also use when reviewing or redesigning existing UI for usability issues.
  NOT needed for trivial edits (one-line CSS fixes, typo corrections, color tweaks).
  Ensures output follows established UX principles, accessibility standards, and visual design best practices.
  Defer to project-specific or aesthetic-focused skills (e.g., frontend-design) when creative direction is set.
user-invocable: true
---

# UX Design Best Practices — Universal Principles

Apply these principles whenever generating or modifying UI code, regardless of platform. Treat violations as bugs.

For platform-specific guidance, consult the relevant reference:
- [Web](references/web.md) — HTML/CSS/JS, SPAs, responsive sites
- [Desktop](references/desktop.md) — Native desktop apps (Windows, macOS, Linux)
- [Mobile](references/mobile.md) — Native mobile apps (iOS, Android)
- [Mixed Platforms](references/mixed-platforms.md) — Designing one app for desktop + mobile together
- [.NET MAUI](references/maui.md) — .NET MAUI apps targeting Mac Catalyst, iOS, Android, Windows
- [Extended Reference](references/ux-reference.md) — Deep dives on typography, color systems, form design, loading patterns

---

## Core Heuristics (Nielsen)

Every UI must satisfy these. Verify each one before considering work complete:

1. **Visibility of system status** — Show users what's happening. Loading states, progress indicators, active/selected states, save confirmations. Never leave the user guessing.
2. **Match real-world language** — Use words users know, not developer jargon. "Remove" not "Delete record", "Save" not "Persist".
3. **User control & freedom** — Always provide undo, back, cancel, close. Never trap users in flows.
4. **Consistency** — Same action = same appearance everywhere. Follow platform conventions.
5. **Error prevention** — Disable invalid actions, use confirmations for destructive ones, constrain inputs (date pickers, dropdowns).
6. **Recognition over recall** — Show options, show recent items, use labels not just icons, provide placeholder text.
7. **Flexibility** — Support keyboard shortcuts, allow customization, cater to both novice and expert users.
8. **Minimalist design** — Every element must earn its place. Remove anything that doesn't directly help the user complete their task.
9. **Error recovery** — Errors in plain language, explain what went wrong, tell users exactly how to fix it.
10. **Help & documentation** — Contextual help, tooltips, onboarding hints when complexity is unavoidable.

## Visual Design Rules

### Layout & Spacing
- Use an **8px grid system** — all spacing, padding, margins in multiples of 8 (8, 16, 24, 32, 40, 48...)
- **Internal spacing <= external spacing** — padding inside a card must be less than or equal to the gap between cards
- Group related items with proximity; separate unrelated items with whitespace
- Maintain consistent alignment — left-align text by default, avoid centered body text
- Whitespace is a design element, not wasted space. Use it generously

### Typography
- Maximum **2 typefaces** per project (1 is often enough)
- Establish a clear **type scale** — use consistent, proportional sizes
- Use **font weight and size** for hierarchy, not just color
- Left-align body text. Center-align only headings or very short text
- Line height: **1.4–1.6x** font size for body text
- Constrain line length for readability (roughly 45–75 characters)

### Color
- Define a **limited palette**: 1 primary, 1 secondary, 1 accent, plus neutrals
- Use color consistently — same color = same meaning throughout
- Never rely on color alone to convey information (accessibility)
- Reserve **red for errors**, **green/blue for success**, **amber/yellow for warnings**
- Ensure the UI works in both light and dark contexts if dark mode is supported

### Visual Hierarchy
- Size, weight, color, spacing, and position all communicate importance
- Primary action buttons must be visually dominant (filled, high contrast)
- Secondary actions should be visually subordinate (outlined, ghost, muted)
- Destructive actions: use warning color + confirmation step, never make them the default/primary action
- One clear focal point per screen/section. If everything is bold, nothing is bold

## Component Patterns

### Buttons
- Clear label that describes the action: "Save changes", "Send message", not "Submit" or "OK"
- Visual hierarchy: Primary (filled) > Secondary (outlined) > Tertiary (text/link)
- Show loading state when action is async (spinner or text change)
- Disable after click to prevent double-submission where appropriate

### Forms
- One column layout — do not place unrelated fields side by side
- Labels always visible (not placeholder-only)
- Mark required fields (asterisk or explicit "required" label)
- Group related fields with headings
- Show inline errors next to the offending field, not just at the top
- Error messages: say what's wrong + how to fix it ("Email must include @")
- Show success state after valid submission
- Minimize fields — remove any that aren't strictly necessary

### Navigation
- Make current location obvious (active state, breadcrumbs)
- Use descriptive labels, not clever names
- Keep primary navigation to **5–7 items** maximum
- Ensure keyboard/shortcut navigability

### Feedback & States
Every interactive element needs ALL of these states:
- **Default** — resting state
- **Hover** — cursor over (desktop) or highlight (touch)
- **Focus** — keyboard/accessibility focus (visible indicator, never invisible)
- **Active/Pressed** — being clicked/tapped
- **Disabled** — not available (reduced opacity + no interaction)
- **Loading** — async action in progress (spinner, skeleton, progress bar)
- **Empty** — no data yet. NEVER show a blank screen. Show illustration + message + action
- **Error** — something failed. Explain why, offer recovery action

### Tables & Lists
- Align text left, numbers right
- Zebra striping or divider lines for scanability
- Sticky headers on scroll for long lists
- Provide sorting/filtering for 10+ items
- Pagination or virtual scroll for 50+ items
- Show count of total items

### Modals & Dialogs
- Use sparingly — only for actions requiring attention or confirmation
- Always include a close/cancel option
- Trap focus inside the modal/dialog while open
- Close on Escape key press (or platform equivalent)
- Dim/blur background to indicate context switch
- Keep content concise — if it needs scrolling, it probably shouldn't be a modal

## Accessibility (Universal)

These are **requirements**, not nice-to-haves:

- All images: meaningful alt text or marked decorative
- All form inputs: associated labels
- Use semantic/structured UI elements, not generic containers for everything
- Full keyboard/assistive navigation: every interactive element reachable and operable
- Visible focus indicators on all interactive elements
- Animations: respect user motion preferences (prefers-reduced-motion / platform equivalent)
- Text resizable without breaking layout
- **Contrast ratios** (WCAG AA minimum):
  - Normal text: **4.5:1** against background
  - Large text (18px+ bold or 24px+): **3:1**
  - UI components and icons: **3:1**

## Dark Mode

- Don't just invert colors — redesign the palette
- Use dark grays, not pure black, as the base
- Reduce saturation of colors on dark backgrounds
- Elevate surfaces with lighter grays, not shadows
- Test contrast ratios in both themes
- Treat dark mode as a first-class experience, not an afterthought

## Performance as UX

- Show content within **1 second** or show a loading indicator
- Use skeleton screens instead of spinners for content loading
- Lazy load below-the-fold/off-screen content
- Avoid layout shifts — reserve space for dynamic content

## Anti-Patterns (Never Do These)

- Placeholder text as the only label
- Auto-playing video/audio
- Mystery meat navigation (icons without labels)
- Tiny click/tap targets
- Content behind unnecessary modals
- Infinite scroll without "back to top" and position memory
- Low-contrast text on background
- Hiding essential actions in overflow menus

## Self-Check

Before delivering any UI work, verify:

- [ ] Every interactive element has all required states (hover, focus, active, disabled, loading, error)
- [ ] Color contrast meets WCAG AA minimums
- [ ] All forms have visible labels, inline validation, and helpful error messages
- [ ] Empty states and loading states are handled — no blank screens
- [ ] Layout uses consistent spacing (8px grid)
- [ ] Typography has clear hierarchy with no more than 2 fonts
- [ ] Navigation is keyboard/shortcut accessible
- [ ] Destructive actions require confirmation
- [ ] The user always knows where they are and what's happening
- [ ] Dark mode works correctly (if supported)
- [ ] Platform-specific checklist items from the relevant reference file are satisfied
