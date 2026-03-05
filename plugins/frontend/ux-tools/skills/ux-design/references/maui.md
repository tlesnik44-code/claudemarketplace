# .NET MAUI — UX Guidelines

Rules specific to .NET MAUI applications. Apply these **in addition to** the universal principles in SKILL.md, [Desktop](desktop.md) for Mac Catalyst/Windows, and [Mobile](mobile.md) for iOS/Android.

## MAUI Platform Overview

.NET MAUI renders native controls on each platform. Your XAML defines the structure, but the visual result differs per platform. Design with this in mind — don't fight the platform.

| Target | Native Toolkit | Conventions |
|--------|---------------|-------------|
| Mac Catalyst | UIKit (via Catalyst) | macOS HIG, menu bar, sidebars |
| iOS | UIKit | iOS HIG, tab bar, navigation bar |
| Android | Material | Material Design, FAB, bottom nav |
| Windows | WinUI 3 | Windows 11 design, command bar |

## Shell Navigation

Shell is the primary navigation container in MAUI. Use it correctly:

- **Flyout** for 5+ top-level destinations or less-frequent navigation
- **TabBar** for 3–5 primary destinations
- **ShellContent** for simple, single-page tabs
- `Shell.TitleView` does NOT work on Mac Catalyst — use `ToolbarItems` instead
- Use `Shell.BackgroundColor` and `Shell.ForegroundColor` for consistent theming
- Register routes with `Routing.RegisterRoute()` for deep navigation
- Pass parameters via query strings, receive with `[QueryProperty]` or `IQueryAttributable`

## Layout Patterns

