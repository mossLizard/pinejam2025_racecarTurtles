-- CONFIGURATION REQUIRED!!!!!

-- add as many 1x1 monitors as you have connected
--   direction: the direction the player should be facing when looking at / using the monitor
-- in this example, I have a tower in the middle of the track with monitors on all 4 sides,
--   plus 1 extra monitor on top of the control computer
local monis = {
  ["monitor_0"] = { ["direction"] = "north" },
  ["monitor_1"] = { ["direction"] = "west" },
  ["monitor_2"] = { ["direction"] = "south" },
  ["monitor_3"] = { ["direction"] = "east" },
  ["top"] = { ["direction"] = "east" }
}

-- name of wireless modem (can be side)
local modem = "modem_0"
-- frequency to use when communicating with the turtles
-- change as needed, but change racercar.lua to match!
local modemFreq = 201

-- END CONFIGURATION

serl = textutils.serializeJSON
usrl = textutils.unserializeJSON
modem = peripheral.wrap(modem)
modem.open(modemFreq)

local messageQueue = {}

players = {}
-- id: id sent to turtle
-- velocity: {x,y}
-- color: wool color it started on
-- crashed: true if crashed (skip turn and set false)


local isAnyColor = false
for k,v in pairs(monis) do
  thisMoni = peripheral.wrap(k)
  if thisMoni ~= nil then
    monis[k]["peri"] = thisMoni
    monis[k]["isColor"] = monis[k].peri.isColor()
    isAnyColor = isAnyColor or monis[k]["isColor"]
  else
    print(" CAUTION: monitor '"..k.."' defined but not attached!")
	monis[k] = nil
  end
end
if not isAnyColor then
  print(" WARNING: You have no advanced monitors defined!")
  print(" You will not be able to control the turtles!")
end

local helpScreen = false
local helpPage = 1
inputs = {}

function setColor(moni,f,b)
  moni.setTextColor(2^f)
  moni.setBackgroundColor(2^b)
end
function swapColors(moni, condition)
  if condition == nil or condition then
    f,b = moni.getTextColor(),moni.getBackgroundColor()
    moni.setTextColor(b)
    moni.setBackgroundColor(f)
  end
end
function cmpsColor(index)
  index = math.mod(index+7,8)+1
  --local tmp = {3,13,6, 1,11,5 ,14,4}
  local tmp = {6,14,1,4,5,9,11,10}
  return tmp[index]
end

local directionMapping = {["south"]=1,["west"]=3,["north"]=5,["east"]=7}
local canAcceptDirInput = true
local listenType = "none"
local doListen = false -- set when waiting for turtle to send message
local playerTurn = 2




function cmpsLttr(index) -- least favorite function in the program but it works
  local dirLoop = {"N","NE","E","SE","S","SW","W","NW"} 
  return dirLoop[math.mod(index+3,8)+1]
end

function handleCompassButton(event, pbtn, ibtn) 
  local moniName = event[2]
  local moniDirection = monis[moniName]["direction"]
  --print(moniDirection)
  moniDirection = directionMapping[moniDirection]
  calcDir = math.mod(pbtn + 6 + moniDirection,8)+1
  canAcceptDirInput = false
  needRedraw = true
  return cmpsLttr(calcDir)
end

