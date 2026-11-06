local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PlantService = {}

local PlantModels = ReplicatedStorage:WaitForChild("zhiwu")

local PlotService = require(
	game.ServerScriptService.Services.PlotService
)

local DataService = require(
	game.ServerScriptService.Data.DataService
)

--------------------------------------------------
-- 植物基础配置
--------------------------------------------------

local PlantConfig = {

	["1"] = {

		--------------------------------------------------
		-- 基础
		--------------------------------------------------

		Name = "1",

		Level = 1,

		Height = 1,

		Growth = 0,

		Fruit = "Apple",

		--------------------------------------------------
		-- 成长
		--------------------------------------------------

		-- 每次1秒增加多少成长值
		GrowthPerTick = 1,

		-- 需要多少成长值长高一次
		GrowthRequired = 100,

		-- 每次长高增加多少高度
		HeightPerGrowth = 1,

		--------------------------------------------------
		-- 鹅化物
		--------------------------------------------------

		-- 初始槽位
		GooseSlots = 1,

		-- 每次长高增加多少槽位
		GooseSlotsPerGrowth = 1,

	}

}


--------------------------------------------------
-- 获取植物配置
--------------------------------------------------

function PlantService:GetPlantConfig(plantName)

	return PlantConfig[plantName]

end


--------------------------------------------------
-- 创建植物
--------------------------------------------------

function PlantService:CreatePlant(player, plantData)

	--------------------------------------------------
	-- 获取玩家自己的土地
	--------------------------------------------------

	local plot = PlotService:GetPlayerPlot(player)

	if not plot then

		warn(
			"[PlantService] 找不到玩家土地："
				.. player.Name
		)

		return nil
	end


	--------------------------------------------------
	-- 确认土地属于玩家
	--------------------------------------------------

	if not PlotService:CanPlayerUsePlot(
		player,
		plot
		) then

		warn(
			"[PlantService] 玩家 "
				.. player.Name
				.. " 尝试操作其他玩家土地"
		)

		return nil
	end


	--------------------------------------------------
	-- 找 PlantArea
	--------------------------------------------------

	local plantArea = plot:FindFirstChild(
		"PlantArea",
		true
	)

	if not plantArea then

		warn(
			"[PlantService] 土地 "
				.. plot.Name
				.. " 找不到 PlantArea"
		)

		return nil
	end


	--------------------------------------------------
	-- 删除旧植物
	--------------------------------------------------

	local oldPlant = plot:FindFirstChild(
		"PlayerPlant"
	)

	if oldPlant then
		oldPlant:Destroy()
	end


	--------------------------------------------------
	-- 获取植物类型
	--------------------------------------------------

	local plantName = plantData.Name

	local config = PlantConfig[plantName]

	if not config then

		warn(
			"[PlantService] 没有植物配置："
				.. tostring(plantName)
		)

		return nil
	end


	--------------------------------------------------
	-- 获取植物模型
	--------------------------------------------------

	local plantTemplate = PlantModels:FindFirstChild(
		plantName
	)

	if not plantTemplate then

		warn(
			"[PlantService] 找不到植物模型："
				.. plantName
		)

		return nil
	end


	--------------------------------------------------
	-- 创建植物
	--------------------------------------------------

	local plant = plantTemplate:Clone()

	plant.Name = "PlayerPlant"

	plant.Parent = plot


	--------------------------------------------------
	-- PrimaryPart
	--------------------------------------------------

	if not plant.PrimaryPart then

		warn(
			"[PlantService] 植物 "
				.. plantName
				.. " 没有 PrimaryPart"
		)

		plant:Destroy()

		return nil
	end


	--------------------------------------------------
	-- 放到 PlantArea
	--------------------------------------------------

	local yOffset =
		plantArea.Size.Y / 2
		+ plant.PrimaryPart.Size.Y / 2

	plant:PivotTo(
		plantArea.CFrame
			* CFrame.new(
				0,
				yOffset,
				0
			)
	)


	--------------------------------------------------
	-- 设置植物 Attribute
	--------------------------------------------------

	plant:SetAttribute(
		"OwnerUserId",
		player.UserId
	)

	plant:SetAttribute(
		"PlantType",
		plantName
	)

	plant:SetAttribute(
		"PlantLevel",
		plantData.Level or config.Level
	)

	plant:SetAttribute(
		"PlantHeight",
		plantData.Height or config.Height
	)

	plant:SetAttribute(
		"Growth",
		plantData.Growth or config.Growth
	)


	--------------------------------------------------
	-- 成长参数
	--------------------------------------------------

	plant:SetAttribute(
		"GrowthRequired",
		config.GrowthRequired
	)

	plant:SetAttribute(
		"GrowthPerTick",
		config.GrowthPerTick or 1
	)

	plant:SetAttribute(
		"HeightPerGrowth",
		config.HeightPerGrowth or 1
	)


	--------------------------------------------------
	-- 鹅化物槽位
	--------------------------------------------------

	local gooseSlotCount =
		plantData.GooseSlotCount

	if gooseSlotCount == nil then
		gooseSlotCount =
			plantData.Height
			or config.GooseSlots
			or 1
	end

	plant:SetAttribute(
		"GooseSlotCount",
		gooseSlotCount
	)

	plant:SetAttribute(
		"GooseSlotsPerGrowth",
		config.GooseSlotsPerGrowth or 1
	)


	--------------------------------------------------
	-- 果实
	--------------------------------------------------

	plant:SetAttribute(
		"Fruit",
		plantData.Fruit or config.Fruit
	)


	--------------------------------------------------
	-- 根据植物高度调整模型
	--------------------------------------------------

	self:UpdatePlantVisual(
		plant
	)


	print(
		"[PlantService] 创建植物："
			.. player.Name
			.. " / "
			.. plantName
			.. " / Lv."
			.. tostring(
				plant:GetAttribute("PlantLevel")
			)
	)

	return plant

