local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteFunction =
	ReplicatedStorage:WaitForChild("RemoteFunction")

local GetFruitInventory =
	RemoteFunction:WaitForChild("GetFruitInventory")

local DataService =
	require(
		game.ServerScriptService.Data.DataService
	)

GetFruitInventory.OnServerInvoke = function(player)

	local data =
		DataService:GetData(player)

	if not data then
		return {}
	end

	if not data.FruitInventory then
		data.FruitInventory = {}
	end

	return data.FruitInventory

end
