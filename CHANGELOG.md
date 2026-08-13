# Clip Hold Changelog
**English** | [日本語](docs/CHANGELOG-ja.md)

<!--
The order of listing is as follows.
- New Features
  - Notable Information
  - Support
  - Additions
- Bug Fixes and Improvements
  - Fixes
  - Improvements
  - Changes
  - Additions
  - Removals
Only for versions 1.5.0 and later. Earlier versions may not follow this order.

Notes
- Make the first level of the list bold
- Make links bold
- When linking to Issues, Pull Requests, or Discussions, include the full URL
-->

## 1.7.0
### New Features
- **Support for Spotlight search and Shortcuts actions**
  - You can search and copy history and standard phrases from Spotlight, or use Shortcuts actions to copy specific history and standard phrases.
- **Support for importing and exporting history including files**
  - You can now export all history data, including files and folders saved in the save folder. You can still import history files exported from previous versions.
- **Add the "Quick Overlay" feature**
  - A Quick Overlay feature has been added that allows you to easily copy history and standard phrases just by moving the mouse cursor while holding down a shortcut key. Most operations are executed by releasing the shortcut key after moving the mouse cursor while holding it down, so it is designed to be easily operated without explicitly clicking.
  - You can enable Quick Overlay from the "Quick Overlay" section of the General settings. For detailed instructions on how to use it, you can click the "How to use Quick Overlay..." button in the "Quick Overlay" section of the General settings.
- **Add the New Copy feature**
  - By default, you can press `⌥ (Option)` + `⌘ (Command)` + `A` to enter your favorite text and create a new copy. You no longer need to enter it into a note, etc. when you want to copy a specific string.
- **Add a pin feature to the copy history**
  - Only one item can be pinned at a time. By default, you can copy or Quick Paste the pinned item by pressing `⌥ (Option)` + `⌘ (Command)` + `P`.
- **Add a "Show Other History from This App" feature to the History window**
  - You can now easily filter by app from the context menu of each history item.
- **Add a "Clear All Filters" button to the filter menu in the History window**
  - Displayed when any filter is applied, and clicking it will clear all filters.
- **Add a "Show Current Preset Icon" option to the "Menu" section of the General settings**
  - When enabled, the currently selected preset icon will be displayed in the menu bar.
- **Add a "Quick Paste to Previous Text Field" option to the General settings**
  - When this setting is used, when you copy, copy as plain text, or change and copy from the History or Standard Phrase window, the focus is returned to the previously focused app before executing Quick Paste. If you are focused on a text field, you can easily copy and paste into the previous text field.
  - You can temporarily disable Quick Paste by holding down the `⌥ (Option)` key.
- **Add a feature to recalculate the total size of the saved folder in the Copy History settings**
  - The size of all files and folders included in the saved folder is now recalculated to display the correct size.

### Bug Fixes and Improvements
- **Fix issue where copying a history with extremely long text from the History window could cause freezes or increased memory usage**
- **Fix issue where the app might crash during Quick Paste**
- **Fix issue where the copy notification would not disappear when copying from the menu in the Standard Phrase window**
- **Fix issue where some sheets were not displayed correctly on macOS Golden Gate**
- **Fix issue where some history and standard phrase settings were not applied until the app was restarted**
- **Fix issue where processing stopped while the large file copy alert was displayed**
  - With native alerts, all processing stopped while the alert was displayed due to OS constraints. To fix this, a custom alert was implemented. As a result, processing no longer stops even when the alert is displayed, and the alert is always displayed in the foreground.
- **Fix issue where app icons might not display correctly in the filter menu of the History window on macOS Sonoma**
- **Fix issue where correct thumbnail images were not displayed when copying images from web browsers or other apps**
- **Improve settings layout**
  - The "Standard Phrases Window" section and "History Window" section in the General settings have been moved to the Standard Phrases and Copy History settings, respectively.
- **Improve the performance of the History window**
  - Implemented pagination, limiting the initial display to 100 items and loading additional history items as you scroll.
- **Improve History window to allow removing only specific file history**
  - If the history item is a file, you can now remove it from the list without affecting other related history by holding down the `⌥ (Option)` key and clicking "Remove Only This Item..." from the context menu.
- **Improve history addition performance when copying files**
- **Improve file copying behavior**
  - A progress bar indicating the progress is now displayed when copying large files, and the duplicate detection system has been enhanced. It is now also possible to cancel the copy midway during large file copies.
- **Improve folder copying behavior**
  - The size displayed in the alert when a folder is copied is now calculated correctly, and an alert is now displayed when the added size calculation timeout is exceeded. Furthermore, the progress of the folder copy is now displayed in the history list.