end


--------------------------------------------------
-- 更新植物外观（缩放 + 底部对齐，保证只向上生长）
--------------------------------------------------

function PlantService:UpdatePlantVisual(plant, smooth)

	if not plant then
		return
	end

	local height = plant:GetAttribute("PlantHeight") or 1

	-- 高度 1 = 原始大小，高度 2 = 1.5 倍，高度 3 = 2 倍
	local targetScale = 1 + (height - 1) * 0.5


	--------------------------------------------------
	-- 核心：封装缩放并且底部对齐的逻辑
	--------------------------------------------------
	local function ApplyScaleAndAlign(scale)

		--------------------------------------------------
		-- 1. 缩放前：记录底部位置
		--------------------------------------------------
		local beforeBottom
		local beforeUp = plant.PrimaryPart 
			and plant.PrimaryPart.CFrame.UpVector 
			or Vector3.new(0, 1, 0)

		local successBefore, beforeBoxCFrame, beforeBoxSize =
			pcall(function()
				return plant:GetBoundingBox()
			end)

		if successBefore and beforeBoxCFrame and beforeBoxSize then
			beforeBottom =
				beforeBoxCFrame.Position
			- beforeUp * (beforeBoxSize.Y / 2)
		end


		--------------------------------------------------
		-- 2. 执行缩放
		--------------------------------------------------
		plant:ScaleTo(scale)


		--------------------------------------------------
		-- 3. 缩放后：计算底部偏移，并推回原位
		--------------------------------------------------
		if beforeBottom then

			local successAfter, afterBoxCFrame, afterBoxSize =
				pcall(function()
					return plant:GetBoundingBox()
				end)

			if successAfter and afterBoxCFrame and afterBoxSize then

				local afterUp = plant.PrimaryPart
					and plant.PrimaryPart.CFrame.UpVector
					or beforeUp

				local afterBottom =
					afterBoxCFrame.Position
				- afterUp * (afterBoxSize.Y / 2)

				local moveOffset =
					beforeBottom - afterBottom

				-- 如果底部有偏移，就把植物整体往上推
				if moveOffset.Magnitude > 0.0001 then

					plant:PivotTo(
						plant:GetPivot()
							+ moveOffset
					)

				end

			end

		end

	end


	--------------------------------------------------
	-- 不需要渐变时直接设置
	--------------------------------------------------
	if not smooth then
		ApplyScaleAndAlign(targetScale)
		return
	end


	--------------------------------------------------
	-- 渐变生长（平滑向上生长）
	--------------------------------------------------
	local startScale = plant:GetScale()

	local duration = 10
	local startTime = os.clock()

	while plant.Parent do

		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / duration, 0, 1)

		-- SmoothStep，让生长开始和结束都比较平滑
		alpha = alpha * alpha * (3 - 2 * alpha)

		local currentScale =
			startScale + (targetScale - startScale) * alpha

		-- 调用封装好的缩放+对齐逻辑
		ApplyScaleAndAlign(currentScale)

		if alpha >= 1 then
			break
		end

		task.wait()
	end

