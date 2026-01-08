local MIR = RegisterMod("Mark Impossible Rooms", 1)
function MIR:Log(msg)
	-- Uncomment to enable logging
	--Isaac.ConsoleOutput(msg)
end

-- Load custom room shapes
function MIR:CreateRoomShape(id, spriteSmallPath, spriteLargePath)
	local spriteSmall = Sprite()
	spriteSmall:Load(spriteSmallPath, true)
	local spriteLarge = Sprite()
	spriteLarge:Load(spriteLargePath, true)
	local animationSmall = {
		sprite = spriteSmall,
		anim = "Default",
		frame = 0
	}
	local animationLarge = {
		sprite = spriteLarge,
		anim = "Default",
		frame = 0
	}
	if MinimapAPI then
		MinimapAPI:AddRoomShape(
			id,
			{
				RoomUnvisited = animationSmall,
				RoomVisited = animationSmall,
				RoomCurrent = animationSmall,
				RoomSemivisited = animationSmall
			},
			{
				RoomUnvisited = animationLarge,
				RoomVisited = animationLarge,
				RoomCurrent = animationLarge,
				RoomSemivisited = animationLarge
			},
			Vector(0, 0),
			Vector(1, 1),
			{Vector(0, 0)},
			{Vector(0, 0)},
			Vector(0, 0),
			{Vector(0.25, 0.25)},
			Vector(0.25, 0.25),
			{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 1)}
		)
	end
end
MIR:CreateRoomShape("ImpossibleRoom", "gfx/ui/impossible_small.anm2", "gfx/ui/impossible_large.anm2")
MIR:CreateRoomShape("SecretGuess", "gfx/ui/secret_guess_small.anm2", "gfx/ui/secret_guess_large.anm2")
MIR:CreateRoomShape("SuperSecretGuess", "gfx/ui/super_secret_guess_small.anm2", "gfx/ui/super_secret_guess_large.anm2")
MIR:CreateRoomShape("UltraSecretGuess", "gfx/ui/ultra_secret_guess_small.anm2", "gfx/ui/ultra_secret_guess_large.anm2")

-- Relative location of adjacent rooms by room shape and doorslot
-- https://wofsauge.github.io/IsaacDocs/rep/enums/RoomShape.html
MIR.DoorTable = {
	-- 1x1
	{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 1), "nil", "nil", "nil", "nil"},
	-- 1x1 horizontal corridor
	{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 1), "nil", "nil", "nil", "nil"},
	-- 1x1 vertical corridor
	{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 1), "nil", "nil", "nil", "nil"},
	-- 2x1 vertical
	{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 2), Vector(-1, 1), "nil", Vector(1, 1), "nil"},
	-- 2x1 vertical corridor
	{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 2), Vector(-1, 1), "nil", Vector(1, 1), "nil"},
	-- 2x1 horizontal
	{Vector(-1, 0), Vector(0, -1), Vector(2, 0), Vector(0, 1), "nil", Vector(1, -1), "nil", Vector(1, 1)},
	-- 2x1 horizontal corridor
	{Vector(-1, 0), Vector(0, -1), Vector(2, 0), Vector(0, 1), "nil", Vector(1, -1), "nil", Vector(1, 1)},
	-- 2x2
	{Vector(-1, 0), Vector(0, -1), Vector(2, 0), Vector(0, 2), Vector(-1, 1), Vector(1, -1), Vector(2, 1), Vector(1, 2)},
	-- lower right L shape (▟)
	{Vector(-1, 0), Vector(-1, 0), Vector(1, 0), Vector(-1, 2), Vector(-2, 1), Vector(0, -1), Vector(1, 1), Vector(0, 2)},
	-- lower left L shape (▙)
	{Vector(-1, 0), Vector(0, -1), Vector(1, 0), Vector(0, 2), Vector(-1, 1), Vector(1, 0), Vector(2, 1), Vector(1, 2)},
	-- upper right L shape (▜)
	{Vector(-1, 0), Vector(0, -1), Vector(2, 0), Vector(0, 1), Vector(0, 1), Vector(1, -1), Vector(2, 1), Vector(1, 2)},
	-- upper left L shape (▛)
	{Vector(-1, 0), Vector(0, -1), Vector(2, 0), Vector(0, 2), Vector(-1, 1), Vector(1, -1), Vector(1, 1), Vector(1, 1)}
}





