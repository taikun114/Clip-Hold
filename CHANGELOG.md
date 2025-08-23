# Clip Hold Changelog
**English** | [日本語](docs/CHANGELOG-ja.md)

## 1.3.0 (under development)

> [!IMPORTANT]
> This version has a major change in the way history files are saved.\
> If you update from a previous version, your history file will also be upgraded to the new format. **The new history file format is not compatible with older versions of Clip Hold.**
>
> Note that the history file `clipboardHistory.json` used in the previous version will stay after the upgrade with the name changed to `oldClipboardHistory.json`.\
> So if you use an older version of Clip Hold for some reason after upgrading the history file, you can rename `oldClipboardHistory.json` to `clipboardHistory.json` to load the old history file with the old Clip Hold.

> [!IMPORTANT]
> This version has changed the saving method with the introduction of the Standard Phrases Preset feature.\
> The file structure itself is unchanged, so it is compatible with older versions of Clip Hold.
> 
> Note that the standard phrases file `standardPhrases.json` used in previous versions will be renamed to `default.json` in the `standardPhrasesPreset` folder.\
> So if you use an older version of Clip Hold for some reason, you can rename `standardPhrasesPreset/default.json` to `standardPhrases.json` to load the standard phrases file with the old Clip Hold.

### New Features
- **Revamped settings screen**
  - The existing tabbed style has been greatly revamped to a sidebar style setting screen.
- **Add Preset feature for Standard Phrases**
  - You can now group your favorite standard phrases by preset. You can switch between presets from the menu or the Standard Phrases window.
- **Add “Show App Icons” option**
  - Toggle to show or hide the app icon for each item in the History window.
- **Add “Developer Features” tab**
  - **Add “Show Character Count” option**
    - Show the character count after the date in the History window and in the menu.
  - **Add “Show a Color Icon Based on Color Code” option**
    - When you copy a color code in HEX, HSL / HSLA, or RGB / RGBA format, an icon for that color will be shown in the History / Standard Phrases window and menu.
  - **Add “Allow Filtering by Color Codes” option**
    - Add “Color Codes Only” to the filtering options in the History window.
  - **Add “Reset All Settings” option**
    - Resets all settings of the app to their defaults. History and standard phrases are not affected.
- **Support link in standard phrases**
  - As in the History window, the Standard Phrases window now displays “Open Link” from the context menu when the item is a link.
- **Support for copying multiple files at the same time**
- **Support filtering by the app in the History window**

### Bug Fixes and Improvements
- **Fix issue with two “About QR Code” items being displayed on the license sheet**
- **Fix issue that an image or image address could not be copied from Safari**
- **Fix issue that sometimes did not add to the history**
- **Improve menu history thumbnails to fit in a square**
- **Improve to temporarily disable Quick Paste when clicking on an item from the menu bar while holding down the Option key**
  - Copying from a shortcut key is not affected by this.
- **Improve the issue causing large disk writes when copying with a large number of history items**
- **Add an app icon to the list item in the History window**
  - It shows the app icon of the app that was in the foreground when it was copied. The icon will not be shown in the copy history before this feature was added.
  - When you hover the mouse cursor over an app icon, the app name will be displayed in a tooltip.
- **Add an icon to the Standard Phrase window**
- **Add “Open” to the History window menu when the item is a file**
- **Add “Add to Apps to Exclude...” to the History window menu**
- **Add a dedicated alert message when trying to delete a file from the history**
- **Change file duplicate detection method to file hash-based**
  - This allows for more accurate duplicate file detection. Existing size-based duplicate detection is used for folders and other items for which file hashes cannot be computed.
- **Change the default “Maximum Size per File:” from 1 GB to Unlimited**

## 1.2.1
### Bug Fixes and Improvements
- **Correct the English wording of “Only \_\_” displayed in the filtering options from “Only \_\_” to “\_\_ Only”**
  - Example: `Only Text` → `Text Only`
- **Improve to display a clip icon when the history item is a website link**
- **Add “Links Only” to the filtering options in the History Window**

## 1.2.0
### New Features
- **Support for saving file and image copy history**
- **Support for Quick Look of files in the History Window**
  - You can Quick Look by pressing the space key with an item selected or by clicking on “Quick Look” from the menu.
- **Add filtering and sorting options to the History Window**
  - You can filter by file type and sort by date or file size.
- **Add “Only Text” option in the settings for Quick Paste**
  - When this option is enabled, you can prevent accidental pasting of a file or image when performing a Quick Paste.
- **Add “Maximum Size per File” option**
  - If you set a size, files larger than the set size will not be saved in the copy history.
- **Add “Show alert when copying a file larger than” option**
  - If you set a size, an alert will be shown asking if you want to save the file to history when you copy a file larger than the size you set.
- **Add “Open Link...” option to the menu of text items containing website URL in the History Window**
- **Add “Copy QR Code Contents” option to the menu of image items containing QR Code in the History Window**
  - With this change, the “Scan QR Code Image” setting has been removed, as the QR Code is now automatically scanned when the image is copied.

### Bug Fixes and Improvements
- **Add small app icon images**
  - This makes it easier to recognize when small app icon images are displayed, such as in System Settings.
- **Add icons to each item in the menu and history items in the History Window**
  - Some icons for menu items will appear on macOS Tahoe or later.
- **Add new “Copy History” tab**
  - Settings related to copy history have been moved to a new tab.
- **Add file size next to the date if the item on the History Window is a file**
- **Change description of “Apps to Exclude” setting**
- **Improve history list performance in the History Window**
  - Performance is no longer slowed down even if the list contains more than a few thousand items.

## 1.1.1
### Bug Fixes and Improvements
- **Add limit to number of characters displayed in standard phrases as well**
  - Standard phrases displayed in menus, list items in standard phrase settings, and shortcut settings will not be too long.

## 1.1.0
### New Features
- **Add the feature to create a QR Code from copied text**
  - Click “Show QR Code” in the item options of the History Window and Standard Phrases Window to generate a QR Code.
- **Add the feature to copy an image that contains a QR code to add the content to the history**
  - You can use it by enabling “Scan QR Code Image” in the settings.
- **Add the feature to drag and drop an image that contains a QR code into the history window to copy the content**
- **Add the feature to create a standard phrase from the clipboard contents**
  - Added shortcut key to add a standard phrase from the current clipboard contents.
  - Added the feature to add a standard phrase from an item in the History Window.
- **Add the feature to automatically scroll to the top when the history list is updated**
  - You can use it by enabling “Scroll to the Top When the List is Updated” in the settings.

### Bug Fixes and Improvements
- **Improve the context menu in the Standard Phrase Window and History Window**
  - Items that show an additional screen now have a trailing “...” and added a divider line above “Delete...”.
- **Improve placement in General settings**
- **Improve the Standard Phrases Window to be able to reorder items**
  - You can reorder only if you are not searching.
- **Fix the Standard Phrase Window and the History Window to remember the correct position**

## 1.0.1
### Bug Fixes and Improvements
- **Add accessibility labels**
  - Descriptions have been added to help VoiceOver users understand items.
- **Add option to temporarily hide menu bar icon**
  - The icon will reappear when you reopen the app.

## 1.0.0
Initial Release!
