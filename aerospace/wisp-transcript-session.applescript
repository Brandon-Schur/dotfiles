-- Toggle a Wisp "Transcript Session" (formerly long-form dictation).
-- Wisp 2.9.0 removed the long-form keyboard shortcut; the only entry point is
-- the menu bar item, so this script clicks it. Bound in aerospace.toml.
-- Requires: AeroSpace allowed under Privacy & Security -> Accessibility and
-- Automation -> System Events (macOS prompts on first run).

tell application "System Events"
	if not (exists process "Wisp") then
		tell application "Wisp" to launch
		delay 1.5
	end if
	tell process "Wisp"
		set wispItem to menu bar item 1 of menu bar 2
		click wispItem
		delay 0.25
		set wispMenu to menu 1 of wispItem
		-- Stop first so the hotkey toggles; long-form names kept as a fallback.
		repeat with prefix in {"Stop Transcript", "Start Transcript", "Stop Long-Form", "Start Long-Form"}
			set hits to (menu items of wispMenu whose name starts with (prefix as text))
			if (count of hits) > 0 then
				click item 1 of hits
				return
			end if
		end repeat
		key code 53 -- no matching item: close the menu (Escape)
	end tell
end tell
