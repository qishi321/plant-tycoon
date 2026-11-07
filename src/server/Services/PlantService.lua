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
-- 植物缩放：绕脚底 pivot 生长，模型整体不位移
--------------------------------------------------

-- 缓存放模块级；弱键表，植物销毁后自动回收
local PivotParts = setmetatable({}, { __mode = "k" })

local function GetPivotPart(plant)
	local cached = PivotParts[plant]

	if cached and cached.Parent then
		return cached
	end

	-- 名字必须和 Studio 里的零件一致
	local found = plant:FindFirstChild("pivot", true)

	if found and found:IsA("BasePart") then
		PivotParts[plant] = found
		return found
	end

	return nil
end


local function ApplyScaleFromPivot(plant, scale)

	local pivotPart = GetPivotPart(plant)
	local primary = plant.PrimaryPart

	--------------------------------------------------
	-- 找不到 pivot：明确报警，不要静默退化
	--------------------------------------------------
	if not pivotPart then

		warn(
			"[PlantService] 植物缺少 pivot 定位零件："
				.. plant:GetFullName()
		)

		plant:ScaleTo(scale)
		return
	end

	--------------------------------------------------
	-- 有 PrimaryPart 时 pivot 由它决定，先摘掉
	--------------------------------------------------
	if primary then
		plant.PrimaryPart = nil
	end

	plant.WorldPivot = pivotPart.CFrame

	-- 绕 pivot 缩放：pivot 点不动，无需任何补偿
	plant:ScaleTo(scale)

	if primary then
		plant.PrimaryPart = primary
	end
end


function PlantService:UpdatePlantVisual(plant, smooth)

	if not plant then
		return
	end

	local height = plant:GetAttribute("PlantHeight") or 1

	-- 高度 1 = 原始大小，高度 2 = 1.5 倍，高度 3 = 2 倍
	local targetScale = 1 + (height - 1) * 0.5

	--------------------------------------------------
	-- 创建 / 读档：直接到位，不播动画
	--------------------------------------------------
	if not smooth then
		ApplyScaleFromPivot(plant, targetScale)
		return
	end

	local startScale = plant:GetScale()

	--------------------------------------------------
	-- 已经在目标值附近，不跑空循环
	--------------------------------------------------
	if math.abs(targetScale - startScale) < 0.001 then
		return
	end

	local duration = 1.5
	local startTime = os.clock()

	while plant.Parent do

		local alpha = math.clamp(
			(os.clock() - startTime) / duration,
			0,
			1
		)

		-- SmoothStep
		alpha = alpha * alpha * (3 - 2 * alpha)

		ApplyScaleFromPivot(
			plant,
			startScale + (targetScale - startScale) * alpha
		)

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