# Web Platform — UX Guidelines

Rules specific to HTML/CSS/JS web applications, SPAs, and responsive websites. Apply these **in addition to** the universal principles in SKILL.md.

## Semantic HTML

- Use `<button>` for actions, `<a>` for navigation — never `<div onclick>`
- Use `<nav>`, `<main>`, `<header>`, `<footer>`, `<section>`, `<article>` — not div-for-everything
- Use `<label>` elements associated with every form input
- ARIA only when semantic HTML isn't sufficient — prefer native elements
- Never use `tabindex` > 0 — it breaks natural tab order
- Add a **skip-to-content** link as the first focusable element

## Focus Management

- Never use `outline: none` without a visible replacement
- Focus indicators must be visible in both light and dark themes
- Manage focus programmatically on route changes in SPAs (move focus to main content or heading)
- Trap focus inside modals while open; restore focus on close

## Responsive Design

- **Mobile-first**: design for smallest screen, then enhance for larger
- Breakpoints: ~480px (mobile), ~768px (tablet), ~1024px (desktop), ~1280px+ (wide)
- Content must be readable without horizontal scrolling at any width
- Collapse navigation into hamburger/bottom sheet on mobile
- Stack columns vertically on narrow screens
- Test at common widths, not just breakpoints

### Common Breakpoint Behaviors
| Pattern | Mobile | Tablet | Desktop |
|---------|--------|--------|---------|
| Navigation | Bottom bar or hamburger | Sidebar collapsed | Full sidebar or top nav |
| Grid | 1 column | 2 columns | 3–4 columns |
| Tables | Card/list view | Scrollable | Full table |
| Forms | Full-width stacked | 2-column groups | Multi-column with sidebar |
| Modals | Full-screen sheet | Centered dialog | Centered dialog |

## Layout

- Use a **12-column grid** for page layouts
- Use `max-width` to constrain line length (`65ch` is ideal for body text)
- **F-pattern** for text-heavy pages: users scan left-to-right then down the left side
- **Z-pattern** for landing pages: eye moves top-left → top-right → diagonal → bottom-left → bottom-right

## Typography

- Body text minimum **16px**
- Use relative units (`rem`, `em`) for font sizes to respect user zoom settings
- System font stacks are fast and familiar when brand fonts aren't required:
  - Sans: `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
  - Mono: `"SF Mono", "Fira Code", "Cascadia Code", Consolas, monospace`
- Paragraph spacing: at least 1.5x line height
- Don't justify body text on screens — use left-align
- Avoid ALL CAPS for more than a few words

## Touch vs. Pointer

- Minimum touch target: **44x44px** on mobile
- Minimum click target: **32x32px** on desktop
- Use `@media (hover: hover)` for hover-only interactions
- Use `@media (pointer: fine/coarse)` to adapt target sizes
- All hover interactions must have touch-friendly alternatives

## Web-Specific Anti-Patterns

- Disabling paste on password/email fields
- Horizontal scroll for primary content
- Using `cursor: pointer` on non-clickable elements or vice versa
- CAPTCHA as first interaction
- Infinite scroll without URL-based position memory
- Layout shifts from late-loading ads/images/fonts

## Performance

- Optimize images (WebP, proper sizing, `srcset` for responsive)
- Lazy load below-the-fold images with `loading="lazy"`
- Minimize Cumulative Layout Shift (CLS) — reserve space for dynamic content
- Text resizable to 200% without breaking layout (WCAG)
- Use CSS containment for complex layouts

## Web Self-Check

In addition to the universal self-check:
- [ ] Semantic HTML used throughout (no div soup)
- [ ] Skip-to-content link present
- [ ] Focus indicators visible and styled
- [ ] Responsive at all breakpoints — no horizontal scroll
- [ ] Touch targets ≥ 44px on mobile
- [ ] Images optimized with alt text
- [ ] No paste-blocking on inputs
