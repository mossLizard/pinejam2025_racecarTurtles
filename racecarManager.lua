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
-- name: silly names



-- DELIVER US:
-- c-t class     action                 payload
-- <-- getId     add me to player list  none
-- --> setId     set this as player id  id
-- --> clearId   removed from players   none
-- --> yourTurn  do move turtle up      none
-- --> cancel    go back down sorry     none
-- --> startMove do move turtle line    accel vector
-- <-- endMove   do input enable        new velocity, crashed
print("starting...")
sleep(1)
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
sleep(2)
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
local canAcceptDirInput = false
local listenType = "none"
local doListen = false -- set when waiting for turtle to send message
local playerTurn = 0

function advanceTurn(nextTurn)
  nextTurn = nextTurn or math.mod(playerTurn, #players)+1
  --print(nextTurn)
  if players[nextTurn]['crashed'] then
    players[nextTurn]['crashed'] = false
	advanceTurn(math.mod(nextTurn, #players)+1)
  else
    enqueueMessage(
    {['target'] = players[nextTurn]['id'],
	 ['class'] = 'yourTurn'})
    playerTurn = nextTurn
    canAcceptDirInput = true
    listenType = "none"
    doListen = false
  end
  
end

function startGame()
  canAcceptDirInput = true
  needRedraw = true
  needReprint = true
  advanceTurn(1)
end



function cmpsLttr(index)
  local dirLoop = {"N","NE","E","SE","S","SW","W","NW"} 
  return dirLoop[math.mod(index+3,8)+1] -- too many magic numbers...
end

function cmpsAccelVector(index) -- least favorite function in the program but it works. probably.
  local vecLoop = {{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1}} 
  return vecLoop[math.mod(index+3,8)+1]
end

function handleCompassButton(event, pbtn, ibtn) 
  local moniName = event[2]
  local moniDirection = monis[moniName]["direction"]
  moniDirection = directionMapping[moniDirection]
  local resultLetter = "0"
  local resultVector = {0,0}
  local calcDir = math.mod(pbtn + 6 + moniDirection,8)+1
  if pbtn ~= 0 then
    resultLetter = cmpsLttr(calcDir)
	resultVector = cmpsAccelVector(calcDir)
  end
  --print(moniDirection)
  if playerTurn > 0 and canAcceptDirInput then
    canAcceptDirInput = false
    enqueueMessage({ 
	['class'] = "startMove",
	['target'] = players[playerTurn]["id"],
	['payload'] = resultVector
	})
    needRedraw = true
    listenFor("endMove")
  end
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

function skipToTurn(event,param,ibtn)
  if canAcceptDirInput then advanceTurn(param) end
  needRedraw = true
end

function scanCompassButtons(event)
  -- random indent to ruin youw day :3
   local compassButtons = {
    {3,2,3,1,handleCompassButton,8},{7,2,3,1,handleCompassButton,1},{11,2,3,1,handleCompassButton,2},
	{3,4,3,1,handleCompassButton,7},{7,4,3,1,handleCompassButton,0},{11,4,3,1,handleCompassButton,3},
	{3,6,3,1,handleCompassButton,6},{7,6,3,1,handleCompassButton,5},{11,6,3,1,handleCompassButton,4}
	} -- x, y, w, h, function, param
		  -- function(event, param, ibtn)
	return scanButtons(event,compassButtons)
  --print(serl({scanButtons(event,compassButtons)}))
end
function scanPlayerListButtons(event)
  sto = {}
  local staticButtons = {
    {14,1,7,1,startGame,0}
  }
  sto[1] = scanButtons(event,staticButtons)
  for i,plyr in ipairs(players) do
   local playerButtons = {
    {3,(i*2)+2,10,1,setPlayerName,i},
	{14,(i*2)+2,9,1,skipToTurn,i}
	}
		  -- function(event, param, ibtn)
	sto[i+1] = scanButtons(event,playerButtons)
  end
  return sto
end

function setPlayerName(event, param, ibtn)
  term.setCursorPos(3,(param*2)+2)
  term.write(" name? >")
  players[param]["name"] = read()
end

function nextListen(message) -- advances listening state if needed
  if listenType == "none" then return 0 end
  payload = message.payload
  if listenType == "start" then -- I'm using listenType to delay messages now! ANARCHY!!
    enqueueMessage({
		  ["class"] = "yourTurn", 
		  ["target"] = 1
		})
	  listenType = "none"
	  doListen = false
  elseif listenType == "endMove" then
    players[playerTurn]["velocity"] = payload[1]
	players[playerTurn]['crashed'] = payload[2] == -1
	needRedraw = true
	needReprint = true
	advanceTurn()
  end
end

function listenFor(class) -- just in case I need more lines
  listenType = class
end


-- thar she blows!!!! (pointing at yet another timer event)
function wrangleInputs()
  for i,event in ipairs(inputs) do
    if event[1] == "modem_message" then
	  --message = usrl(event[5])
	  message = event[5]
	  --print(serl(message))
	  if message.class == "getId" then
	    print("adding player")
		needReprint = true
		needRedraw = true -- in case this is the first player
	    -- add new player
		local plyr = {
		  ["id"] = #players + 1,
		  ["velocity"] = {0,0},
		  ["crashed"] = false,
		  ["name"] = "Player ".. (#players+1)
		}
		enqueueMessage({
		  ["class"] = "setId", ["target"] = -1,
		  ["payload"] = plyr.id
		})
		players[#players + 1] = plyr
		--print(serl(players))
	  elseif message.class == listenType then
	    nextListen(message)
	  end
	elseif event[1] == "mouse_click" then
	  needReprint = true
	  scanPlayerListButtons(event)
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
		local helpButton = {{13,1,3,1,function() helpScreen = true; needRedraw = true end}}
		scanButtons(event,helpButton) -- too lazy to make this its own function 
	  end
	end
  end
end

function sendMessages()
  for i,v in ipairs(messageQueue) do -- needs to be on a separate tick I think
    modem.transmit(modemFreq,modemFreq,v)
	--print("  SENT:", serl(v))
  end
  messageQueue = {}
end
function enqueueMessage(message)
  messageQueue[#messageQueue+1] = message
end

function drawHelpPage(moni, page)
  local helpText = {
                    {" HELP    [1/7] "," Gather friends","and dig 1 block","deep canyon in ","the dirt. Place",
					 "colored wool at","the start and  ","white / black  ","wool across the","finish line.   "},
                    {" HELP    [2/7] ","Put racecar.lua"," on 2-8 turtles","w/ modems. Put ","this prog. on a",
					 "computer w/ mod","-em and monitor","facing track.  ","Edit prog. to  ","define monitors"},
                    {" HELP    [3/7] "," Place turtles ","on start line  ","FACING NORTH!  ","start computer.",
					"press [PAIR] on ","turtles, then  ","use computer to","finish setup.  ","Press [START]  "},
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

function generateCompassImage()
  local sto = {
    "+--RACECAR--[?]",
    "|  __ ___ __  |",
    "|    \\ | /    |",
    "| ___- @ -___ |",
    "|    / | \\    |",
    "|  __ ___ __  |",
    "+-------------+",
    "               ",
	"!ERROR!        ",
    "No players!    "}
	if #players == 0 then
	  return sto -- default with no players
	end
	if playerTurn == 0 then
	  sto[10] = "Game ready!    "
	  return sto
	end
	
	if canAcceptDirInput then
	  sto[10] = "Ready For Input"
	elseif listenType == "startMove" then
	  sto[10] = "Telling Turtle..."
	elseif listenType == "endMove" then
	  sto[10] = "Moving .........."
	elseif listenType == "endTurn" then
	  sto[10] = "Passing turn....."
	else
	  sto[10] = "Mystery Status!!!"
	end
	sto[9] = string.format("%15.15s",players[playerTurn]["name"])
	sto[8] = string.format(" %+3.3sN,    %+3.3sE ",players[playerTurn]["velocity"][2]*-1,players[playerTurn]["velocity"][1])
  return sto 
end

function drawCompass(moni, direction)
  local compassImage = generateCompassImage()
  --moni.write(cmpsLttr(dirOfset))
  -- Draw frame in white
  local dirOfset = directionMapping[direction]-1
  setColor(moni,0,15)
  for i = 1, 10 do
    moni.setCursorPos(1,i)
    moni.write(compassImage[i])
  end
  local compassArray = {
    {{3,1,0},{7,1,1},{11,0,2}},
	{{3,1,7},{11,1,3}},
	{{3,1,6},{7,1,5},{11,0,4}}
  } -- I love me some magic numbers
    -- {x position, left padding, direction ofset}
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
  term.write(" PLAYERS:    [START]" )
  for i,player in ipairs(players) do
    if i == playerTurn then setColor(term,15,0) else setColor(term,0,15) end
    term.setCursorPos(2,(i*2)+1)
	term.write(string.format("%3.3s %+2.2dx %+2.2dy %5.5s, %s", player.id, player.velocity[1], player.velocity[2], player.crashed, player.name))
    term.setCursorPos(2,(i*2)+2)
	term.write(" [SET NAME] [MY TURN]")
	
  end
  
end



doLoop = true
needRedraw = true
needReprint = true

function main()
  while doLoop do
	sendMessages()
    parallel.waitForAny(interval, getInputs)
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
	  needReprint = false
	end
  end
end
main()