--== Room Helper Functions ==--


-- Find all possible adjacent rooms
-- MinimapAPI already has GetAdjacentRooms(), but this returns coordinates instead of room objects
function MIR:GetNeighborVectors(room)
	return MIR:GetNeighborVectorsOfPosition(room.Position, room.Shape)
end

function MIR:GetNeighborVectorsOfPosition(pos, shape)
	local neighbors = {}
	for _,delta in ipairs(MIR.DoorTable[shape]) do
		if delta ~= "nil" then
			MIR:Log("\nNeighbor delta: {"..delta.X..", "..delta.Y.."}")
			table.insert(neighbors, pos + delta)
		end
	end
	return neighbors
end

-- Return number of visible rooms adjacent to a given position
function MIR:CountAdjacentVisibleRooms(pos)
	local count = 0
	for _,neighborPos in ipairs(MIR:GetNeighborVectorsOfPosition(pos, RoomShape.ROOMSHAPE_1x1)) do
		local adjacentRoom = MinimapAPI:GetRoomAtPosition(neighborPos)
		if adjacentRoom then
			if adjacentRoom:IsVisible() and adjacentRoom.Type ~= RoomType.ROOM_NULL then
				count = count + 1
			end
		end
	end
	return count
end

function MIR:AddImpossibleRoom(pos)
	local stage = Game():GetLevel():GetStage()

	if (stage == LevelStage.STAGE2_2 and MinimapAPI.CurrentDimension == 1) -- knife piece 2
	or stage == LevelStage.STAGE8 then -- home
		return
	end

	if not MinimapAPI:IsPositionFree(pos) then
		local existingRoom = MinimapAPI:GetRoomAtPosition(pos)
		if existingRoom.Shape == "SecretGuess" or existingRoom.Shape == "SuperSecretGuess" or existingRoom.Shape == "UltraSecretGuess" then
			existingRoom:Remove()
			MIR:Log("\nReplaced {"..pos.X..", "..pos.Y.."}")
		else
			return
		end
	end

	MinimapAPI:AddRoom({
		ID = pos.X.."-"..pos.Y,
		Position = pos,
		Shape = "ImpossibleRoom",
		Type = RoomType.ROOM_NULL,
		DisplayFlags = 5
	})
	MIR:Log("\nAdded {"..pos.X..", "..pos.Y.."}")
end





--== Impossible Room Marking ==--


-- Mark any impossible rooms neighboring the current room
function MIR:CheckDoorSlots()
	local room = MinimapAPI:GetCurrentRoom()
	if room == nil then
		return
	end

	local validDoors = room.Descriptor.Data.Doors -- bitmap of what entrances are valid
	local neighborVectors = MIR:GetNeighborVectors(room)

	MIR:Log("\nShape: "..room.Shape..", bitmap: "..validDoors..", coords: "..room.Position.X..", "..room.Position.Y.."\nNeighbors:")
	for _,neighborPos in ipairs(neighborVectors) do MIR:Log(" {"..neighborPos.X..", "..neighborPos.Y.."}") end
	MIR:Log("\nChecking rooms...")

	-- Get invalid entrances to neighboring rooms
	for n=0,7 do
		if validDoors & 1 << n == 0 then
			local delta = MIR.DoorTable[room.Shape][n+1]
			if delta ~= "nil" then
				local invalidPos = room.Position + delta
				MIR:AddImpossibleRoom(invalidPos)
			end
		end
	end

	-- Loop through all adjacent room vectors
	for _,neighborPos in ipairs(neighborVectors) do
		-- Check if the neighbor is outside the floor grid (13x13)
		if neighborPos.X < 0 or neighborPos.Y < 0 or neighborPos.X > 12 or neighborPos.Y > 12 then
			MIR:AddImpossibleRoom(neighborPos)
		end
	end

	MIR:Log("\nFinished checking rooms\n")
end