- **Improve icon display on macOS Golden Gate**
- **Improve the display of History and Standard Phrase windows on macOS Golden Gate**
- **Improve the add apps to exclude screen**
- **Improve the preset picker display on macOS Tahoe or later**
- **Improve accuracy of detecting the source application of copied items**
  - A more accurate app is now detected when copying from a background window (e.g., via right-click) while another app is focused. Note that due to system limitations, if you copy text from a context menu on the Clip Hold window (such as in an alert or sheet), another frontmost app will be detected. (Don't worry, copying from the copy history or standard phrases will be recognized correctly.)
- **Improve to allow toggling clipboard monitoring from the menu**
- **Improve to display currently configured shortcut keys in the menu**
- **Improve operability of History and Standard Phrase windows**
  - When you open the History or Standard Phrase window, the first item is now focused, making it easier to operate with just the keyboard. You can also type directly to search or return focus to the list.
- **Improve the behavior of the search field in the History and Standard Phrase windows**
  - Previously, pressing the Escape key closed the window immediately. Now, if there is any text in the search field, pressing Escape once will clear the text, and pressing it a second time will close the window.
- **Improve to show an alert when attempting to change the maximum number of history to save to a value smaller than the currently saved history count**
- **Changes to the preset icon picker package**
  - Icon names are now displayed, and you can filter by specific categories using the category picker.
- **Change the default of “Size for Copy Alert” to 100 MB**
  - To prevent the saved folder capacity from unexpectedly expanding, the capacity threshold before displaying the alert has been reduced.

## 1.6.3
### New Features
- **Add French (`fr`), German (`de`), Spanish (`es`) localization by generative AI**
  - Since I have no knowledge of languages other than Japanese and English, translations may contain strange translations. If you notice any translations that need correction, I would appreciate it if you could send feedback on what to change and how!
- **Add the “Date and Time Display Format” option to the “Menu” section and “History Window” section in General Settings**
  - Changes how the date is displayed when copied. You can choose from the following options.
    - **Absolute** (Default)\
      Example: 11/30/2025, 12:34PM
    - **Relative**\
      Example: 5 minutes ago
    - **Both: Absolute (Relative)**\
      Example: 11/30/2025, 12:34PM (5 minutes ago)
    - **Both: Absolute - Relative**\
      Example: 11/30/2025, 12:34PM - 5 minutes ago
    - **Both: Relative (Absolute)**\
      Example: 5 minutes ago (11/30/2025, 12:34PM)
    - **Both: Relative - Absolute**\
      Example: 5 minutes ago - 11/30/2025, 12:34PM

### Bug Fixes and Improvements
- **Fix issue where the “Resume” button did not appear in the notification panel sent when launching the app while clipboard monitoring was paused**
- **Fix issue that preset name in the edit screen for default presets was not localized**
- **Fix “Change History and Copy” to “Change Item and Copy”**
  - The issue where the “Change History and Copy” was also displayed on the change and copy standard phrases screen has been fixed.
- **Fix issue where the History and Standard Phrases window could not be closed using the Escape key**
- **Fix issue where the default preset icon was not generated**
- **Improve app performance**
  - Proper cache utilization and automatic cleanup of unnecessary data now help prevent performance degradation even when Clip Hold is running for long periods.
- **Improve shortcut keys for the change history and copy screen**
  - Pressing `⌘ (Command)` + `S` while the change history and copy screen is open now performs the copy action.
- **Improve the input field box highlighting on the change and copy screens for history and standard phrases, and on the add edit screen for standard phrases, when “Increase Contrast” is enabled in System Settings**
- **Improve to send a notification when the shortcut key for standard phrases that are not set is pressed**
- **Improve the clipboard monitoring indicator in the Privacy Settings when “Differentiate Without Color” is enabled in System Settings**
- **Add a description regarding size calculation to the “Total Size of Saved Folder:” in Copy History Settings**
- **Remove height restrictions on input fields in the history and standard phrases edit screens**
  - When these screens are displayed as windows, increasing the window height now causes the input fields to expand accordingly.

## 1.6.2
### Bug Fixes and Improvements
- **Fix issue that sometimes prevented copying the correct folder**
  - This issue occurred due to a malfunction in the duplicate detection feature. Fixed by skipping duplicate detection for folders.
  - Since duplicate detection for folders is now disabled, please note that copying the same folder multiple times from another app will result in duplicate saves.
- **Fix issue that allows saving with empty preset names**
- **Improve Standard Phrases window to scroll to top when switching presets**
  - Fixed issue where the list could be cut off when switching from a preset with long entries.
- **Improve to automatically switch to newly added presets when new ones are added**
- **Improve focus management in the add standard phrase screen**
  - Pressing the Return key in the custom title input field now moves focus to the main text input field.
- **Improve shortcut keys for the add standard phrase screen**
  - Pressing `⌘ (Command)` + `S` while the add standard phrase screen is open now performs the save action.

## 1.6.1
### Bug Fixes and Improvements
- **Fix issue ([#4](https://github.com/taikun114/Clip-Hold/issues/4)) that sometimes failed to launch Clip Hold**

## 1.6.0
### New Features
- **Add the feature to set icons and colors for standard phrase presets**
  - You can now assign colors and set your favorite icons for each preset.
  - Icons can be selected from SF Symbols. While you can choose icons from the in-app symbol picker, using the [**SF Symbols app**](https://developer.apple.com/sf-symbols/) is convenient for viewing symbols in more detail or searching for them.
  - You can change icons and colors from the edit screen in the “Preset Settings” section of the Standard Phrases settings.
- **Add the “Overlay Display” option and “Overlay Transparency” option to the “History Window” section and “Standard Phrases Window” section in General Settings**
  - **Overlay Display**
    - When unfocused, make the window semi-transparent.
  - **Overlay Transparency**
    - When “Overlay Display” is enabled, you can set the transparency level of the semi-transparent window between 20% and 80%.
- **Add the “Ignore Standard Phrases” option to the “History Settings” section in the Copy History Settings**
  - Prevents copied standard phrases from being added to the history.
- **Add the “Delete All History from This App...” feature to the History window’s context menu and action menu**
- **Add the “Change and Copy...” feature to the Standard Phrases window’s context menu and action menu**
  - Similar to the “Change and Copy...” feature (formerly “Edit and Copy...”) in the History window, a feature allowing you to edit a portion and create a new copy has been added to the Standard Phrases window.

### Bug Fixes and Improvements
- **Improve to remove animated effects when “Reduce Motion” is enabled**
- **Improve the style of navigation buttons in the Settings window for macOS Sequoia or earlier versions**
  - Icon positioning and spacing have been improved, bringing them closer to the navigation buttons in System Settings.
- **Improve the default preset to be editable**
  - You can now edit the default presets to change colors and icons (please note that you cannot change the names).
- **Improve accessibility and notification permission status display in Privacy Settings to update in real time**
- **Improve the style of “Quick Paste Only for Text” when “Quick Paste” is off**
  - When “Quick Paste” is off, the title and description in the settings item now appear in a lighter color, making it easier to see that the option is disabled.
- **Change “Edit and Copy...” to “Change and Copy...” in the History window**
  - The feature name has been changed to make it clearer. No changes have been made to the functionality.
- **Change to monospace font for text input field on the “Change and Copy” screen**
- **Add help text to the preset list in the “Preset Settings” section of Standard Phrases Settings**
  - Hovering the mouse cursor over each list item now displays the full preset name in a tooltip.
- **Add a character limit to the preset names in each preset picker**
  - Even if excessively long preset names are set, they no longer cover the screen or slow down processing.

## 1.5.0
### New Features
- **Add “Plain Text Only” and “Rich Text Only” options to the filtering options**
  - These options are in “Text Only”.
- **Add “PDF Only”, “Videos Only”, “Folders Only” and “Other Files” options to the filtering options**
  - These options are in “Files Only”.
- **Add a feature to edit and copy**
  - You can edit and copy the history by clicking “Edit and Copy...” in the context menu or action menu of a text item in the History window.
  - You can also use a shortcut key to edit and copy the latest history item. The default shortcut key is `⌥ (Option)` + `⌘ (Command)` + `E`.
  - This feature allows you to edit and copy text retrieved from your past history, so your past history will not be modified.

### Bug Fixes and Improvements
- **Fix issue that previously selected items weren't chosen when closing the custom number input sheet in Settings using the Escape key**
- **Fix issue that copied folders starting with ”.” did not appear in the History window**
- **Fix the background of the window for add a standard phrase and add a preset**
- **Improve settings item names and descriptions in General and Copy History Settings**
  - Names have been changed to be more intuitive, and descriptions have been added to each item, making it easier to understand the role of each setting and what functionality it provides.
- **Improve the layout of settings items in General and Copy History Settings**
  - Related or similar features are now grouped together.
- **Improve behavior to disable filtering and sorting buttons while loading history**
- **Improve Settings window to be able to close with the Escape key**
- **Improve the style of the add standard phrase screen**
- **Improve the Privacy Settings indicator to be differentiated by shape when “Differentiate Without Color” is enabled in System Settings**
- **Improve the search boxes in the History and Standard Phrases windows to display borders when “Increase Contrast” is enabled in System Settings**
- **Improve the separator line between navigation buttons in the Settings window to increase contrast when “Increase Contrast” is enabled in System Settings**
- **Improve the history list to display dedicated icons for non existing apps**
- **Improve the “Apps” picker in the filtering options to display the selected app icon and name**
- **Change default behavior to display numbers for each item in the History and Standard Phrases windows**
- **Change default behavior to not close the window when you double-click an item in the History or Standard Phrases windows**
- **Change the rich text icon**
  - Changed from `append.page` to `richtext.page`, making rich text items easier to recognize.
- **Change “Links Only” into “Text Only” in the filtering options**
- **Change the clipboard check interval to 0.1 seconds**
  - Now faster at 0.1 seconds from 0.5 seconds previously, reducing delays in history updates and app retrieval.
  - Performance impact from this change is minimal.
- **Add icons to each filtering option and sorting option**
- **Add `ico`, `icns`, `svg`, `eps`, `ai`, and `psd` to the filtering targets for “Images Only”**
- **Remove the icon from the “Copy as Plain Text” option in the History window's context menu and action menu**
  - Following Apple's [**Human Interface Guidelines**](https://developer.apple.com/design/human-interface-guidelines/menus#Icons), icons for related features now appear only on one parent item (in this case, “Copy”).

## 1.4.0
### New Features
- **Support for Rich Text**
  - This fixes a issue ([**#3**](https://github.com/taikun114/Clip-Hold/issues/3)) that caused text to be copied as an image in Microsoft Office software.
- **Support for PDF**
  - Software that stores data as PDF in the clipboard can now copy vector data as PDF.
- **Support Liquid Glass**
   - New app icons designed for Liquid Glass have been added.
   - Liquid Glass effects have been added to the background of the History and Standard Phrases windows, and to the overlay background of the License Information screen.
   - Liquid Glass is available on macOS Tahoe or later.
- **Add “Copy as Plain Text” in the History window when the history item is rich text**
- **Add “Automatic” to the app filtering options in the History window**
  - This option automatically filters based on the app currently in focus.
- **Add “Exclude Clip Hold Windows with App's ‘Automatic’ Filtering” to the History Window section in General Settings**
  - Do not switch the filtered app when you focus the Clip Hold window (such as the History window) while the app's “Automatic” filtering is active.
- **Add “Use Filtered Copy History in the History Window” to the “Copy History” section in Shortcuts Settings**
  - Allow copying filtered history using shortcut keys when the History window is open and filtering is applied.
- **Add the feature to be able to add apps by drag and drop to the Preset to Assign list in Standard Phrases Settings and the Apps to Exclude list in Privacy Settings**

### Bug Fixes and Improvements
- **Fix issue that voice input is entered in the standard phrase input field when the preset add screen is opened from the standard phrase add screen**
- **Fix issue that “Show All Processes” does not work on the add apps to exclude screen in Privacy Settings**
- **Fix issue that default preset name was not localized in the notification shown when switching presets using shortcut keys**
- **Fix issue that the “Preset to Assign” picker in Standard Phrases Settings becomes empty when the selected preset is deleted**
- **Fix issue that the remove app button (minus button on the list) does not update when switching the Preset to Assign list in Standard Phrases Settings**
- **Fix issue that memory is not released even after closing the History and Standard Phrases windows**
- **Improve the Settings screen and add standard phrase screen when no presets exist**
- **Improve the Settings screen and Standard Phrases window when all presets are deleted**
- **Improve the focus back to the input field when returning to the add standard phrase screen after adding a preset from the add standard phrase screen**
- **Improve the alert message when deleting presets**
  - Added a message indicating the number of standard phrases within the preset being deleted and that they will be removed.
- **Improve focus detection in the Settings window**
   - Improved the styling of the “Information” button in the Settings window to ensure it is properly set.
- **Improve only the display name of image files to be localized**
    - Image files that cannot be obtained by name such as images copied from a web browser are now properly localized when copied and then the system language is changed.

## 1.3.2
### New Features
- **Add “Exclude Clip Hold Windows” option to the “Assign Presets” section of the Standard Phrases Settings**
  - Prevents the preset switching when the Clip Hold window (such as the Standard Phrases window) is focused.

### Bug Fixes and Improvements
- **Fix the issue ([#2](https://github.com/taikun114/Clip-Hold/issues/2)) that when “Maximum number of history items to save” is set, old history items are saved instead of the set number of new history items**
- **Improve margins on the edit standard phrase screen**
- **Improve to remember the last selected preset when importing presets**

## 1.3.1
### New Features
- **Add the feature to allow drag and drop to copy items in the History and Standard Phrases windows**
  - You can drag and drop icons shown for each item in the History window, or list items in the Standard Phrases window to copy text or files to the dropped location.
- **Add the feature to duplicate a standard phrase**
  - You can duplicate a standard phrase by clicking on “Duplicate” which has been added to the context menu and the action menu (Standard Phrases window only) in the Standard Phrases window or in standard phrases list in the “Standard Phrases Settings” section of the Standard Phrases Settings.
- **Add the feature to duplicate a preset**
  - You can duplicate a preset by clicking on “Duplicate” which has been added to the context menu in the preset list in the “Preset Settings” section of the Standard Phrases Settings.
- **Add the feature to move a standard phrase to another preset**
  - You can move a standard phrase to another preset by clicking on “Move to Another Preset...” which has been added to the context menu and the action menu (Standard Phrases window only) in the Standard Phrases window or in standard phrases list in the “Standard Phrases Settings” section of the Standard Phrases Settings.

### Bug Fixes and Improvements
- **Fix issue that the last selected preset is not remembered**
- **Fix issue that the last position in the settings window is not remembered**
- **Fix issue that default presets are not localized in some places**
- **Fix issue that description text was sometimes cut off in import to preset sheet**
- **Fix issue that some of the context menus in the Standard Phrases Settings did not have icons**
- **Add app icons to the app picker in the filtering options in the History window**
- **Change the filtering and sorting buttons in the History window and the preset button in the Standard Phrases window to a picker**
- **Change preset icons to `star.square`**
  - The icon has been changed in the Standard Phrases window and in the menu so you can recognize the preset feature at a glance.

## 1.3.0

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
  - You can now group your favorite standard phrases by preset. You can switch between presets from the menu or the Standard Phrases window. You can also use shortcut keys to create and switch presets.
- **Add “Assign Preset” settings to “Standard Phrases” settings**
  - If you assign presets to apps, they will automatically switch to the selected preset when the app is on the foreground.
- **Add “Developer Features” tab**
  - **Add “Show Character Count” option**
    - Show the character count after the date in the History window and in the menu.
  - **Add “Show a Color Icon Based on Color Code” option**
    - When you copy a color code in HEX, HSL / HSLA, or RGB / RGBA format, an icon for that color will be shown in the History / Standard Phrases window and menu.
  - **Add “Allow Filtering by Color Codes” option**
    - Add “Color Codes Only” to the filtering options in the History window.
  - **Add “Reset All Settings” option**
    - Resets all settings of the app to their defaults. History and standard phrases are not affected.
- **Add “Show App Icons” option**
  - Toggle to show or hide the app icon for each item in the History window.
- **Support link in standard phrases**
  - As in the History window, the Standard Phrases window now displays “Open Link” from the context menu when the item is a link.
- **Support for copying multiple files at the same time**
- **Support filtering by the app in the History window**

### Bug Fixes and Improvements
- **Fix issue with two “About QR Code” items being displayed on the license sheet**
- **Fix issue that an image or image address could not be copied from Safari**
- **Fix issue that sometimes did not add to the history**
- **Fix issue that sometimes the background color did not match the theme in the Add a Standard Phrase window**
- **Improve menu history thumbnails to fit in a square**
- **Improve to temporarily disable Quick Paste when clicking on an item from the menu bar while holding down the Option key**
  - Copying from a shortcut key is not affected by this.
- **Improve the issue causing large disk writes when copying with a large number of history items**
- **Improve the list of apps displayed on the app adding screen in the “Apps to Exclude” list**
- **Improve the design of the add edit standard phrase screen**
- **Improve the design of the custom number input sheet**
- **Add an app icon to the list item in the History window**
  - It shows the app icon of the app that was in the foreground when it was copied. The icon will not be shown in the copy history before this feature was added.
  - When you hover the mouse cursor over an app icon, the app name will be displayed in a tooltip.
- **Add an icon to the Standard Phrase window**
- **Add “Open” to the History window menu when the item is a file**
- **Add “Add to Apps to Exclude...” to the History window menu**
- **Add a dedicated alert message when trying to delete a file from the history**
- **Add a picker that allows you to select a destination preset on the add standard phrase screen**
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
