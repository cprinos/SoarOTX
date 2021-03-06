-- JF Channel Swap
-- Timestamp: 2018-03-09
-- Created by Jesper Frickmann

local N = 32 -- Highest channel number to swap
local MAXOUT = 1250 -- Maximum output value
local MINDIF = 100 -- Minimum difference between lower, center and upper values
local MENUTXT -- Text to show on menu
local XDOT -- X position of number dot
local XREV -- X position of channel direction indicator
local CENTER -- X position of center line
local SCALE -- X scale
local XTXT -- Text position of warning message
local ATT1 -- Text attribute of warning message
local ATT2 -- Text attribute of warning message

local namedChs = {} -- List of named channels
local firstLine = 1 -- Named channel displayed on the first line
local selection = 1 -- Selected named channel
local srcBase = 	getFieldInfo("ch1").id - 1 -- ASSUMING that channel sources are consecutive!
local stage = 1 -- 1:Show warning 2:Run

-- Transmitter specific
if tx == TX_X9D then
	MENUTXT = " JF Channel Configurator "
	XDOT = 18
	XREV = 60
	CENTER = 135
	SCALE = 0.05
	XTXT = 30
	ATT1 = MIDSIZE
	ATT2 = 0
else
	MENUTXT = "Channel Config"
	XDOT = 15
	XREV = 45
	CENTER = 90
	SCALE = 0.025
	XTXT = 7
	ATT1 = 0
	ATT2 = SMLSIZE
end

local editing = 0 --[[ Selected channel is being edited
	0 = Not edited
	1 = Channel no. selected
	2 = Direction selected
	3 = Lower, Center, Upper selected
	4 = Range selected
	5 = Lower selected
	6 = Center selected
	7 = Upper selected
	11 = Channel no. edited
	13 = Lower, Center, Upper edited
	14 = Range edited
	15 = Lower edited
	16 = Center edited
	17 = Upper edited
]]

local function init()
	-- Build the list of named channels that are displayed and can be moved
	local j = 0
	
	for i = 1, N do
		local out = model.getOutput(i - 1)
		
		if out and out.name ~= "" then
			j = j + 1
			namedChs[j] = i
		end
	end
end -- init()

-- Swap two channels, direction = -1 or +1
local function MoveSelected(direction)
	local m = {} -- Channel indices
	m[1] = namedChs[selection] -- Channel to move
	m[2] = m[1] + direction -- Neighbouring channel to swap
	
	-- Are we at then end?
	if m[2] < 1 or m[2] > N then
		playTone(3000, 100, 0, PLAY_NOW)
		return
	end
	
	local out = {} -- List of output tables
	local mixes = {} -- List of lists of mixer tables

	-- Read channel into tables
	for i = 1, 2 do
		out[i] = model.getOutput(m[i] - 1)

		-- Read list of mixer lines
		mixes[i] = {}
		for j = 1, model.getMixesCount(m[i] - 1) do
			mixes[i][j] = model.getMix(m[i] - 1, j - 1)
		end
	end
	
	-- Write back swapped data
	for i = 1, 2 do
		model.setOutput(m[i] - 1, out[3 - i])

		-- Delete existing mixer lines
		for j = 1, model.getMixesCount(m[i] - 1) do
			model.deleteMix(m[i] - 1, 0)
		end

		-- Write back mixer lines
		for j, mix in pairs(mixes[3 - i]) do
			model.insertMix(m[i] - 1, j - 1, mix)
		end
	end

	-- Swap sources for the two channels in all mixes
	for i = 1, N do
		local mixes = {} -- List of mixer tables
		local dirty = false -- If any sources were swapped, then write back data

		-- Read mixer lines and swap sources if they match the two channels being swapped
		for j = 1, model.getMixesCount(i - 1) do
			mixes[j] = model.getMix(i - 1, j - 1)
			if mixes[j].source == m[1] + srcBase then
				dirty = true
				mixes[j].source = m[2] + srcBase
			elseif mixes[j].source == m[2] + srcBase then
				dirty = true
				mixes[j].source = m[1] + srcBase
			end
		end
		
		-- Do we have to write back data?
		if dirty then
			-- Delete existing mixer lines
			for j = 1, model.getMixesCount(i - 1) do
				model.deleteMix(i - 1, 0)
			end

			-- Write new mixer lines
			for j, mix in pairs(mixes) do
				model.insertMix(i - 1, j - 1, mix)
			end
		end
	end

	-- Update selection on screen
	if namedChs[selection + direction] and namedChs[selection + direction] == m[2] then
		-- Swapping two named channels?
		selection = selection + direction
	else
		-- Swapping named channel with unnamed, invisible channel
		namedChs[selection] = m[2]
	end
