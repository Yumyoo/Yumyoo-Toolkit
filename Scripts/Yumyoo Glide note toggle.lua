-- @description Yumyoo Auto Glide Toggle
-- @author Yumyoo
-- @version 1.0
-- @provides [midi_editor]

local ed = reaper.MIDIEditor_GetActive()
if not ed then return end

local _, _, sec, cmd = reaper.get_action_context()
local is16 = reaper.GetExtState("GraysonGlideToggle", "ch") == "16"

reaper.MIDIEditor_OnCommand(ed, is16 and 40482 or 40497)
reaper.SetExtState("GraysonGlideToggle", "ch", is16 and "1" or "16", false)

reaper.SetToggleCommandState(sec, cmd, is16 and 0 or 1)
reaper.RefreshToolbar2(sec, cmd)
