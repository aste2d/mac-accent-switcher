# Mac Accent Switcher

Click a swatch to use an iMac or MacBook Neo system accent color. Restore your previous settings from the window or the menu bar. Made by **aste2d**.

点击色卡，快速切换 iMac 和 MacBook Neo 的机身专属主题色。主窗口和菜单栏都能一键恢复切换前的设置。

## Use

1. Open **Mac Accent Switcher.app** and click a swatch. The palette is also available from the paint palette icon in the menu bar.
2. Choose **Restore Original** to return to the preferences saved before the first switch. The backup persists between launches. Subsequent switches keep the same original.
3. If an app still shows the old color, quit and reopen that app. **Open Appearance** opens System Settings so you can check the **This Mac** swatch.
4. **Force Restart Dock, System Settings, and Finder** restarts all three apps after confirmation so they can reload the accent. Wait for any Finder file transfers to finish before using it.

macOS 15 Sequoia, 26 Tahoe, and 27 Golden Gate are the target versions. The app is universal (Apple silicon and Intel on versions that support Intel). iMac colors use IDs 3–8. MacBook Neo colors use IDs 15–17 and need a build with those colors, starting with macOS 26.3.1. The app checks each color against AppKit at launch and disables unavailable swatches. On some hardware or OS builds, running apps may only pick up the new color after relaunch.

## Build from source

Install Apple's Command Line Tools (`xcode-select --install`), then run:

```sh
bash build.sh --zip
bash test.sh
```

The app and distributable ZIP are written to `dist/`. The default build uses an ad hoc signature. A locally built copy is the simplest way to run it if Gatekeeper blocks a downloaded copy. Set `CODE_SIGN_IDENTITY` to use a local signing identity. Distribution signing and notarization are separate steps.

## Implementation

The app writes three preferences in the current user's global defaults domain: `NSColorSimulateHardwareAccent`, `NSColorSimulatedHardwareEnclosureNumber`, and `AppleAccentColor`. It saves the previous values, including absent keys, before the first switch. Restore puts those three keys back. It sends the system color change notifications after saving. No admin privileges are needed. The hardware simulation preferences are undocumented and may behave differently across macOS builds.

The palette was sampled from AppKit in sRGB. See the [iMac color mapping](https://georgegarside.com/blog/macos/imac-m1-accent-colours-any-mac/) and [MacBook Neo color mapping](https://forums.macrumors.com/threads/macbook-neo-hardware-accent-colors.2478747/).

MIT © 2026 aste2d
