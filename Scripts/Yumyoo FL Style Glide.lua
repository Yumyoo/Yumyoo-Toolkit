-- @description Yumyoo Auto Glide - Defer Script
-- @author Yumyoo (Edit by Grayson Solis)
-- @version 2

local PB_RANGE    = 12
local GLIDE_CHAN  = 15   -- 0-indexed = MIDI ch16
local WIPE_TAIL   = 19200
local GLIDE_SHAPE = 1    -- 0=square 1=linear 2=slow start/end 3=fast start 4=fast end 5=bezier

if PB_RANGE == 0 then PB_RANGE = 1 end

local last_state = ""
local update_pending = false
local time_to_update = 0
local DEBOUNCE_TIME = 0.15

local function mouse_held()
    if reaper.JS_Mouse_GetState then
        return (reaper.JS_Mouse_GetState(0xFFFFFFFF) & 1) == 1
    end
    return false
end

local function fingerprint(take)
    local s, i = "", 0
    while true do
        local ok, _, mt, a, b, c, p = reaper.MIDI_GetNote(take, i)
        if not ok then break end
        if (not mt) or c == GLIDE_CHAN then
            s = s .. a .. "," .. b .. "," .. c .. "," .. p .. ";"
        end
        i = i + 1
    end
    return s
end

local function enforce_mute(take)
    local i, changed = 0, false
    while true do
        local ok, _, muted, _, _, c = reaper.MIDI_GetNote(take, i)
        if not ok then break end
        if c == GLIDE_CHAN and not muted then
            reaper.MIDI_SetNote(take, i, nil, true, nil, nil, nil, nil, nil, true)
            changed = true
        end
        i = i + 1
    end
    if changed then reaper.MIDI_Sort(take) end
end

