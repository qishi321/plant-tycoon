local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemoteEvent = ReplicatedStorage:WaitForChild(
	"RemoteEvent"
)

local PlantRemote = RemoteEvent:WaitForChild(
	"Plant"
)

local PlantService = require(
	ServerScriptService.Services:WaitForChild(
		"PlantService"
	)
)

local DataService = require(
	ServerScriptService.Data:WaitForChild(
		"DataService"
	)
)

local SetSelectedFruit =
	RemoteEvent:WaitForChild(
		"SetSelectedFruit"
	)


PlantRemote.OnServerEvent:Connect(function(player)

	print(
		"[PlantServer] "
			.. player.Name
			.. " 请求种植"
	)

	--------------------------------------------------
	-- 初始植物固定为 1
	--------------------------------------------------

	local plant = PlantService:PlantNewPlant(
		player,
		"1"
	)

	if not plant then

		warn(
			"[PlantServer] "
				.. player.Name
				.. " 种植失败"
		)

		return
	end

	print(
		"[PlantServer] "
			.. player.Name
			.. " 种植成功"
	)

	--------------------------------------------------
	-- 植物生成成功后立即保存
	--------------------------------------------------

	local saveSuccess = DataService:SavePlayer(
		player
	)

	if saveSuccess then

		print(
			"[PlantServer] "
				.. player.Name
				.. " 植物数据已立即保存"
		)

	else

		warn(
			"[PlantServer] "
				.. player.Name
				.. " 植物数据保存失败"
		)

	end

end)

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")



--------------------------------------------------
-- DataService
--------------------------------------------------

local DataService =
	require(
		ServerScriptService.Data:WaitForChild(
			"DataService"
		)
	)

--------------------------------------------------
-- 玩家点击果实
--------------------------------------------------

SetSelectedFruit.OnServerEvent:Connect(
	function(player, fruitName)

		--------------------------------------------------
		-- 检查参数
		--------------------------------------------------

		if typeof(fruitName) ~= "string" then

			warn(
				"[Fruit] 无效果实名称：",
				player.Name
			)

			return

		end

		--------------------------------------------------
		-- 获取玩家数据
		--------------------------------------------------

		local data =
			DataService:GetData(player)

		if not data then

			warn(
				"[Fruit] 玩家数据不存在：",
				player.Name
			)

			return

		end

		--------------------------------------------------
		-- 检查果实是否在玩家背包
		--------------------------------------------------

		local hasFruit = false

		for _, ownedFruit in ipairs(
			data.FruitInventory or {}
			) do

			if ownedFruit == fruitName then

				hasFruit = true
				break

			end

		end

		if not hasFruit then

			warn(
				"[Fruit] 玩家没有这个果实：",
				player.Name,
				fruitName
			)

			return

		end

		--------------------------------------------------
		-- 检查植物
		--------------------------------------------------

		if typeof(data.Plant) ~= "table" then

			warn(
				"[Fruit] 玩家没有植物数据：",
				player.Name
			)

			return

		end

		--------------------------------------------------
		-- 切换当前果实
		--------------------------------------------------

		data.Plant.Fruit =
			fruitName

		--------------------------------------------------
		-- 保存玩家植物数据
		--------------------------------------------------

		DataService:SetPlantData(
			player,
			data.Plant
		)

		--------------------------------------------------
		-- 同步 Attribute
		--------------------------------------------------

		local plotName =
			player:GetAttribute("PlotName")

		if plotName then

			local map =
				workspace:FindFirstChild(
					"Grow A Garden map"
				)

			if map then

				local plot =
					map:FindFirstChild(plotName)

				if plot then

					local plant =
						plot:FindFirstChild(
							"PlayerPlant"
						)

					if plant then

						plant:SetAttribute(
							"Fruit",
							fruitName
						)

					end

				end

			end

		end

		print(
			"[Fruit] "
				.. player.Name
				.. " 切换果实为："
				.. fruitName
		)

	end
)