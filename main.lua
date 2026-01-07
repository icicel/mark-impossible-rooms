local MIR = RegisterMod("Mark Impossible Rooms", 1)
function MIR:Log(msg)
	-- Uncomment to enable logging
	--Isaac.ConsoleOutput(msg)
end

-- Adds the "impossible room" sprite.
MIR.ImpossibleRoomSpriteSmall = Sprite()
MIR.ImpossibleRoomSpriteSmall:Load("gfx/ui/impossible_small.anm2", true)
MIR.ImpossibleRoomSpriteLarge = Sprite()
MIR.ImpossibleRoomSpriteLarge:Load("gfx/ui/impossible_large.anm2", true)
MIR.ImpossibleRoomAnimationSmall = {
	sprite = MIR.ImpossibleRoomSpriteSmall,
	anim = "Default",
	frame = 0
}
MIR.ImpossibleRoomAnimationLarge = {
	sprite = MIR.ImpossibleRoomSpriteLarge,
	anim = "Default",
	frame = 0
}

if MinimapAPI then
	MinimapAPI:AddRoomShape(
		"ImpossibleRoom",
		{
			RoomUnvisited = MIR.ImpossibleRoomAnimationSmall,
			RoomVisited = MIR.ImpossibleRoomAnimationSmall,
			RoomCurrent = MIR.ImpossibleRoomAnimationSmall,
			RoomSemivisited = MIR.ImpossibleRoomAnimationSmall
		},
		{
			RoomUnvisited = MIR.ImpossibleRoomAnimationLarge,
			RoomVisited = MIR.ImpossibleRoomAnimationLarge,
			RoomCurrent = MIR.ImpossibleRoomAnimationLarge,
			RoomSemivisited = MIR.ImpossibleRoomAnimationLarge
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

-- Relative location of adjacent rooms by room shape and doorslot
-- https://wofsauge.github.io/IsaacDocs/rep/enums/RoomShape.html
MIR.DoorTable = {
	-- 1x1
	{{-1, 0}, {0, -1}, {1, 0}, {0, 1}, "nil", "nil", "nil", "nil"},
	-- 1x1 horizontal corridor
	{{-1, 0}, {0, -1}, {1, 0}, {0, 1}, "nil", "nil", "nil", "nil"},
	-- 1x1 vertical corridor
	{{-1, 0}, {0, -1}, {1, 0}, {0, 1}, "nil", "nil", "nil", "nil"},
	-- 2x1 vertical
	{{-1, 0}, {0, -1}, {1, 0}, {0, 2}, {-1, 1}, "nil", {1, 1}, "nil"},
	-- 2x1 vertical corridor
	{{-1, 0}, {0, -1}, {1, 0}, {0, 2}, {-1, 1}, "nil", {1, 1}, "nil"},
	-- 2x1 horizontal
	{{-1, 0}, {0, -1}, {2, 0}, {0, 1}, "nil", {1, -1}, "nil", {1, 1}},
	-- 2x1 horizontal corridor
	{{-1, 0}, {0, -1}, {2, 0}, {0, 1}, "nil", {1, -1}, "nil", {1, 1}},
	-- 2x2
	{{-1, 0}, {0, -1}, {2, 0}, {0, 2}, {-1, 1}, {1, -1}, {2, 1}, {1, 2}},
	-- lower right L shape (▟)
    {{-1, 0}, {-1, 0}, {1, 0}, {-1, 2}, {-2, 1}, {0, -1}, {1, 1}, {0, 2}},
	-- lower left L shape (▙)
    {{-1, 0}, {0, -1}, {1, 0}, {0, 2}, {-1, 1}, {1, 0}, {2, 1}, {1, 2}},
	-- upper right L shape (▜)
	{{-1, 0}, {0, -1}, {2, 0}, {0, 1}, {0, 1}, {1, -1}, {2, 1}, {1, 2}},
	-- upper left L shape (▛)
	{{-1, 0}, {0, -1}, {2, 0}, {0, 2}, {-1, 1}, {1, -1}, {1, 1}, {1, 1}}
}






-- Mark any impossible rooms neighboring the current room
function MIR:CheckDoorSlots()
	local room = MinimapAPI:GetCurrentRoom()
	if room == nil then
		return
	end

	local pos = room.Position -- vector
	local shape = room.Shape
	local validDoors = room.Descriptor.Data.Doors -- bitmap of what entrances are valid
	local neighborPos_s = MIR:GetNeighborVectors(pos, shape)

	MIR:Log("\nShape: "..shape..", bitmap: "..validDoors..", coords: "..pos.X..", "..pos.Y.."\nNeighbors:")
	for _,v in ipairs(neighborPos_s) do MIR:Log(" {"..v.X..", "..v.Y.."}") end
	MIR:Log("\nChecking rooms...")

	-- Get invalid entrances to neighboring rooms
	for n=0,7 do
		if validDoors & 1 << n == 0 then
			local delta = MIR.DoorTable[shape][n+1]
			if delta ~= "nil" then
				local invalidPos = Vector(pos.X + delta[1], pos.Y + delta[2])
				MIR:AddImpossibleRoom(invalidPos)
			end
		end
	end

	-- Loop through all adjacent room vectors
	for _,neighborPos in ipairs(neighborPos_s) do
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
			for _,neighborPos in ipairs(MIR:GetNeighborVectors(room.Position, room.Shape)) do
				MIR:AddImpossibleRoom(neighborPos)
			end

		elseif room:IsVisible() then
			-- add neighbors to the left and right if vertical corridor
			if room.Shape == RoomShape.ROOMSHAPE_IV or room.Shape == RoomShape.ROOMSHAPE_IIV then
				for _,neighborPos in ipairs(MIR:GetNeighborVectors(room.Position, room.Shape)) do
					if neighborPos.X ~= room.Position.X then
						MIR:AddImpossibleRoom(neighborPos)
					end
				end
			-- add neighbors above and below if horizontal corridor
			elseif room.Shape == RoomShape.ROOMSHAPE_IH or room.Shape == RoomShape.ROOMSHAPE_IIH then
				for _,neighborPos in ipairs(MIR:GetNeighborVectors(room.Position, room.Shape)) do
					if neighborPos.Y ~= room.Position.Y then
						MIR:AddImpossibleRoom(neighborPos)
					end
				end
			end
		end

	end
end

-- MinimapAPI already has GetAdjacentRooms(), but this returns coordinate vectors instead of room objects
function MIR:GetNeighborVectors(pos, shape)
	local neighbors = {}
	for _,v in ipairs(MIR.DoorTable[shape]) do
		if v ~= "nil" then
			table.insert(neighbors, Vector(pos.X + v[1], pos.Y + v[2]))
		end
	end
	return neighbors
end

function MIR:AddImpossibleRoom(pos)
	local stage = Game():GetLevel():GetStage()

	if not MinimapAPI:IsPositionFree(pos)
	or (stage == LevelStage.STAGE2_2 and MinimapAPI.CurrentDimension == 1) -- knife piece 2
	or stage == LevelStage.STAGE8 then -- home
		return
	end

	MinimapAPI:AddRoom({
		ID = pos.X.."-"..pos.Y,
		Position = pos,
		Shape = "ImpossibleRoom",
		Type = 1, -- ROOM_DEFAULT
		DisplayFlags = 5,
		Descriptor = {
			Data = {
				Doors = 0
			},
			DisplayFlags = 5
		}
	})
	MIR:Log("\nAdded {"..pos.X..", "..pos.Y.."}")
end

if MinimapAPI then
	MIR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MIR.CheckDoorSlots)
	MIR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, MIR.CheckAllRooms)
	MIR:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, MIR.CheckAllRooms)
end
