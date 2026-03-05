# UX Reference — Extended Guidelines

Deep dives on universal UX topics. Consult this file for detailed guidance beyond the core principles in SKILL.md. For platform-specific rules, see [web](web.md), [desktop](desktop.md), [mobile](mobile.md), [mixed](mixed-platforms.md), or [maui](maui.md).

## Gestalt Principles in UI

These perceptual principles explain how users visually group and interpret elements:

- **Proximity**: Elements close together are perceived as related. Use spacing to create logical groups without needing borders or dividers
- **Similarity**: Elements that look alike (same color, shape, size) are perceived as related. Use consistent styling for same-type actions
- **Continuity**: The eye follows smooth paths. Align elements along clear lines and axes
- **Closure**: The brain completes incomplete shapes. You don't need full borders — partial boundaries or shadows work
- **Figure-Ground**: Users distinguish foreground from background. Use contrast, elevation (shadows), and overlays to establish layers
- **Common Region**: Elements within the same bounded area are perceived as grouped. Cards and containers leverage this

## Information Architecture

### Content Organization
- Use card sorting results or logical grouping to organize navigation
- Apply the **3-click rule** as a guideline: users should reach any content within 3 interactions
- Use progressive disclosure: show summary first, details on demand
- Breadcrumbs for hierarchies deeper than 2 levels
- Provide multiple paths to the same content (navigation + search + links)

## Interaction Design

### Micro-interactions
- Confirm actions with subtle animations (checkmark, color change)
- Animate transitions between states (expand/collapse, show/hide) — 200–300ms duration
- Use easing curves, not linear timing (ease-out for entrances, ease-in for exits)
- Don't animate purely for decoration — every animation should communicate something

### Drag & Drop
- Show clear drop targets with visual highlighting
- Provide visual feedback during drag (shadow, opacity change, grab cursor)
- Support keyboard alternatives (select + arrow keys or move menu)
- Show ghost/placeholder where item will land
- Allow cancel (Escape key)

## Typography Deep Dive

### Type Scale (Recommended)
```
12px  — Caption, fine print
14px  — Secondary text, metadata, labels
16px  — Body text (base)
18px  — Large body, intro text
20px  — H4, sub-headings
24px  — H3, section headings
32px  — H2, page section titles
40px  — H1, page titles
48px+ — Display, hero text
```

### Font Pairing Rules
- Pair a serif heading font with a sans-serif body font (or vice versa)
- Never pair two fonts that are too similar — contrast is the point
- When no brand font is specified, use the platform's system font for native feel

### Readability
- Paragraph spacing: at least 1.5x line height
- Don't justify body text on screens — use left-align
- Constrain line length (65 characters is ideal)
- Avoid ALL CAPS for more than a few words (hard to read, feels like shouting)

## Color System Design

### Building a Palette
1. Choose a **primary** color (brand identity, main actions)
2. Choose a **neutral** scale (10 shades from near-white to near-black)
3. Add **semantic** colors: error (red), success (green), warning (amber), info (blue)
4. Optionally add 1–2 **accent** colors for secondary CTAs or highlights
5. Each color should have 5–10 shades for flexibility (50, 100, 200... 900)

### Color Usage Patterns
- Primary: main CTAs, active navigation, key highlights
- Neutral-900/800: primary text
- Neutral-600/500: secondary text, icons
- Neutral-200/100: borders, dividers
- Neutral-50: subtle backgrounds
- White: card/surface backgrounds
- Semantic colors: only for status communication, not decoration

## Form Design Deep Dive

### Field Types — When to Use What
- **Text input**: free-form text, short answers
- **Textarea**: multi-line text (comments, descriptions)
- **Select/Dropdown**: 5–15 predefined options
- **Radio buttons**: 2–5 mutually exclusive options (always visible)
- **Checkboxes**: multiple selections from a small set
- **Toggle/Switch**: binary on/off with immediate effect (no submit needed)
- **Date picker**: date selection (never make users type dates in specific format)
- **Autocomplete/Combobox**: large lists (countries, cities, users)
- **File upload**: drag-and-drop zone + click-to-browse, show preview

### Validation Timing
| Scenario | When to validate |
|----------|-----------------|
| Required field empty | On submit only |
| Format error (email, phone) | On blur (after leaving field) |
| Character limits | Real-time counter |
| Password strength | Real-time meter |
| Username availability | On blur with debounce |
| Complex business rules | On submit |

### Error Message Writing
- Bad: "Invalid input" / "Error" / "Field required"
- Good: "Enter an email address (e.g., name@example.com)"
- Good: "Password must be at least 8 characters with one number"
- Good: "This username is already taken. Try adding numbers or try: [suggestion]"

## Loading & Empty States

### Loading Patterns
| Duration | Pattern |
|----------|---------|
| < 500ms | No indicator needed |
| 500ms – 2s | Spinner or subtle animation |
| 2s – 10s | Skeleton screen with shimmer |
| 10s+ | Progress bar with percentage or steps |
| Unknown long | Progress bar + estimated time + cancel option |

### Skeleton Screen Rules
- Match the layout of actual content
- Use neutral gray blocks/lines where content will appear
- Add shimmer/pulse animation to indicate loading (not static gray)
- Load content progressively — replace skeletons as data arrives

### Empty State Templates
Every empty state needs:
1. **Visual** — illustration or icon (not just blank space)
2. **Message** — explain why it's empty in friendly language
3. **Action** — give the user a next step

Examples:
- "No projects yet. Create your first project to get started." [+ Create Project]
- "No results found for 'xyz'. Try a different search or [clear filters]."
- "You're all caught up! No new notifications."

## Notification & Feedback Patterns

### Types
| Type | Use for | Auto-dismiss | Position |
|------|---------|-------------|----------|
| Toast/Snackbar | Success confirmations, non-critical info | Yes (4–6s) | Bottom or top |
| Banner | System-wide status, maintenance, warnings | No | Top of page |
| Inline alert | Contextual warnings/info near content | No | Within content |
| Modal/Dialog | Critical actions requiring decision | No | Center overlay |
| Badge/Dot | Unread counts, new items | No | On icons/tabs |

### Writing Notification Copy
- Be specific: "Document saved" not "Operation successful"
- Include context: "3 files uploaded to Project X"
- For errors, include recovery: "Upload failed. Check your connection and try again."
- Keep it brief: 1–2 sentences maximum

## Sources & Further Reading

- [Nielsen's 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
- [WCAG 2.2 Guidelines](https://www.w3.org/TR/WCAG22/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Material Design 3](https://m3.material.io/)
- [Spacing, Grids, and Layouts](https://www.designsystems.com/space-grids-and-layouts/)
- [NNGroup Error Reporting in Forms](https://www.nngroup.com/articles/errors-forms-design-guidelines/)