end


--------------------------------------------------
-- 第一次种植
--------------------------------------------------

function PlantService:PlantNewPlant(
	player,
	plantName
)

	--------------------------------------------------
	-- 获取玩家数据
	--------------------------------------------------

	local data = DataService:GetData(
		player
	)

	if not data then

		warn(
			"[PlantService] 找不到玩家数据："
				.. player.Name
		)

		return nil
	end


	--------------------------------------------------
	-- 检查是否已经有植物
	--------------------------------------------------

	if data.Plant
		and data.Plant.Name
		and data.Plant.Name ~= "" then

		warn(
			"[PlantService] "
				.. player.Name
				.. " 已经拥有植物"
		)

		return nil
	end


	--------------------------------------------------
	-- 检查植物配置
	--------------------------------------------------

	local config = PlantConfig[plantName]

	if not config then

		warn(
			"[PlantService] 不存在植物配置："
				.. tostring(plantName)
		)

		return nil
	end


	--------------------------------------------------
	-- 创建新的植物数据
	--------------------------------------------------

	local plantData = {

		Name = plantName,

		Level = config.Level,

		Height = config.Height,

		Growth = config.Growth,

		Fruit = config.Fruit,

		GooseSlots = {}

	}


	--------------------------------------------------
	-- 创建植物
	--------------------------------------------------

	local plant = self:CreatePlant(
		player,
		plantData
	)

	if not plant then
		return nil
	end


	--------------------------------------------------
	-- 写入 DataService
	--------------------------------------------------

	DataService:SetPlantData(
		player,
		plantData
	)


	print(
		"[PlantService] "
			.. player.Name
			.. " 种植了初始植物 "
			.. plantName
	)

	return plant

end


--------------------------------------------------
-- 植物成长
--------------------------------------------------

function PlantService:GrowPlant(player)

	--------------------------------------------------
	-- 获取玩家土地
	--------------------------------------------------

	local plot = PlotService:GetPlayerPlot(
		player
	)

	if not plot then
		return false
	end


	--------------------------------------------------
	-- 权限检查
	--------------------------------------------------

	if not PlotService:CanPlayerUsePlot(
		player,
		plot
		) then
		return false
	end


	--------------------------------------------------
	-- 获取植物
	--------------------------------------------------

	local plant = plot:FindFirstChild(
		"PlayerPlant"
	)

	if not plant then
		return false
	end


	--------------------------------------------------
	-- 检查植物主人
	--------------------------------------------------

	if plant:GetAttribute(
		"OwnerUserId"
		) ~= player.UserId then

		return false
	end


	--------------------------------------------------
	-- 获取成长数据
	--------------------------------------------------

	local growth =
		plant:GetAttribute("Growth")
		or 0

	local growthRequired =
		plant:GetAttribute(
			"GrowthRequired"
		)
		or 100

	local growthPerTick =
		plant:GetAttribute("GrowthPerTick")
		or 1

	local height =
		plant:GetAttribute(
			"PlantHeight"
		)
		or 1

	local heightPerGrowth =
		plant:GetAttribute("HeightPerGrowth")
		or 1


	--------------------------------------------------
	-- 增加成长
	--------------------------------------------------

	growth += growthPerTick


	--------------------------------------------------
	-- 达到成长条件
	--------------------------------------------------

	if growth >= growthRequired then

		growth -= growthRequired


		height += heightPerGrowth


		--------------------------------------------------
		-- 更新植物高度
		--------------------------------------------------

		plant:SetAttribute(
			"PlantHeight",
			height
		)


		--------------------------------------------------
		-- 解锁鹅化物槽位
		--------------------------------------------------

		local gooseSlotCount =
			plant:GetAttribute("GooseSlotCount") or 1

		local gooseSlotsPerGrowth =
			plant:GetAttribute("GooseSlotsPerGrowth")
			or 1

		gooseSlotCount += gooseSlotsPerGrowth

		plant:SetAttribute(
			"GooseSlotCount",
			gooseSlotCount
		)


		--------------------------------------------------
		-- 同步玩家 Attribute
		--------------------------------------------------

		player:SetAttribute(
			"PlantHeight",
			height
		)

		player:SetAttribute(
			"GooseSlotCount",
			gooseSlotCount
		)


		--------------------------------------------------
		-- 植物渐变成长（平滑向上生长）
		--------------------------------------------------

		self:UpdatePlantVisual(
			plant,
			true
		)


		print(
			"[PlantService] "
				.. player.Name
				.. " 的植物长高了！"
				.. " 高度："
				.. height
				.. " / 鹅化物槽位："
				.. gooseSlotCount
		)

	end


	--------------------------------------------------
	-- 保存 Growth 到植物属性（内存中）
	--------------------------------------------------

	plant:SetAttribute(
		"Growth",
		growth
	)

	player:SetAttribute(
		"PlantHeight",
		height
	)

	-- 注意：这里不直接调用 DataService 保存！
	-- 避免每秒保存导致 DataStore 请求溢出排队。
	-- 保存工作请交给玩家离开游戏时，或服务器定时保存。

	return true