local function rebuild(take)
    reaper.PreventUIRefresh(1)

    local bases, glides = {}, {}
    local i = 0
    while true do
        local ok, _, mt, s, e, c, p = reaper.MIDI_GetNote(take, i)
        if not ok then break end
        if c == GLIDE_CHAN then
            glides[#glides+1] = {s=s, e=e, p=p}
        elseif not mt and (c == 0 or c == 1) then
            bases[#bases+1] = {idx=i, s=s, e=e, c=c, p=p}
        end
        i = i + 1
    end

    local _, _, cc_n = reaper.MIDI_CountEvts(take)
    for j = cc_n - 1, 0, -1 do
        local _, _, _, _, msg, ch = reaper.MIDI_GetCC(take, j)
        if msg == 224 and (ch == 0 or ch == 1) then reaper.MIDI_DeleteCC(take, j) end
    end

    table.sort(bases, function(a, b) return a.s < b.s end)

    local function active_base_at(t)
        local best = nil
        for _, b in ipairs(bases) do
            if b.s <= t and b.e > t and (not best or b.s > best.s) then best = b end
        end
        return best
    end

    for _, base in ipairs(bases) do
        if base.e <= base.s then goto next_base end

        local my_g = {}
        for _, g in ipairs(glides) do
            if g.s >= base.s and g.s < base.e then
                local owner = active_base_at(g.s)
                if owner and owner.idx == base.idx then my_g[#my_g+1] = g end
            end
        end
        if #my_g == 0 then goto next_base end

        table.sort(my_g, function(a, b) return a.s < b.s end)

        local max_e = base.e
        for _, g in ipairs(my_g) do if g.e > max_e then max_e = g.e end end

        local next_s = math.huge
        for _, b in ipairs(bases) do
            if b.s >= base.e and b.s < next_s then next_s = b.s end
        end

        local hold   = max_e - 1
        local wipe_e = math.min(max_e + WIPE_TAIL, next_s - 1)

        if wipe_e < base.s  then wipe_e = base.s     end
        if hold  >= wipe_e  then hold   = wipe_e - 1 end
        if hold  <  base.s  then hold   = base.s     end

        local pb   = 8192
        local evts = {{ppq=base.s, val=8192, sh=0}}

        for idx, g in ipairs(my_g) do
            if g.s <= hold then
                local diff   = math.max(-PB_RANGE, math.min(PB_RANGE, g.p - base.p))
                local target = 8192 + math.floor((diff / PB_RANGE) * 8191 + 0.5)
                local next_g_s    = idx < #my_g and my_g[idx+1].s or math.huge
                local interrupted = next_g_s < g.e
                local eff_e       = math.min(interrupted and next_g_s or g.e, hold)

                evts[#evts+1] = {ppq=g.s, val=pb, sh=GLIDE_SHAPE}

                if interrupted then
                    local dur = g.e - g.s
                    pb = dur > 0 and (pb + math.floor((target-pb)*(eff_e-g.s)/dur+0.5)) or target
                else
                    pb = target
                end
                pb = math.max(0, math.min(16383, pb))
                evts[#evts+1] = {ppq=eff_e, val=pb, sh=0}
            end
        end

        evts[#evts+1] = {ppq=hold,   val=pb,   sh=0}
        evts[#evts+1] = {ppq=wipe_e, val=8192, sh=0}

        table.sort(evts, function(a, b) return a.ppq < b.ppq end)
        local clean = {}
        for _, e in ipairs(evts) do
            local L = clean[#clean]
            if L and math.abs(L.ppq - e.ppq) < 0.5 then
                if e.sh == GLIDE_SHAPE then clean[#clean] = e
                else local sh=L.sh; clean[#clean]=e; if sh==GLIDE_SHAPE then clean[#clean].sh=GLIDE_SHAPE end end
            else clean[#clean+1] = e end
        end

        for _, e in ipairs(clean) do
            reaper.MIDI_InsertCC(take, false, false, e.ppq, 224, base.c, e.val&127, (e.val>>7)&127)
        end

        reaper.MIDI_Sort(take)
        local _, _, cc2 = reaper.MIDI_CountEvts(take)
        for j = 0, cc2-1 do
            local _, _, _, ppq, msg, ch = reaper.MIDI_GetCC(take, j)
            if msg == 224 and ch == base.c then
                for _, e in ipairs(clean) do
                    if math.abs(ppq - e.ppq) <= 2 then
                        reaper.MIDI_SetCCShape(take, j, e.sh, 0); break
                    end
                end
            end
        end

        ::next_base::
    end

    local anchors = {}
    for _, base in ipairs(bases) do
        local conflict = false
        for _, g in ipairs(glides) do
            if g.s == base.s then conflict=true; break end
        end
        if not conflict then
            reaper.MIDI_InsertCC(take, false, false, base.s, 224, base.c, 0, 64)
            anchors[#anchors+1] = {ppq=base.s, chan=base.c}
        end
    end

    reaper.MIDI_Sort(take)

    local _, _, total_cc = reaper.MIDI_CountEvts(take)
    for j = 0, total_cc-1 do
        local _, _, _, ppq, msg, ch = reaper.MIDI_GetCC(take, j)
        if msg == 224 then
            for _, a in ipairs(anchors) do
                if ppq == a.ppq and ch == a.chan then
                    reaper.MIDI_SetCCShape(take, j, 0, 0); break
                end
            end
        end
    end

    reaper.MIDI_Sort(take)
    reaper.PreventUIRefresh(-1)
end

local function loop()
    local ed   = reaper.MIDIEditor_GetActive()
    local take = ed and reaper.MIDIEditor_GetTake(ed)
    
    if take then
        local st = fingerprint(take)
        
        if st ~= last_state then
            last_state = st
            update_pending = true
            time_to_update = reaper.time_precise() + DEBOUNCE_TIME
        end

        if update_pending then
            if mouse_held() then
                time_to_update = reaper.time_precise() + DEBOUNCE_TIME
            elseif reaper.time_precise() >= time_to_update then
                update_pending = false
                
                enforce_mute(take) 
                rebuild(take)
                
                last_state = fingerprint(take)
            end
        end
    end
    
    reaper.defer(loop)
end

loop()
