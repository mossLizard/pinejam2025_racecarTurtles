
modemFreq = 201

-- END CONFIGURATION

modem = peripheral.wrap("left") or peripheral.wrap("right")
modem.closeAll()
modem.open(modemFreq)

testImage = {
  " Racecar!----------------------------- ",
  "                                       ",
  " Modem  # # freq- [SYNC] ###  ######## ",
  " Direc                 [NORTH]  [TURN] ",
  " Pos X  [<] [-] ###### [+] [>} # ----- ",
  " Pos Y  [<] [-] ###### [+] [>} # ----- ",
  " Pos Z  [<] [-] ###### [+] [>} # ----- ",
  " Veloc  [-X] +## [+X]   [-Z] +## [+Z]  ",
  "                                       ",
  " pineJam2025                      moss "
}


racerId = -1

serl = textutils.serializeJSON
usrl = textutils.unserializeJSON

local listenClass = ""
local doListen = false -- waiting for computer to send message


local storedX, storedY, storedZ = 0,0,0
local velx, velz = 0,0
local storedDirection = "north"
-- east = +x, south = +z
local movementQueue = {} -- move instructions for reckon() to execute

function reckon()
  -- moves (or doesn't) and updates stored X Y Z & direction
  -- I COULD use GPS to get position. That would be smart.
  -- but I'm too tired to be smart right now
  --   and that would involve somehow waiting for GPS while 
  --   also listening to other computers. in the same program.
  -- so. I'm doing this the Olde Fashioned Way
  
end

function addRotates(newDirection)
  if newDirection == storedDirection then return 0 end
  directionMapping = {["south"]=1,["west"]=3,["north"]=5,["east"]=7}
  mapN = directionMapping[storedDirection]
  mapS = directionMapping[newDirection]
  
end

function lineToMoves(x,z)
  -- fills movementQueue with instructions to move by the set amount, checking down every once in a while
  -- returns > 0 if okay, -1 if crashed / blocked
  
  local newDirection = ""
  local majorAxis, minorAxis = 0,0
    if math.abs(z) > math.abs(x) then
	  if z >= 0 then
	    newDirection = "south"
		majorAxis, minorAxis = z, x
	  else
	    newDirection = "north"
		majorAxis = -z, -x -- minus for left, + for right
	  end
	else
	  if x >= 0 then
	    newDirection = "east"
		majorAxis, minorAxis = x, -z
	  else
	    newDirection = "west"
		majorAxis, minorAxis = -x, z
	  end
	
	end
  
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
		  listenClass = ""
		  doListen = false
		elseif message.class == "yourTurn" then
		end
	  end
    elseif event[1] == "mouse_click" then
	  buttons =  {
	    {19,3,6,1,startSync,0}
	    }
	  print(serl(event),scanButtons(event, buttons))
	  --sleep(0.2)
	end
  end
end

function handleComputerMessage(message)
end


function startSync(event, param, index) -- send message requesting an ID
  -- will blindly accept the next setId message that comes in which is a bad way to do it but whateverrrrrr it's fiiiiine perfect is the enemy of done
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
  drawList = { {13,3,5,modemFreq}, {26,3,3,racerId}, {31,3,8,listenClass}
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
    parallel.waitForAny(interval, getInputs)
	wrangleInputs()
    drawPanel()
	if doListen then
	  
	end
  end
end
main()