-- Mark impossible rooms on a more global level
function MIR:CheckAllRooms()
	for _,room in ipairs(MinimapAPI:GetLevel()) do
		local stage = Game():GetLevel():GetStage()

		-- add all neighbors if boss room
		-- is straight up disabled in void (for now) because wacky behavior with delirium's boss room
		if room.Type == RoomType.ROOM_BOSS and room:IsIconVisible() and stage ~= LevelStage.STAGE7 then
			for _,neighborPos in ipairs(MIR:GetNeighborVectors(room)) do
				MIR:AddImpossibleRoom(neighborPos)
			end

		elseif room:IsVisible() then
			-- add neighbors to the left and right if vertical corridor
			if room.Shape == RoomShape.ROOMSHAPE_IV or room.Shape == RoomShape.ROOMSHAPE_IIV then
				for _,neighborPos in ipairs(MIR:GetNeighborVectors(room)) do
					if neighborPos.X ~= room.Position.X then
						MIR:AddImpossibleRoom(neighborPos)
					end
				end
			-- add neighbors above and below if horizontal corridor
			elseif room.Shape == RoomShape.ROOMSHAPE_IH or room.Shape == RoomShape.ROOMSHAPE_IIH then
				for _,neighborPos in ipairs(MIR:GetNeighborVectors(room)) do
					if neighborPos.Y ~= room.Position.Y then
						MIR:AddImpossibleRoom(neighborPos)
					end
				end
			end
		end

	end
end





--== Secret Room Guessing ==--


-- Find possible secret room locations (empty spaces adjacent to 2-4 visible rooms)
function MIR:GuessSecretRoom()
	for _,room in ipairs(MinimapAPI:GetLevel()) do
		-- only consider visible rooms
		if not room:IsVisible() then
			goto continue
		end
		-- ignore special rooms
		if room.Type ~= RoomType.ROOM_DEFAULT then
			goto continue
		end
		-- ignore red rooms
		if room.Descriptor.Flags & RoomDescriptor.FLAG_RED_ROOM ~= 0 then
			goto continue
		end

		for _,neighborPos in ipairs(MIR:GetNeighborVectors(room)) do
			-- spot occupied by visible room (invisible is fine)
			if not MinimapAPI:IsPositionFree(neighborPos) then
				if MinimapAPI:GetRoomAtPosition(neighborPos):IsVisible() then
					goto continue2
				end
			end
			-- borders 2-4 rooms
			if MIR:CountAdjacentVisibleRooms(neighborPos) < 2 then
				goto continue2
			end

			local newRoom = MinimapAPI:AddRoom({
				ID = neighborPos.X.."-"..neighborPos.Y,
				Position = neighborPos,
				Shape = "SecretGuess",
				Type = RoomType.ROOM_NULL,
				DisplayFlags = 5,
				AllowRoomOverlap = true -- can overlap with unrevealed secret rooms (will be overwritten when revealed)
			})
			table.insert(MIR.CurrentGuesses, newRoom)
			MIR:Log("\nAdded SecretGuess {"..neighborPos.X..", "..neighborPos.Y.."}")

			::continue2::
		end
		::continue:: -- ugh
	end
end

function MIR:GuessSuperSecretRoom()
	
end

function MIR:GuessUltraSecretRoom()
	
end

function MIR:ClearGuesses()
	for _,room in ipairs(MIR.CurrentGuesses) do
		room:Remove()
		MIR:Log("\nRemoved {"..room.Position.X..", "..room.Position.Y.."}")
	end
	MIR.CurrentGuesses = {}
end

-- Only one set of guesses should be active at a time
MIR.CurrentGuesses = {}
function MIR:ToggleGuesses()
	if Input.IsButtonTriggered(Keyboard.KEY_T, 0) then
		if #MIR.CurrentGuesses > 0 then
			MIR:ClearGuesses()
		else
			MIR:GuessSecretRoom()
		end
	end
	if Input.IsButtonTriggered(Keyboard.KEY_Y, 0) then
		if #MIR.CurrentGuesses > 0 then
			MIR:ClearGuesses()
		else
			MIR:GuessSuperSecretRoom()
		end
	end
	if Input.IsButtonTriggered(Keyboard.KEY_U, 0) then
		if #MIR.CurrentGuesses > 0 then
			MIR:ClearGuesses()
		else
			MIR:GuessUltraSecretRoom()
		end
	end
end





--== Callbacks ==--


if MinimapAPI then
	MIR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MIR.CheckDoorSlots)
	MIR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MIR.CheckAllRooms)
	MIR:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, MIR.CheckAllRooms)
	MIR:AddCallback(ModCallbacks.MC_POST_RENDER, MIR.ToggleGuesses)
end