function scanButtons(event, buttons) -- I like this function even if it is a little jank. I'll have to use it more in the future
  --[[ BUTTON FORMAT:
    { 
	button x, button y, button width, button height,
	function to run when clicked,
	extra parameter to pass to the function (I probably just use separate functions or rely on button index, but this is more interesting)
	}
	FUNCTION PARAMETERS:
	( 
	the click event in its entirety,
	the extra paramater,
	the index of the button clicked (don't rely on this!)
	)
  --]]
  for ibtn, bttn in ipairs(buttons) do
    if (event[3] >= bttn[1] and event[3] < bttn[1] + bttn[3] 
	and event[4] >= bttn[2] and event[4] < bttn[2] + bttn[4] ) then
	  return ibtn, bttn[5](event, bttn[6], ibtn)
	  -- lua just lets me put a function in a table.
	  -- cursed. I love it.
	end
  end
  return 0 --no button pressed
end
function scanCompassButtons(event)
   local compassButtons = {
    {3,2,3,1,handleCompassButton,8},{7,2,3,1,handleCompassButton,1},{11,2,3,1,handleCompassButton,2},
	{3,4,3,1,handleCompassButton,7},{7,4,3,1,handleCompassButton,0},{11,4,3,1,handleCompassButton,3},
	{3,6,3,1,handleCompassButton,6},{7,6,3,1,handleCompassButton,5},{11,6,3,1,handleCompassButton,4}
	} -- x, y, w, h, function, param
		  -- function(event, param, ibtn)
	return scanButtons(event,compassButtons)
  --print(serl({scanButtons(event,compassButtons)}))
end



-- thar she blows!!!! (pointing at yet another timer event)
function wrangleInputs()
  for i,event in ipairs(inputs) do
    if event[1] == "modem_message" then
	  --message = usrl(event[5])
	  message = event[5]
	  print(serl(message))
	  if message.class == "getId" then
	    print("adding player")
	    -- add new player
		local plyr = {
		  ["id"] = #players + 1,
		  ["velocity"] = {0,0},
		  ["crashed"] = false
		}
		messageQueue[#messageQueue+1] = {
		  ["class"] = "setId", ["target"] = -1,
		  ["payload"] = plyr.id
		}
		players[#players + 1] = plyr
		print(serl(players))
	  end
    elseif event[1] == "monitor_touch" then
	  print(textutils.serializeJSON(event))
	  if helpScreen then 
	    print("helpScreen")
		if helpPage < 7 then
		  helpPage = helpPage + 1
		  needRedraw = true
		else
		  helpScreen = false
		  helpPage = 1
		  needRedraw = true
		end
		
	  else
	    if canAcceptDirInput then
	      scanCompassButtons(event)
		end
		local helpButton = {{13,1,3,1,function() helpScreen = true; needRedraw = true end}}
		scanButtons(event,helpButton)
	  end
	end
  end
end

function sendMessages()
  for i,v in ipairs(messageQueue) do -- needs to be on a separate tick I think
    modem.transmit(modemFreq,modemFreq,v)
	print(" MESSAGE", serl(v))
  end
  messageQueue = {}
end

function drawHelpPage(moni, page)
  local helpText = {
                    {" HELP    [1/7] "," Gather friends","and dig 1 block","deep canyon in ","the dirt. Place",
					 "colored wool at","the start and  ","white / black  ","wool across the","finish line.   "},
                    {" HELP    [2/7] ","Put racecar.lua"," on 2-8 turtles","w/ modems. Put ","this prog. on a",
					 "computer w/ mod","-em and monitor","facing track.  ","Edit prog. to  ","define monitors"},
                    {" HELP    [3/7] "," Place turtles ","on start line. "," Press [PAIR]  ","on computer,   ",
					"then [PAIR] on ","turtles. Use the","computer to    ","finish setup, ","press [START]   "},
					{" HELP    [4/7] "," Each turn, you","may ACCELERATE ","N/S/E/W or dia","-gonally; click ",
					 "the compass on ","your turn.     ","Your turtle's  ","VELOCITY will  ","be changed.    "},
					{" HELP    [5/7] "," If you hit a  ","wall, you crash","and you lose a ","turn and all of",
					 "your velocity! ","Winner is first","turtle ending  ","its turn on the","finish line!   "},
                    {" HELP    [6/7] "," Controls on   ","turtles & the  ","main computer  ","are for DEBUG /",
					 "FIX PURPOSES   ","ONLY! Not part ","of the game!   ","               ","               "},
					{" HELP    [7/7] ","'Racecar' is   ","traditionally  ","played on graph","paper; In this ",
					 "land of integer","coordinates,   ","the very world ","is our canvas! ","          -moss"}
				 }
  for i,v in ipairs(helpText[page]) do
    moni.setCursorPos(1,i)
	moni.write(v)
  end
end


function drawCompass(moni, direction)
  local testImg = {
    "+--RACECAR--[?]",
    "|  __ ___ __  |",
    "|    \\ | /    |",
    "| ___- @ -___ |",
    "|    / | \\    |",
    "|  __ ___ __  |",
    "Player 1's turn",
    "Ready For Accel",
    " 3m N,    4m E ",
    "Round 04 Turn 3"}
  --moni.write(cmpsLttr(dirOfset))
  -- Draw frame in white
  local dirOfset = directionMapping[direction]-1
  setColor(moni,0,15)
  for i = 1, 10 do
    moni.setCursorPos(1,i)
    moni.write(testImg[i])
  end
  local compassArray = {
    {{3,1,0},{7,1,1},{11,0,2}},
	{{3,1,7},{11,1,3}},
	{{3,1,6},{7,1,5},{11,0,4}}
  }
  local row = 0
  for i,v in ipairs(compassArray) do
    row = row + 2
	for j,jv in ipairs(v) do
      setColor(moni,15,cmpsColor(jv[3]+dirOfset))
	  local label = cmpsLttr(jv[3]+dirOfset)
	  local padding = string.rep(" ",jv[2])
	  swapColors(moni, not canAcceptDirInput)
	  moni.setCursorPos(jv[1],row)
	  moni.write("   ")
	  moni.setCursorPos(jv[1],row)
	  moni.write(padding..label)
	end
  end
  setColor(moni,15,0)
  moni.setCursorPos(7,4)
  moni.write(" @ ")
  setColor(moni,15,3)
  moni.setCursorPos(13,1)
  moni.write("[?]")
end

function interval()
  sleep(0.15)
end
function getInputs()
  inputs = {}
  while #inputs <= 255 do
    local event = {os.pullEvent()}
	inputs[#inputs + 1] = event
  end
end

function printPlayerList()
  term.setCursorPos(1,1)
  setColor(term,0,15)
  term.clear()
  term.write(
  for i,player in ipairs(players) do
    if i == playerTurn then setColor(term,15,0) else setColor(term,0,15) end
    term.setCursorPos(2,(i*2)+1)
	term.write(string.format("%3.3s %+2.2dx %+2.2dy %5.5s", player.id, player.velocity[1], player.velocity[2], player.crashed))
	term.write(" [TEST] [MY TURN] [DELETE]")
	
  end
  
end



doLoop = true
needRedraw = true
needReprint = true

function main()
  while doLoop do
    parallel.waitForAny(interval, getInputs)
	sendMessages()
	wrangleInputs()
	if needRedraw then
	  if helpScreen then
	    for k,v in pairs(monis) do
          v.peri.setTextScale(0.5)
          setColor(v.peri,0,15)
          v.peri.clear()
          drawHelpPage(v.peri, helpPage)
		end
	  else
	    needRedraw = false
	    for k,v in pairs(monis) do
          v.peri.setTextScale(0.5)
          setColor(v.peri,0,15)
          v.peri.clear()
          drawCompass(v.peri, v.direction)
		end
      end
	end
	if needReprint then
	  printPlayerList()
	end
  end
end
main()