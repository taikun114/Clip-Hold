# Clip Hold Changelog
**English** | [日本語](docs/CHANGELOG-ja.md)

## 1.2.1
### Bug Fixes and Improvements
- Correct the English wording of “Only \_\_” displayed in the filtering options from “Only \_\_” to “\_\_ Only”
  - Example: `Only Text` → `Text Only`
- Improve to display a clip icon when the history item is a website link
- Add “Links Only” to the filtering options in the History Window

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