### Mac Catalyst / Desktop
- Constrain content width for readability: `WidthRequest="640" HorizontalOptions="Start"` on the content VerticalStackLayout
- Apple's readable width is ~672pt — aim for 600–700px content width on text/form pages
- `MaximumWidthRequest` is **BROKEN** on Mac Catalyst/iOS (dotnet/maui#13604) — use `WidthRequest` instead
- Use `Grid` for complex layouts, `VerticalStackLayout`/`HorizontalStackLayout` for simple flows
- Avoid `StackLayout` (legacy) — use `VerticalStackLayout` or `HorizontalStackLayout`

### iOS / Mobile
- Full-width layouts, single column
- Use `ScrollView` wrapping content for long forms
- Respect safe area: `ios:Page.UseSafeArea="True"` or SafeArea-aware layouts
- Bottom-aligned action buttons for thumb reach

### Adaptive Layout
- Use `OnPlatform` and `OnIdiom` for platform/device-specific values
- Example: different padding on Mac vs iOS
```xml
<VerticalStackLayout>
    <VerticalStackLayout.Padding>
        <OnPlatform x:TypeArguments="Thickness">
            <On Platform="MacCatalyst" Value="24,16" />
            <On Platform="iOS" Value="16,8" />
        </OnPlatform>
    </VerticalStackLayout.Padding>
</VerticalStackLayout>
```
- Use `DeviceIdiom` checks for phone vs tablet vs desktop differences

## Styling & Theming

### Resource Dictionaries
- Define colors, styles, and templates in `Resources/Styles/`
- Use `AppThemeBinding` for light/dark mode:
```xml
<Color x:Key="PageBackground">
    <AppThemeBinding Light="{StaticResource Gray100}" Dark="{StaticResource Gray950}" />
</Color>
```
- Define named styles for reuse: `FormLabel`, `CaptionLabel`, `CompactButton`, etc.
- Use `BasedOn` for style inheritance

### Color Palette
- Define a complete neutral scale (Gray100–Gray600, Gray900, Gray950)
- Avoid referencing colors that don't exist in your palette
- Semantic colors: `Primary`, `Secondary`, `Error`, `Warning`, `Success`
- Test in both Light and Dark AppTheme

### Typography in MAUI
- Use `Label` with named styles for consistent typography
- Set `FontSize` using named sizes or explicit values (don't mix)
- `LineBreakMode="WordWrap"` for multi-line text
- `MaxLines` to limit visible lines with truncation

## Controls & Components

### Buttons
- Use `Button` for primary actions, not `TapGestureRecognizer` on labels
- Style hierarchy: Primary (filled) → Secondary (outlined/ghost) → Text-only
- `IsEnabled="False"` for disabled state — don't roll your own
- Show `ActivityIndicator` or change text during async operations
- Touch target: set minimum `HeightRequest="44"` on iOS, `HeightRequest="48"` on Android

### Forms & Input
- `Entry` for single-line input, `Editor` for multi-line
- Always set `Keyboard` property: `Keyboard="Email"`, `Keyboard="Numeric"`, `Keyboard="Url"`
- Use `Placeholder` AND a visible `Label` above the input
- `IsPassword="True"` for password fields
- Validation: use CommunityToolkit.Mvvm `ObservableValidator` with data annotations
- Group related fields in `Border` or `Frame` with section headers

### Lists & Collections
- `CollectionView` is the primary list control (not `ListView`)
- Use `ItemTemplate` with `DataTemplate` for item layout
- `EmptyView` for empty state — never show a blank list
- `RefreshView` wrapping `CollectionView` for pull-to-refresh
- `RemainingItemsThreshold` for incremental loading
- Selection: `SelectionMode="Single"` or `SelectionMode="Multiple"` with visual feedback

### Popups & Dialogs
- `DisplayAlert` for simple confirmations
- `DisplayActionSheet` for action lists
- CommunityToolkit.Maui `Popup` for custom dialogs
- Always provide Cancel/Close option
- Destructive options: `FlowDirection` with red/destructive styling

## Mac Catalyst Specifics

### Menu Bar
- Build menus with `MenuBarItem` in Shell or use `UIMenuBuilder` via platform code
- Insert custom menus with `InsertSiblingMenuAfter`
- Cmd+, for Settings via `UIKeyCommand` in `AppDelegate.cs`
- Standard shortcuts: Cmd+N (new), Cmd+S (save), Cmd+W (close), Cmd+Q (quit)

### Window Management
- Set minimum window size in platform code
- Remember window position/size (persist in Preferences)
- Support standard resize behavior

### Title Bar
- `Shell.TitleView` doesn't work — use `ToolbarItems` for title bar actions
- Keep toolbar items minimal (3–5 max)

## iOS Specifics

### Background Tasks
- Both iOS and Mac Catalyst `Info.plist` need `UIBackgroundModes` with `fetch`
- Use `BGTaskScheduler` for background work

### Platform Detection
- `OperatingSystem.IsIOSVersionAtLeast()` returns true on Mac Catalyst too
- Use `DeviceInfo.Idiom` or `DeviceInfo.Platform` for accurate platform checks

### Gestures
- Double-tap detection: use `CancellationTokenSource` delay approach, not multiple gesture recognizers (causes flicker)
- Swipe gestures with `SwipeView` on list items
- Long-press with `TapGestureRecognizer` (NumberOfTapsRequired does not support long press — use custom handler)

## MVVM Patterns

- ViewModels: use `ObservableObject` from CommunityToolkit.Mvvm
- Commands: `[RelayCommand]` attribute for auto-generated commands
- Use `[ObservableProperty]` for bindable properties
- Compiled bindings: `x:DataType` on every page/template for performance and compile-time checking
- Register ViewModels and services in `MauiProgram.cs` with DI
- Navigation: inject `INavigationService` or use Shell navigation with query parameters

## Performance

- Use compiled bindings everywhere (`x:DataType`)
- Avoid `BindableLayout` for large collections — use `CollectionView`
- Use `DataTemplateSelector` instead of runtime visibility toggles
- Minimize XAML nesting depth (deep trees hurt layout performance)
- Profile with `dotnet-trace` and MAUI performance diagnostics
- Use `MainThread.BeginInvokeOnMainThread()` for UI updates from background threads

## MAUI Anti-Patterns

- Using `StackLayout` instead of `VerticalStackLayout`/`HorizontalStackLayout`
- `MaximumWidthRequest` for layout constraints (it's broken)
- `Shell.TitleView` on Mac Catalyst (doesn't render)
- `OperatingSystem.IsIOSVersionAtLeast()` to distinguish iOS from Mac Catalyst
- Multiple `TapGestureRecognizer` for double-tap detection
- Missing `x:DataType` on pages (loses compiled binding benefits)
- `ListView` instead of `CollectionView`
- Hardcoded colors instead of `AppThemeBinding` resources
- Missing `EmptyView` on `CollectionView`
- Blocking the main thread with synchronous I/O

## MAUI Self-Check

In addition to the universal and platform-specific self-checks:
- [ ] `x:DataType` set on every page and DataTemplate (compiled bindings)
- [ ] `WidthRequest` used instead of `MaximumWidthRequest` for content width
- [ ] Named styles from Styles.xaml used consistently
- [ ] `AppThemeBinding` used for light/dark mode colors
- [ ] `CollectionView` has `EmptyView` defined
- [ ] Keyboard types set on all `Entry` controls
- [ ] Mac Catalyst uses `ToolbarItems`, not `Shell.TitleView`
- [ ] `VerticalStackLayout`/`HorizontalStackLayout` used, not `StackLayout`
- [ ] Services and ViewModels registered in DI container
- [ ] Platform checks use `DeviceInfo.Platform`, not `OperatingSystem.IsIOSVersionAtLeast()`