end


--------------------------------------------------
-- 玩家加入时加载植物
--------------------------------------------------

function PlantService:LoadPlayerPlant(
	player
)

	local data = DataService:GetData(
		player
	)

	if not data then

		warn(
			"[PlantService] 找不到玩家数据："
				.. player.Name
		)

		return nil
	end


	--------------------------------------------------
	-- 没有植物
	--------------------------------------------------

	if not data.Plant then
		return nil
	end


	if not data.Plant.Name
		or data.Plant.Name == "" then

		print(
			"[PlantService] "
				.. player.Name
				.. " 没有保存的植物"
		)

		return nil
	end


	--------------------------------------------------
	-- 恢复植物
	--------------------------------------------------

	return self:CreatePlant(
		player,
		data.Plant
	)

end


--------------------------------------------------
-- 保存植物（供玩家离开/定时器调用）
--------------------------------------------------

function PlantService:SavePlayerPlant(player)

	local plot = PlotService:GetPlayerPlot(
		player
	)

	if not plot then
		return false
	end


	local plant = plot:FindFirstChild(
		"PlayerPlant"
	)


	--------------------------------------------------
	-- 没有植物
	--------------------------------------------------

	if not plant then

		pcall(function()
			DataService:SetPlantData(
				player,
				{
					Name = "",
					Level = 0,
					Height = 0,
					Growth = 0,
					Fruit = "",
					GooseSlots = {}
				}
			)
		end)

		return true
	end


	--------------------------------------------------
	-- 权限检查
	--------------------------------------------------

	if plant:GetAttribute(
		"OwnerUserId"
		) ~= player.UserId then

		warn(
			"[PlantService] "
				.. player.Name
				.. " 尝试保存其他玩家植物"
		)

		return false
	end


	--------------------------------------------------
	-- 获取当前植物数据
	--------------------------------------------------

	local plantData = {

		Name =
			plant:GetAttribute("PlantType")
			or "1",

		Level =
			plant:GetAttribute("PlantLevel")
			or 1,

		Height =
			plant:GetAttribute("PlantHeight")
			or 1,

		Growth =
			plant:GetAttribute("Growth")
			or 0,

		Fruit =
			plant:GetAttribute("Fruit")
			or "",

		GooseSlotCount =
			plant:GetAttribute("GooseSlotCount")
			or 1,

		GooseSlots = {}

	}


	--------------------------------------------------
	-- 写入 DataService（加入 pcall 保护）
	--------------------------------------------------

	local success, err = pcall(function()
		DataService:SetPlantData(
			player,
			plantData
		)
	end)

	if not success then
		warn(
			"[PlantService] 保存植物数据失败（DataStore可能超时）：",
			err
		)
	end

	return success

end



return PlantService