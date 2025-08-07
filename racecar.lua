
modemFreq = 201

-- END CONFIGURATION

modem = peripheral.wrap("left") or peripheral.wrap("right")
modem.closeAll()
modem.open(modemFreq)

testImage = {
  " Racecar!----------------------------- ",
  "                                       ",
  " Modem  ######  [SYNC] ### ########### ",
  "                                       ",
  " Posit      X##### Z#####   #####      ",
  "                                       ",
  " Veloc  [-] X+## [+] [@] [-] Z+## [+]  ",
  "                                       ",
  " pineJam2025                      moss "
}
local msgTestMode = true

racerId = -1

serl = textutils.serializeJSON
usrl = textutils.unserializeJSON

local listenClass = ""
local doListen = false -- waiting for control computer to send message

local messageQueue = {}
function sendMessages()
  for i,v in ipairs(messageQueue) do
    modem.transmit(modemFreq,modemFreq,v)
  end
  messageQueue = {}
end
function enqueueMessage(message)
  messageQueue[#messageQueue+1] = message
end


-- MOVEMENT

local storedX, storedY, storedZ = 0,0,0
local velX, velZ = 0,0
local storedDirection = "north"
-- east = +x, south = +z
local movementQueue = {} -- move instructions for reckon() to execute

function dirToVec(direction)
  local mapping = { -- not copying my code from the other one for. reasons.
    ['north'] = {0,-1},
    ['east']  = {1, 0},
    ['south'] = {0, 1},
    ['west']  = {-1,0},
  }
  return mapping[direction]
end

function reckon()
  -- moves (or doesn't) and updates stored X Y Z & direction
  -- I COULD use GPS to get position. That would be smart.
  --   but that would involve somehow waiting for GPS while 
  --   also listening to other computers in a single program
  --   and I'm too tired to be smart right now.
  --   so. I'm doing this the Olde Fashioned Way
  hasCrashed = false
  for i,order in ipairs(movementQueue) do
    --reckonResult = reckon(v)
	--moveResult = {moveTypes[order]()}
	if order == "f" then
	  result = {turtle.forward()}
	  hasCrashed = hasCrashed or (not result[1])
	  if result[1] then 
	    local ofset = dirToVec(storedDirection)
		storedX = storedX + ofset[1]
		storedZ = storedZ + ofset[1]
	  end
	elseif order == "l" then
	  result = {turtle.turnLeft()}
	  hasCrashed = hasCrashed or (not result[1]) -- shouldn't be able to fail but just for completeness
	  storedDirection = simTurnDirection(storedDirection,"l")
	elseif order == "r" then
	  result = {turtle.turnRight()}
	  hasCrashed = hasCrashed or (not result[1])
	  storedDirection = simTurnDirection(storedDirection,"r")
    end
	if hasCrashed then break end
	sleep(0.5)
  end
  if hasCrashed then return -1 end
  --  0: okay!
  -- -1: crashed (wall)
  -- -2: crashed 2 (for when I have proper collision checking)
  -- -3: no fuel
  return 0
end

function simTurnDirection(startingDir, turnDir) -- I change my mind, THIS is my least favorite function in EITHER program
  turnOfset = 0
  if turnDir == "r" then turnOfset = 2
  elseif turnDir == "l" then turnOfset = -2
  end
  local directionMapping = {["south"]=1,["west"]=3,["north"]=5,["east"]=7}
  local directionUnmapping = {"south",nil,"west",nil,"north",nil,"east"}
  oldIndex = directionMapping[startingDir]
  newIndex = math.mod(oldIndex+turnOfset+7,8)+1
  return directionUnmapping[newIndex]
end

--print(turnDirection("north","r"),turnDirection("east","r"),turnDirection("south","l"))
-- AND YET IT WORKS
-- I hate it


function addRotates(newDirection)
  -- adds the necesary moves to turn to a specific direction to the movementQueue
  -- returns number of moves added, list of moves added
  if newDirection == storedDirection then return 0, {} end
  local directionMapping = {["south"]=1,["west"]=3,["north"]=5,["east"]=7}
  local mapS = directionMapping[storedDirection]
  local mapN = directionMapping[newDirection]
  local isReverse = (math.abs(mapN - mapS) == 4) -- programming is my passion
  local toAdd = {}
  if isReverse then -- turn around
    toAdd = {"r","r"} -- not an ambiturner
  elseif (mapN - mapS) == -2 or (mapN - mapS) == 6 then -- turn left
    toAdd = {"l"}
  else --if (mapN - mapS) == -2 or (mapN - mapS) == 6 then -- turn right
    toAdd = {"r"}
  end
  for i,v in ipairs(toAdd) do -- this is a little overkill for this situation but shhhhhh
    movementQueue[#movementQueue+1] = v
  end
  return #toAdd, toAdd
end

function addMoves(x,z)
  local newDirection = ""
  local majorAxis, minorAxis = 0,0 -- distance to the target the longer and shorter axes
  -- sign of minor axis indicates left (-) or right (+)
  local minorOfset = 0 -- amount to move for each step along the major axis
  -- I know this is terminology normally used for elipses but I can't remember the real names so uhhhhhhhhh
   -- I don't have the energy to fix this random indent. SUFFER!!!!!
    if math.abs(z) > math.abs(x) then
	  if z >= 0 then
	    newDirection = "south"
		majorAxis, minorAxis = z, -x
		-- x ofset in - direction = right = + minorAxis
		-- x ofset in + direction = left = - minorAxis
	  else
	    newDirection = "north"
		majorAxis, minorAxis = -z, x 
		-- x ofset in - direction = left = - minorAxis
		-- x ofset in + direction = right = + minorAxis
	  end
	else
	  if x >= 0 then
	    newDirection = "east"
		majorAxis, minorAxis = x, z
	  else
	    newDirection = "west"
		majorAxis, minorAxis = -x, -z
	  end
	end
	addRotates(newDirection)
	minorOfset = math.abs(minorAxis / majorAxis)
	local toAdd = {}
	local acc = 0
	local accStep = 0
    local turnDirs = {"l","r"}
	if minorAxis > 0 then
	  turnDirs = {"r","l"}
	end
    for moveStep = 1, math.abs(majorAxis) do
	  toAdd[#toAdd+1] = "f"
	  acc = acc + minorOfset
	  if math.floor(acc) > accStep then -- for diagonal movement
	    toAdd[#toAdd+1] = turnDirs[1]
		toAdd[#toAdd+1] = "f"
	    toAdd[#toAdd+1] = turnDirs[2]
		accStep = math.floor(acc)
	  end
	end
  for i,v in ipairs(toAdd) do
    movementQueue[#movementQueue+1] = v
  end
  return #toAdd, toAdd
end

function bigOlMovementFunction()
  addMoves(velX, velZ)
  reckonResult = reckon()
  movementQueue = {}
  if reckonResult == -1 then
    velX = 0
	velZ = 0
  end
  movementQueue = {}
  return reckonResult
end

function incVelX(event,param,ibtn)
  velX = velX + param
end

function incVelZ(event,param,ibtn)
  velZ = velZ + param
end






function interval()
  sleep(0.1)
end
function getInputs()
  inputs = {}
  while #inputs <= 255 do
    local event = {os.pullEvent()}
	inputs[#inputs + 1] = event
  end
end
function wrangleInputs()
  for i,event in ipairs(inputs) do
    if event[1] == "modem_message" and doListen then
	  message = event[5]
	  if message.target == racerId  and message.class == listenClass then
	    if message.class == "setId" then
		  racerId = message.payload
		  listenClass = "yourTurn"
		  doListen = true
		elseif message.class == "yourTurn" then
		  if not msgTestMode then
		  end
		  listenClass = "startMove"
		elseif message.class == "startMove" then
		  accel = message.payload
		  velX = velX + accel[1]
		  velZ = velZ + accel[2]
		  movementResult = bigOlMovementFunction()
		  enqueueMessage({ 
		  ['class'] = "endMove",
		  ['payload'] = {{velX, velZ},movementResult}
		  })
		  if movementResult == -1 then
		    movementQueue = {"r","r","r","r"}
			reckon() -- spinout animation to indicate crashing
			movementQueue = {}
		  end
		end
	  end
    elseif event[1] == "mouse_click" then
	  buttons =  {
	    {17,3,6,1,startSync,0},
	    {9,7,3,1,incVelX,-1},{18,7,3,1,incVelX,1},{22,7,3,1,bigOlMovementFunction,0},
	    {26,7,3,1,incVelZ,-1},{35,7,3,1,incVelZ,1}
	    }
	  print(serl(event),scanButtons(event, buttons))
	  --sleep(0.2)
	end
  end
end


function startSync(event, param, index) -- send message requesting an ID
  -- will blindly accept the next setId message that comes in which is a bad way to do it but whateverrrrrr it's fiiiiine perfect is the enemy of done
  -- actually you know what. no. intentional backdoor
  -- feel free to use this information to hack this... super high priority protected turtle race.... I guess..?
  racerId = -1
  modem.transmit(modemFreq, modemFreq,
    {["class"] = "getId"}
  )
  doListen = true
  listenClass = "setId"
end


function drawPanel()
  term.setTextColor(1)
  term.setBackgroundColor(2^15)
  term.clear()
  for i=1, #testImage do
    term.setCursorPos(1,i)
    term.write(testImage[i])
  end
  drawList = { {9,3,6,modemFreq}, {24,3,3,racerId}, {28,3,11,listenClass},
  {14,5,5,storedX}, {21,5,5,storedZ}, {28,5,6,storedDirection},
  {14,7,3,velX}, {31,7,3,velZ}
  }
  term.setTextColor(2^15)
  term.setBackgroundColor(2^8)
  for i,v in ipairs(drawList) do
    term.setCursorPos(v[1],v[2])
	term.write( string.format("%"..math.floor(v[3]).."."..math.floor(v[3]).."s",v[4]))
	-- yeah thats right I'm string formatting AND raw concatenation. EMBRACE CHAOS!!!!!!
  end
  term.setCursorPos(1,2)
end

function scanButtons(event, buttons) -- so nice, I used it twice!
  for ibtn, bttn in ipairs(buttons) do
    if (event[3] >= bttn[1] and event[3] < bttn[1] + bttn[3] 
	and event[4] >= bttn[2] and event[4] < bttn[2] + bttn[4] ) then
	  return ibtn, bttn[5](event, bttn[6], ibtn)
	end
  end
  return 0
end


doLoop = true

function main()
  while doLoop do
    sendMessages()
    parallel.waitForAny(interval, getInputs)
	wrangleInputs()
    drawPanel()
	if doListen then
	  
	end
  end
end
main()