end -- SwapChannels()

local function Draw()
	DrawMenu(MENUTXT)
	
	-- Draw vertical reference lines
	for i = -5, 5 do
		local x = CENTER - 0.2 * i * MAXOUT * SCALE
		lcd.drawLine(x, 10, x, 61, DOTTED, FORCE)
	end

	for iLine = 1, math.min(6, #namedChs - firstLine + 1) do		
		local iNamed = iLine + firstLine - 1
		local iCh = namedChs[iNamed]
		local out = model.getOutput(iCh - 1)
		local x0 = CENTER + SCALE * out.offset
		local x1 = CENTER + SCALE * out.min
		local x2 = CENTER + SCALE * out.max
		local y0 = 5 + 8 * iLine

		-- Drawing attributes for blinking etc.
		local attName = 0
		local attCh = 0
		local attDir = 0
		local attCtr = 0
		local attLwr = 0
		local attUpr = 0
		
		if selection == iNamed then
			attName = INVERS
			if editing == 1 then
				attCh = INVERS
			elseif editing == 2 then
				attDir = INVERS
			elseif editing == 3 then
				attCtr = INVERS
				attLwr = INVERS
				attUpr = INVERS
			elseif editing == 4 then
				attLwr = INVERS
				attUpr = INVERS
			elseif editing == 5 then
				attLwr = INVERS
			elseif editing == 6 then
				attCtr = INVERS
			elseif editing == 7 then
				attUpr = INVERS
			elseif editing == 11 then
				attCh = INVERS + BLINK
			elseif editing == 13 then
				attCtr = INVERS + BLINK
				attLwr = INVERS + BLINK
				attUpr = INVERS + BLINK
			elseif editing == 14 then
				attLwr = INVERS + BLINK
				attUpr = INVERS + BLINK
			elseif editing == 15 then
				attLwr = INVERS + BLINK
			elseif editing == 16 then
				attCtr = INVERS + BLINK
			elseif editing == 17 then
				attUpr = INVERS + BLINK
			end
		end

		-- Draw channel no. and name
		lcd.drawNumber(XDOT, y0, iCh, SMLSIZE + RIGHT + attCh)
		lcd.drawText(XDOT + 4, y0, out.name, SMLSIZE + attName)
		lcd.drawText(XDOT, y0, ".", SMLSIZE)
		
		-- Channel direction indicator
		if out.revert == 1 then
			lcd.drawText(XREV, y0, "<", SMLSIZE + attDir)
		else
			lcd.drawText(XREV, y0, ">", SMLSIZE + attDir)
		end

		-- Draw markers
		if bit32.btest(attCtr, BLINK) then
			local xx = 2
			if out.offset < 0 then xx = -1 end
			lcd.drawNumber(x0 + xx, y0 + 4, out.offset, PREC1 + SMLSIZE)
		end
		lcd.drawText(x0, y0, "|", SMLSIZE + attCtr)
		
		if bit32.btest(attLwr, BLINK) then
			local xx = 2
			if out.min < 0 then xx = -1 end
			lcd.drawNumber(x1 + xx, y0 + 4, out.min, PREC1 + SMLSIZE)
		end
		lcd.drawText(x1, y0, "|", SMLSIZE + attLwr)
		
		if bit32.btest(attUpr, BLINK) then
			lcd.drawNumber(x2 - 1, y0 + 4, out.max, PREC1 + SMLSIZE + RIGHT)
		end
		lcd.drawText(x2, y0, "|", SMLSIZE + attUpr)

		-- Draw horizontal channel range lines
		lcd.drawLine(x1, y0 + 2, x2, y0 + 2, SOLID, FORCE)
		lcd.drawLine(x1, y0 + 3, x2, y0 + 3, SOLID, FORCE)
		
		-- And current position inducator
		x0 = getValue(srcBase + iCh)
		if x0 >= 0 then
			x0 = out.offset + math.min(x0, 1024) * (out.max - out.offset) / 1024 
		else
			x0 = out.offset + math.max(x0, -1024) * (out.offset - out.min) / 1024 
		end

		x0 = CENTER + SCALE * x0
		lcd.drawLine(x0, y0 + 1, x0, y0 + 1, SOLID, FORCE)
		lcd.drawLine(x0 - 1, y0, x0 + 1, y0, SOLID, FORCE)
		lcd.drawLine(x0 - 2, y0 - 1, x0 + 2, y0 - 1, SOLID, FORCE)
	end
end

-- Adjust all three based on Center or Range deltas
local function AdjCtrRng(out, dCtr, dRng)
	local lwr = out.min
	local ctr = out.offset
	local upr = out.max
	local rng = (upr - lwr) / 2
	local dMax -- Avoid big jumps of upper and lower points
	
	-- Adjust deltas to avoid exceeding constraints
	if dCtr ~= 0 then
		if dCtr > 0 then
			dCtr = math.max(0, math.min(MAXOUT - MINDIF - ctr, dCtr))
		else
			dCtr = math.min(0, math.max(-MAXOUT + MINDIF - ctr, dCtr))
		end
		
		ctr = ctr + dCtr
		dMax = 2 * math.abs(dCtr)
		
		-- Adjust range if one endpoint is close to the limit
		if upr >= MAXOUT - dMax or lwr <= -MAXOUT + dMax then
			dRng = math.min(1000, MAXOUT - math.abs(ctr)) - rng
		end
	else -- dRng ~= 0
		dMax = 2 * math.abs(dRng)

		if dRng > 0 then
			dRng = math.max(0, math.min(MAXOUT - upr, lwr + MAXOUT, dRng))
		else
			dRng = math.min(0, math.max(MINDIF - rng, dRng))
		end
	end
	
	if dCtr == 0 and dRng == 0 then
		playTone(3000, 100, 0, PLAY_NOW)
	else
		rng = rng + dRng
		out.offset = ctr
		
		-- For endpoints, aim for symmetry, and then limit deltas
		out.min = math.max(-dMax, math.min(dMax, ctr - rng - lwr)) + lwr
		out.max = math.max(-dMax, math.min(dMax, ctr + rng - upr)) + upr
	end
	
	model.setOutput(namedChs[selection] - 1, out)
 end -- AdjCtrRng()

local function run(event)
	if stage == 1 then
		if event == EVT_ENTER_BREAK then
			stage = 2
		end
	elseif stage == 2 then
		local iCh
		local out
	
		if editing > 1 then
			iCh = namedChs[selection]
			out = model.getOutput(iCh - 1)
		end
		
		-- Handle key events
		if editing == 0 then
			-- No editing; move channel selection
			if event == EVT_EXIT_BREAK then
				return true -- Quit
			elseif event == EVT_ENTER_BREAK then
				editing = 1
			elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_PLUS_REPT then
				if selection == 1 then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					selection = selection - 1
				end
			elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_MINUS_REPT then
				if selection == #namedChs then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					selection = selection + 1
				end
			end
		elseif editing == 2 then
			-- Editing direction
			if event == EVT_ENTER_BREAK then
				out.revert = 1 - out.revert
				model.setOutput(iCh - 1, out)
			elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT then
				editing = 1
			elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT then
				editing = 3
			elseif event == EVT_EXIT_BREAK then
				editing = 0
			end
		elseif editing == 1 or (editing >= 3 and editing <= 7) then
			-- Item(s) selected, but not edited
			if event == EVT_ENTER_BREAK then
				-- Start editing
				editing = editing + 10
			elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT then
				editing = editing - 1
				if editing < 1 then editing = 7 end
			elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT then
				editing = editing + 1
				if editing > 7 then editing = 1 end
			elseif event == EVT_EXIT_BREAK then
				editing = 0
			end
		elseif editing == 11 then
			-- Channel number edited
			if event == EVT_ENTER_BREAK or event == EVT_EXIT_BREAK then
				editing = 1
			elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_PLUS_REPT then
				return MoveSelected(-1)
			elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_MINUS_REPT then
				return MoveSelected(1)
			end
		elseif editing == 13 then
			-- Lower, Center, Upper edited
			if event == EVT_ENTER_BREAK or event == EVT_EXIT_BREAK then
				editing = 3
			elseif event == EVT_PLUS_BREAK then
				AdjCtrRng(out, 1, 0)
			elseif event == EVT_PLUS_REPT or event == EVT_ROT_RIGHT then
				AdjCtrRng(out, 10, 0)
			elseif event == EVT_MINUS_BREAK then
				AdjCtrRng(out, -1, 0)
			elseif event == EVT_MINUS_REPT or event == EVT_ROT_LEFT then
				AdjCtrRng(out, -10, 0)
			end
		elseif editing == 14 then
			-- Channel range edited
			if event == EVT_ENTER_BREAK or event == EVT_EXIT_BREAK then
				editing = 4
			elseif event == EVT_PLUS_BREAK then
				AdjCtrRng(out, 0, 1)
			elseif event == EVT_PLUS_REPT or event == EVT_ROT_RIGHT then
				AdjCtrRng(out, 0, 10)
			elseif event == EVT_MINUS_BREAK then
				AdjCtrRng(out, 0, -1)
			elseif event == EVT_MINUS_REPT or event == EVT_ROT_LEFT then
				AdjCtrRng(out, 0, -10)
			end
		elseif editing >= 15 and editing <= 17 then
			-- One value edited
			local delta = 0
			
			if event == EVT_ENTER_BREAK or event == EVT_EXIT_BREAK then
				editing = editing - 10
			elseif event == EVT_PLUS_BREAK then
				delta = 1
			elseif event == EVT_PLUS_REPT or event == EVT_ROT_RIGHT then
				delta = 10
			elseif event == EVT_MINUS_BREAK then
				delta = -1
			elseif event == EVT_MINUS_REPT or event == EVT_ROT_LEFT then
				delta = -10
			end
			
			if editing == 15 then
				out.min = math.max(-MAXOUT, math.min(0, out.offset - 100, out.min + delta))
			elseif editing == 16 then
				out.offset = math.max(out.min + 100, math.min(out.max - 100, out.offset + delta))
			else
				out.max = math.min(MAXOUT, math.max(0, out.offset + 100, out.max + delta))
			end

			model.setOutput(iCh - 1, out)
		end

		-- Scroll if necessary
		if selection < firstLine then
			firstLine = selection
		elseif selection - firstLine > 5 then
			firstLine = selection - 5
		end
	end

	-- Update the screen
	if stage == 1 then
		DrawMenu(" Warning! ")

		lcd.drawText(XTXT, 15, "Disconnect the motor!", ATT1)
		lcd.drawText(XTXT, 30, "Sudden spikes may occur", ATT2)
		lcd.drawText(XTXT, 40, "when channels are moved.", ATT2)
		lcd.drawText(XTXT, 50, "Press ENTER to proceed.", ATT2)
	else
		Draw()
	end
end

return {init = init, run = run}