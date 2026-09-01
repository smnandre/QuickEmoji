# QuickEmoji

A macOS menu-bar app for inserting emoji and special characters from anywhere. One global shortcut opens a search-and-pick panel, then inserts the selected character into the app you were using. Visit [smnand.re/quickemoji](https://smnand.re/quickemoji).

> The picker works in text-capable apps such as Safari, Notes, Slack, code editors, and terminals.

## Install

### Homebrew

```bash
brew trust --cask smnandre/tap/quickemoji
brew install --cask smnandre/tap/quickemoji
```

### Direct download

Download `QuickEmoji.dmg` from the [latest release](https://github.com/smnandre/QuickEmoji/releases/latest), open it, then drag `QuickEmoji.app` to `Applications`.

## Usage

### The picker - ⌘⇧E

Press **⌘⇧E** anywhere. A floating panel opens near the top-center of the active screen.

- Type to filter
- Arrow keys to navigate
- **Enter** to insert the selected character
- **Shift-Enter** to insert and keep the picker open
- **Command-A** to select all typed search text
- **Control-click** or **right-click** to copy
- **Escape** or **Tab** closes the picker; so does any click outside it

Search understands English Unicode names and shortcodes. It also supports Unicode CLDR short names in French, Spanish, German, and Simplified Chinese.

## First launch and Accessibility permission

QuickEmoji asks for **Accessibility** access on first launch:

> System Settings → Privacy & Security → Accessibility → QuickEmoji

If access is missing, QuickEmoji asks macOS for permission and waits for access to be granted. Use **Open Accessibility Settings** in the menu-bar dropdown to open the relevant System Settings page directly.

This is required for: the global ⌘⇧E shortcut, locating the text cursor, and inserting the chosen character into the focused field.

QuickEmoji keeps emoji usage and per-app ranking data on your Mac. It sends no emoji history or focused-field content. The manual update check reads the published Homebrew cask. There is no telemetry.

## Menu-bar dropdown

Click the menu-bar icon for:

- **Show Picker (⌘⇧E)** - same as the shortcut
- **Launch at Login** - open QuickEmoji automatically when you sign in
- **Check for Updates…** - one-shot lookup against the published Homebrew cask. No background polling, no telemetry.

## Requirements

- macOS 26 or later
- Apple silicon

## Build from source

```bash
git clone https://github.com/smnandre/QuickEmoji.git
cd QuickEmoji

make verify
make run
```

## Contributing

Contributions are welcome. Run `make verify` before opening a pull request.

## License

Released by [Simon André](https://smnandre.dev) under the [MIT License](LICENSE).
