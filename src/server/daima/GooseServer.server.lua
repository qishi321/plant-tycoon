local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GooseService =
	require(
		ServerScriptService.Services:WaitForChild(
			"GooseService"
		)
	)

--------------------------------------------------
-- 全局位置配置
--------------------------------------------------

local LEFT_VISUAL_OFFSET = -1

local GAP = 0.05

--------------------------------------------------
-- Remote
--------------------------------------------------

local RemoteEvent =
	ReplicatedStorage:WaitForChild("RemoteEvent")

local PlaceGoose =
	RemoteEvent:WaitForChild("PlaceGoose")

local GoosePlacementResult =
	RemoteEvent:FindFirstChild("GoosePlacementResult")

if not GoosePlacementResult then
	GoosePlacementResult = Instance.new("RemoteEvent")
	GoosePlacementResult.Name = "GoosePlacementResult"
	GoosePlacementResult.Parent = RemoteEvent
end

local RemoteFunction =
	ReplicatedStorage:WaitForChild("RemoteFunction")

local BuyGoose =
	RemoteFunction:WaitForChild("BuyGoose")

local GetGooseInventory =
	RemoteFunction:WaitForChild("GetGooseInventory")

--------------------------------------------------
-- 鹅化物交互 RemoteEvent
-- 左键编辑 / 右键回收
--------------------------------------------------

local GooseInteraction =
	RemoteEvent:FindFirstChild("GooseInteraction")

if not GooseInteraction then
	GooseInteraction = Instance.new("RemoteEvent")
	GooseInteraction.Name = "GooseInteraction"
	GooseInteraction.Parent = RemoteEvent
end

-- 正在编辑的鹅化物：player -> itemId
local EditingGoose = {}

--------------------------------------------------
-- Config
--------------------------------------------------

local GooseConfig =
	require(
		ReplicatedStorage.Config:WaitForChild("GooseConfig")
	)

local GoosePlacementConfig =
	require(
		ReplicatedStorage.Config:WaitForChild(
			"GoosePlacementConfig"
		)
	)

--------------------------------------------------
-- GooseModels
--------------------------------------------------

local GooseModels =
	ReplicatedStorage:WaitForChild("GooseModels")

--------------------------------------------------
-- Services
--------------------------------------------------

local PlotService =
	require(
		ServerScriptService.Services:WaitForChild(
			"PlotService"
		)
	)

local DataService =
	require(
		ServerScriptService.Data:WaitForChild(
			"DataService"
		)
	)

--------------------------------------------------
-- 植物 / 鹅化物位置辅助函数
--------------------------------------------------

local function GetPlantScale(plant)
	if not plant or not plant:IsA("Model") then
		return 1
	end

	local success, scale = pcall(function()
		return plant:GetScale()
	end)

	if success and typeof(scale) == "number" and scale > 0 then
		return scale
	end

	return 1
end

local function CalculateGooseTransform(
	plant,
	side,
	heightRatio,
	length,
	scaleMultiplier,
	directHeight
)
	if not plant or not plant.PrimaryPart then
		return nil
	end

	local plantPart = plant.PrimaryPart

	if not plantPart:IsA("BasePart") then
		return nil
	end

	local plantCFrame = plantPart.CFrame
	local plantSize = plantPart.Size

	local safeHeightRatio = math.clamp(
		tonumber(heightRatio) or 0.5,
		0,
		1
	)

	local safeLength = math.max(
		tonumber(length) or 2,
		0.1
	)

	local safeScaleMultiplier = math.max(
		tonumber(scaleMultiplier) or 1,
		0.001
	)

	local currentLength =
		safeLength * safeScaleMultiplier

	local currentHeight

	if typeof(directHeight) == "number" then
		currentHeight = directHeight
	else
		currentHeight =
			-plantSize.Y / 2
			+ safeHeightRatio * plantSize.Y
	end

	local direction = 1

	if side == "Left" then
		direction = -1
	end

	local plantHalfWidth =
		plantSize.X / 2

	local gooseCenterX =
		direction
		* (
			plantHalfWidth
			+ currentLength / 2
			+ GAP
		)

	if side == "Left" then
		gooseCenterX +=
			LEFT_VISUAL_OFFSET
			* safeScaleMultiplier
	end

	local localPosition = Vector3.new(
		gooseCenterX,
		currentHeight,
		0
	)

	local worldPosition =
		plantCFrame:PointToWorldSpace(
			localPosition
		)

	local sideRotation = CFrame.identity

	if side == "Left" then
		sideRotation =
			CFrame.Angles(
				0,
				math.rad(180),
				0
			)
	end

	local horizontalRotation =
		CFrame.Angles(
			0,
			0,
			math.rad(-90)
		)

	return {
		CFrame =
			CFrame.new(worldPosition)
			* plantCFrame.Rotation
			* sideRotation
			* horizontalRotation,

		WorldPosition = worldPosition,
		Length = currentLength,
	}
end

--------------------------------------------------
-- ✅ 应用缩放
--
-- BasePart：三轴等比缩放
-- Model：整体等比缩放（ScaleTo），跟随植物同步变大
--------------------------------------------------

local function ApplyGooseScale(
	gooseObject,
	scaleMultiplier
)
	local safeMultiplier = math.max(
		tonumber(scaleMultiplier) or 1,
		0.001
	)

	if gooseObject:IsA("BasePart") then
		local baseX =
			gooseObject:GetAttribute("BaseSizeX")

		local baseY =
			gooseObject:GetAttribute("BaseSizeY")

		local baseZ =
			gooseObject:GetAttribute("BaseSizeZ")

		if typeof(baseX) == "number"
			and typeof(baseY) == "number"
			and typeof(baseZ) == "number" then

			gooseObject.Size = Vector3.new(
				baseX * safeMultiplier,
				baseY * safeMultiplier,
				baseZ * safeMultiplier
			)
		end

		--------------------------------------------------
		-- ✅ Model：整体等比缩放
		--------------------------------------------------

	elseif gooseObject:IsA("Model") then
		local baseScale =
			gooseObject:GetAttribute("BaseModelScale")

		if typeof(baseScale) == "number"
			and baseScale > 0 then

			-- ✅ 这里就是 Model 跟随植物同步变大的关键
			-- 每次植物成长，scaleMultiplier 都会变大
			-- Model 会按 baseModelScale * scaleMultiplier 整体缩放
			gooseObject:ScaleTo(
				baseScale * safeMultiplier
			)
		end
	end

	gooseObject:SetAttribute(
		"CurrentScaleMultiplier",
		safeMultiplier
	)
end

local function UpdatePlayerGoosePositions(player)
	local plot =
		PlotService:GetPlayerPlot(player)

	if not plot then
		return
	end

	local plant =
		plot:FindFirstChild("PlayerPlant")

	if not plant
		or not plant:IsA("Model")
		or not plant.PrimaryPart then
		return
	end

	local currentPlantScale =
		GetPlantScale(plant)

	for _, gooseObject in ipairs(
		plot:GetChildren()
		) do
		if gooseObject:GetAttribute("ItemId") then
			local side =
				gooseObject:GetAttribute("Side")

			local heightRatio =
				tonumber(
					gooseObject:GetAttribute("HeightRatio")
				)

			local length =
				tonumber(
					gooseObject:GetAttribute("Length")
				)

			local itemId =
				gooseObject:GetAttribute("ItemId")

			if side
				and heightRatio
				and length
				and itemId then

				local data =
					DataService:GetData(player)

				local placementPlantScale = 1

				if data and data.GooseInventory then
					for _, item in ipairs(
						data.GooseInventory
						) do
						if item.ID == itemId then
							if item.Position then
								placementPlantScale =
									tonumber(
										item.Position.PlantScale
									)
									or 1
							end
							break
						end
					end
				end

				placementPlantScale =
					math.max(
						placementPlantScale,
						0.001
					)

				local scaleMultiplier =
					currentPlantScale
					/ placementPlantScale

				local transform =
					CalculateGooseTransform(
						plant,
						side,
						heightRatio,
						length,
						scaleMultiplier
					)

				if transform then
					-- ✅ 先应用缩放
					ApplyGooseScale(
						gooseObject,
						scaleMultiplier
					)

					-- ✅ 再设置位置
					if gooseObject:IsA("BasePart") then
						gooseObject.CFrame =
							transform.CFrame
					elseif gooseObject:IsA("Model") then
						gooseObject:PivotTo(
							transform.CFrame
						)
					end
				end
			end
		end
	end
end

--------------------------------------------------
-- 获取新放置鹅化物应该使用的大小倍率
--------------------------------------------------

local function GetNewGooseScaleMultiplier(player, plant, currentPlantScale)
	local data = DataService:GetData(player)

	if not data or not data.GooseInventory then
		return 1
	end

	for _, item in ipairs(data.GooseInventory) do
		if item.EquipState == true
			and item.Position
			and tonumber(item.Position.PlantScale)
			and tonumber(item.Position.PlantScale) > 0 then

			local oldPlantScale = tonumber(item.Position.PlantScale)
			return currentPlantScale / oldPlantScale
		end
	end

	return currentPlantScale
end

--------------------------------------------------
-- 找到鹅化物 Hitbox
--------------------------------------------------

local function GetGooseHitbox(gooseObject)
	if not gooseObject then
		return nil
	end

	if gooseObject:IsA("BasePart") then
		return gooseObject
	end

	local hitbox = gooseObject:FindFirstChild("Hitbox", true)

	if hitbox and hitbox:IsA("BasePart") then
		return hitbox
	end

	return nil
end

--------------------------------------------------
-- 给已经放置的鹅化物设置点击交互
--------------------------------------------------

local function SetupGooseClickDetector(ownerPlayer, gooseObject)
	if not gooseObject or not gooseObject.Parent then
		return
	end

	local hitbox = GetGooseHitbox(gooseObject)

	if not hitbox then
		warn(
			"[GooseServer] 鹅化物没有 Hitbox，无法设置点击交互：",
			gooseObject.Name
		)
		return
	end

	if gooseObject:IsA("Model") then
		gooseObject.PrimaryPart = hitbox
	end

	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanTouch = true
	hitbox.CanQuery = true
	hitbox.Transparency = 1

	--------------------------------------------------
	-- 先清掉旧的（可能来自模板或被复制过）
	-- 重建比"打标记复用"可靠：
	-- 旧检测器上的 MouseClick 连接会随实例一起销毁
	--------------------------------------------------

	local oldDetector =
		hitbox:FindFirstChild("GooseClickDetector")

	if oldDetector then
		oldDetector:Destroy()
	end

	local clickDetector =
		Instance.new("ClickDetector")

	clickDetector.Name =
		"GooseClickDetector"

	clickDetector.MaxActivationDistance =
		1000

	clickDetector.Parent =
		hitbox

	--------------------------------------------------
	-- 左键：进入编辑模式
	--------------------------------------------------

	clickDetector.MouseClick:Connect(function(clickedPlayer)
		if clickedPlayer ~= ownerPlayer then
			return
		end

		local plot = PlotService:GetPlayerPlot(clickedPlayer)
		if not plot or not gooseObject:IsDescendantOf(plot) then
			return
		end

		local itemId = gooseObject:GetAttribute("ItemId")
		local gooseId = gooseObject:GetAttribute("GooseId")
		local side = gooseObject:GetAttribute("Side")
		local length = tonumber(gooseObject:GetAttribute("Length"))

		if typeof(itemId) ~= "string"
			or typeof(gooseId) ~= "string"
			or (side ~= "Left" and side ~= "Right")
			or not length then
			return
		end

		local data = DataService:GetData(clickedPlayer)
		if not data then
			return
		end

		local found = false
		for _, item in ipairs(data.GooseInventory or {}) do
			if item.ID == itemId and item.EquipState == true then
				found = true
				break
			end
		end

		if not found then
			return
		end

		local plant = plot:FindFirstChild("PlayerPlant")
		if not plant or not plant:IsA("Model") or not plant.PrimaryPart then
			return
		end

		local goosePosition = gooseObject:GetPivot().Position
		local localPosition =
			plant.PrimaryPart.CFrame:PointToObjectSpace(goosePosition)

		local plantSizeY = plant.PrimaryPart.Size.Y
		if plantSizeY <= 0 then
			return
		end

		local height = math.clamp(
			localPosition.Y,
			-plantSizeY / 2,
			plantSizeY / 2
		)

		GooseInteraction:FireClient(
			clickedPlayer,
			"EditRequest",
			itemId,
			gooseId,
			side,
			height,
			length,
			gooseObject:GetPivot()
		)
	end)

	--------------------------------------------------
	-- 右键：回收进背包
	--------------------------------------------------

	clickDetector.RightMouseClick:Connect(function(clickedPlayer)
		if clickedPlayer ~= ownerPlayer then
			return
		end

		local plot = PlotService:GetPlayerPlot(clickedPlayer)
		if not plot or not gooseObject:IsDescendantOf(plot) then
			return
		end

		local itemId = gooseObject:GetAttribute("ItemId")
		if typeof(itemId) ~= "string" then
			return
		end

		GooseInteraction:FireClient(
			clickedPlayer,
			"RecycleRequest",
			itemId
		)
	end)
end

--------------------------------------------------
-- 回收鹅化物
--------------------------------------------------

local function RecycleGoose(player, itemId)
	if typeof(itemId) ~= "string" then
		return false
	end

	local plot = PlotService:GetPlayerPlot(player)
	if not plot then
		return false
	end

	local data = DataService:GetData(player)
	if not data then
		return false
	end

	local gooseItem
	for _, item in ipairs(data.GooseInventory or {}) do
		if item.ID == itemId then
			gooseItem = item
			break
		end
	end

	if not gooseItem or gooseItem.EquipState ~= true then
		return false
	end

	local worldObject
	for _, object in ipairs(plot:GetChildren()) do
		if object:GetAttribute("ItemId") == itemId then
			worldObject = object
			break
		end
	end

	if worldObject then
		worldObject:Destroy()
	end

	gooseItem.EquipState = false
	gooseItem.Position = nil
	gooseItem.WorldPosition = nil

	EditingGoose[player] = nil

	GoosePlacementResult:FireClient(
		player,
		true,
		itemId,
		gooseItem.GooseId,
		"Recycled"
	)

	return true
end

--------------------------------------------------
-- 购买鹅化物
--------------------------------------------------

BuyGoose.OnServerInvoke = function(
	player,
	gooseId
)

	print(
		"[GooseServer] 收到购买请求：",
		player.Name,
		gooseId
	)

	if typeof(gooseId) ~= "string" then
		return false, "商品ID错误"
	end

	local gooseData =
		GooseConfig[gooseId]

	if not gooseData then
		warn(
			"[GooseServer] 不存在的鹅化物：",
			gooseId
		)
		return false, "商品不存在"
	end

	local data =
		DataService:GetData(player)

	if not data then
		warn(
			"[GooseServer] 玩家数据不存在：",
			player.Name
		)
		return false, "数据还没有加载完成"
	end

	local price =
		gooseData.Price

	if typeof(price) ~= "number" then
		warn(
			"[GooseServer] 商品价格错误：",
			gooseId
		)
		return false, "商品价格错误"
	end

	if data.Money < price then
		print(
			"[GooseServer] 金币不足：",
			player.Name,
			data.Money,
			"/",
			price
		)
		return false, "金币不足"
	end

	local success =
		DataService:AddMoney(
			player,
			-price
		)

	if not success then
		warn(
			"[GooseServer] 扣钱失败：",
			player.Name
		)
		return false, "购买失败"
	end

	if not data.GooseInventory then
		data.GooseInventory = {}
	end

	local item = {
		ID =
			HttpService:GenerateGUID(false),

		GooseId =
			gooseId,

		EquipState =
			false,
	}

	table.insert(
		data.GooseInventory,
		item
	)

	print(
		"[GooseServer] 购买成功：",
		player.Name,
		gooseId,
		price
	)

	return true, "购买成功"

end

--------------------------------------------------
-- 放置鹅化物
--------------------------------------------------

PlaceGoose.OnServerEvent:Connect(function(
	player,
	itemId,
	side,
	height,
	length,
	clientWorldPosition
)

	local dataTimeout = 10
	local dataStart = os.clock()

	while player.Parent
		and player:GetAttribute("DataLoaded") ~= true
		and os.clock() - dataStart < dataTimeout do

		task.wait(0.1)
	end

	if not player.Parent then
		return
	end

	if player:GetAttribute("DataLoaded") ~= true then
		warn(
			"[GooseServer] 等待玩家数据加载超时：",
			player.Name
		)
		return
	end

	print(
		"[GooseServer] 收到放置请求：",
		player.Name,
		itemId,
		side,
		height,
		length
	)

	if typeof(itemId) ~= "string" then
		warn("[GooseServer] 鹅化物ID错误")
		return
	end

	if side ~= "Left"
		and side ~= "Right" then
		warn(
			"[GooseServer] 鹅化物方向错误：",
			side
		)
		return
	end

	if typeof(height) ~= "number" then
		warn("[GooseServer] 鹅化物高度错误")
		return
	end

	if typeof(length) ~= "number" then
		warn("[GooseServer] 鹅化物长度错误")
		return
	end

	if typeof(clientWorldPosition) ~= "Vector3" then
		warn(
			"[GooseServer] 客户端世界坐标错误：",
			player.Name,
			clientWorldPosition
		)
		return
	end

	local minLength =
		GoosePlacementConfig.MinLength

	local maxLength =
		GoosePlacementConfig.MaxLength

	if typeof(minLength) ~= "number"
		or typeof(maxLength) ~= "number" then

		warn(
			"[GooseServer] GoosePlacementConfig 配置错误"
		)

		return
	end

	length =
		math.clamp(
			length,
			minLength,
			maxLength
		)

	local plot =
		PlotService:GetPlayerPlot(player)

	if not plot then
		warn(
			"[GooseServer] 玩家没有土地：",
			player.Name
		)
		return
	end

	local data =
		DataService:GetData(player)

	if not data then
		warn(
			"[GooseServer] 玩家数据不存在：",
			player.Name
		)
		return
	end

	local gooseItem

	for _, item in ipairs(
		data.GooseInventory or {}
		) do

		if item.ID == itemId then
			gooseItem = item
			break
		end

	end

	if not gooseItem then
		warn(
			"[GooseServer] 玩家没有这个鹅化物：",
			player.Name,
			itemId
		)
		return
	end

	local isEditing =
		EditingGoose[player] == itemId

	if gooseItem.EquipState == true and not isEditing then
		warn(
			"[GooseServer] 这个鹅化物已经放置：",
			itemId
		)
		return
	end

	local gooseData =
		GooseConfig[gooseItem.GooseId]

	if not gooseData then
		warn(
			"[GooseServer] 找不到鹅化物配置：",
			gooseItem.GooseId
		)
		return
	end

	local plant =
		plot:FindFirstChild("PlayerPlant")

	if not plant
		or not plant:IsA("Model") then

		warn(
			"[GooseServer] 玩家还没有有效植物：",
			player.Name
		)

		return
	end

	local plantPart =
		plant.PrimaryPart

	if not plantPart
		or not plantPart:IsA("BasePart") then

		warn(
			"[GooseServer] PlayerPlant 没有有效 PrimaryPart：",
			player.Name
		)

		return
	end

	local gooseSlotCount =
		plant:GetAttribute(
			"GooseSlotCount"
		)

	if not gooseSlotCount then
		gooseSlotCount =
			player:GetAttribute(
				"GooseSlotCount"
			)
			or 0
	end

	local equippedCount = 0

	for _, item in ipairs(
		data.GooseInventory or {}
		) do

		if item.EquipState == true
			and item.ID ~= itemId then
			equippedCount += 1
		end

	end

	if equippedCount >= gooseSlotCount and not isEditing then
		warn(
			"[GooseServer] 鹅化物槽位已满：",
			player.Name,
			equippedCount,
			"/",
			gooseSlotCount
		)
		return
	end

	local currentPlantScale =
		GetPlantScale(plant)

	local targetGooseScale =
		GetNewGooseScaleMultiplier(
			player,
			plant,
			currentPlantScale
		)

	local placementPlantScale

	if isEditing
		and gooseItem.Position
		and tonumber(gooseItem.Position.PlantScale)
		and tonumber(gooseItem.Position.PlantScale) > 0 then

		placementPlantScale =
			tonumber(gooseItem.Position.PlantScale)
	else
		placementPlantScale =
			currentPlantScale / math.max(targetGooseScale, 0.001)
	end

	placementPlantScale =
		math.max(placementPlantScale, 0.001)

	local plantHeight =
		plantPart.Size.Y

	if plantHeight <= 0 then
		warn(
			"[GooseServer] 植物高度无效：",
			player.Name
		)
		return
	end

	local heightRatio =
		(
			height
			+
			plantHeight / 2
		)
		/
		plantHeight

	heightRatio =
		math.clamp(
			heightRatio,
			0,
			1
		)

	local scaleMultiplier =
		currentPlantScale / placementPlantScale

	local sideRotation = CFrame.identity
	if side == "Left" then
		sideRotation = CFrame.Angles(0, math.rad(180), 0)
	end

	local horizontalRotation =
		CFrame.Angles(0, 0, math.rad(-90))

	local transform = {
		CFrame =
			CFrame.new(clientWorldPosition)
			* plantPart.CFrame.Rotation
			* sideRotation
			* horizontalRotation,
		WorldPosition = clientWorldPosition,
		Length = length,
	}

	if not transform then
		warn(
			"[GooseServer] 无法计算鹅化物位置：",
			player.Name
		)
		return
	end

	local gooseTemplate =
		GooseModels:FindFirstChild(
			gooseItem.GooseId
		)

	if not gooseTemplate then
		warn(
			"[GooseServer] 找不到 GooseModel：",
			gooseItem.GooseId
		)
		return
	end

	local gooseObject =
		gooseTemplate:Clone()

	gooseObject.Name =
		"Goose_" .. gooseItem.ID

	--------------------------------------------------
	-- BasePart / MeshPart
	--------------------------------------------------

	if gooseObject:IsA("BasePart") then

		local originalSize =
			gooseObject.Size

		gooseObject:SetAttribute(
			"BaseSizeX",
			length
		)

		gooseObject:SetAttribute(
			"BaseSizeY",
			originalSize.Y
		)

		gooseObject:SetAttribute(
			"BaseSizeZ",
			originalSize.Z
		)

		gooseObject.Anchored = true
		gooseObject.CanCollide = false
		gooseObject.CanTouch = true
		gooseObject.CanQuery = true

		ApplyGooseScale(
			gooseObject,
			scaleMultiplier
		)

		gooseObject.CFrame =
			transform.CFrame

		--------------------------------------------------
		-- ✅ Model：放置后支持同步变大
		--------------------------------------------------

	elseif gooseObject:IsA("Model") then

		for _, object in ipairs(
			gooseObject:GetDescendants()
			) do

			if object:IsA("BasePart") then

				object.Anchored = true
				object.CanCollide = false

				local isHitbox = object.Name == "Hitbox"

				if isHitbox then
					object.CanTouch = true
					object.CanQuery = true
					object.Transparency = 1
				else
					object.CanTouch = false
					object.CanQuery = false
				end

			end

		end

		local visual =
			gooseObject:FindFirstChild("Visual", true)

		local hitbox =
			gooseObject:FindFirstChild("Hitbox", true)

		if hitbox and hitbox:IsA("BasePart") then
			gooseObject.PrimaryPart = hitbox
		end

		-- ✅ 计算 Visual 的原始 X 轴长度
		-- 兼容 Visual 是 BasePart 或 Model 的情况
		local originalSizeX
		if visual and visual:IsA("BasePart") then
			originalSizeX = visual.Size.X
		else
			local _, originalSize = gooseObject:GetBoundingBox()
			originalSizeX = originalSize.X
		end

		if not originalSizeX or originalSizeX <= 0 then

			gooseObject:Destroy()

			warn(
				"[GooseServer] GooseModel 原始长度无效：",
				gooseItem.GooseId
			)

			return
		end

		-- ✅ 记录基准缩放（用于后续植物成长时同步变大）
		local baseModelScale =
			length / originalSizeX

		gooseObject:SetAttribute(
			"BaseModelScale",
			baseModelScale
		)

		-- ✅ 应用缩放（会调用 ScaleTo）
		ApplyGooseScale(
			gooseObject,
			scaleMultiplier
		)

		-- ✅ 设置位置
		gooseObject:PivotTo(
			transform.CFrame
		)

	else

		warn(
			"[GooseServer] GooseModel 类型错误：",
			gooseObject.ClassName
		)

		gooseObject:Destroy()

		return
	end

	gooseObject:SetAttribute(
		"ItemId",
		gooseItem.ID
	)

	gooseObject:SetAttribute(
		"GooseId",
		gooseItem.GooseId
	)

	gooseObject:SetAttribute(
		"Side",
		side
	)

	gooseObject:SetAttribute(
		"IsLeft",
		side == "Left"
	)

	gooseObject:SetAttribute(
		"HeightRatio",
		heightRatio
	)

	gooseObject:SetAttribute(
		"Length",
		length
	)

	gooseObject:SetAttribute(
		"CurrentScaleMultiplier",
		scaleMultiplier
	)

	gooseObject.Parent =
		plot

	SetupGooseClickDetector(
		player,
		gooseObject
	)

	--------------------------------------------------
	-- 放置后自检：没有 ClickDetector 立刻报警
	-- 以后"点了没反应"能在 Output 里直接看到
	--------------------------------------------------
	task.defer(function()

		if not gooseObject.Parent then
			return
		end

		local hitbox =
			GetGooseHitbox(gooseObject)

		local detector =
			hitbox
			and hitbox:FindFirstChildOfClass("ClickDetector")

		if not detector then

			warn(
				"[GooseServer] 放置后没有 ClickDetector：",
				gooseObject:GetFullName(),
				"| 有 Hitbox：",
				hitbox and "是" or "否"
			)

		end

	end)

	if isEditing then
		for _, oldGoose in ipairs(plot:GetChildren()) do
			if oldGoose ~= gooseObject
				and oldGoose:GetAttribute("ItemId") == itemId then
				oldGoose:Destroy()
			end
		end
	end

	gooseItem.EquipState = true

	gooseItem.Position = {
		Side = side,
		IsLeft = (side == "Left"),
		Height = height,
		HeightRatio = heightRatio,
		Length = length,
		PlantScale = placementPlantScale,
	}

	gooseItem.WorldPosition = {
		X = transform.WorldPosition.X,
		Y = transform.WorldPosition.Y,
		Z = transform.WorldPosition.Z,
	}

	EditingGoose[player] = nil

	task.defer(function()
		if player.Parent then
			UpdatePlayerGoosePositions(player)
		end
	end)

	GoosePlacementResult:FireClient(
		player,
		true,
		gooseItem.ID,
		gooseItem.GooseId,
		"Placed"
	)

	print(
		"[GooseServer] 鹅化物放置成功：",
		player.Name,
		gooseData.Name,
		"方向：",
		side,
		"高度比例：",
		heightRatio,
		"长度：",
		length,
		"植物Scale：",
		placementPlantScale
	)

end)

--------------------------------------------------
-- 获取鹅化物背包
--------------------------------------------------

GetGooseInventory.OnServerInvoke =
	function(player)

		local timeout = 10
		local startTime = os.clock()

		while player.Parent
			and player:GetAttribute("DataLoaded") ~= true
			and os.clock() - startTime < timeout do

			task.wait(0.1)

		end

		local data =
			DataService:GetData(player)

		if not data then
			warn(
				"[GooseServer] 找不到玩家数据：",
				player.Name
			)
			return {}
		end

		if not data.GooseInventory then
			data.GooseInventory = {}
		end

		return data.GooseInventory

	end

--------------------------------------------------
-- 鹅化物交互请求
--------------------------------------------------

GooseInteraction.OnServerEvent:Connect(function(player, action, itemId)
	if typeof(action) ~= "string" then
		return
	end

	if action == "BeginEdit" then
		if typeof(itemId) ~= "string" then
			return
		end

		local data = DataService:GetData(player)
		if not data then
			return
		end

		local item
		for _, gooseItem in ipairs(data.GooseInventory or {}) do
			if gooseItem.ID == itemId then
				item = gooseItem
				break
			end
		end

		if not item or item.EquipState ~= true then
			return
		end

		local plot = PlotService:GetPlayerPlot(player)
		if not plot then
			return
		end

		local worldObject
		for _, object in ipairs(plot:GetChildren()) do
			if object:GetAttribute("ItemId") == itemId then
				worldObject = object
				break
			end
		end

		if not worldObject then
			return
		end

		EditingGoose[player] = itemId
		GooseInteraction:FireClient(player, "EditReady", itemId)

	elseif action == "Recycle" then
		if typeof(itemId) ~= "string" then
			return
		end

		RecycleGoose(player, itemId)

	elseif action == "CancelEdit" then
		if typeof(itemId) ~= "string" then
			EditingGoose[player] = nil
			return
		end

		if EditingGoose[player] == itemId then
			EditingGoose[player] = nil
		end
	end
end)

--------------------------------------------------
-- 玩家鹅化物加载
--------------------------------------------------

local function LoadPlayerGoose(player)

	if player:GetAttribute("GooseLoaded") == true then
		return
	end

	while player.Parent
		and player:GetAttribute("DataLoaded") ~= true do

		task.wait(0.1)

	end

	if not player.Parent then
		return
	end

	local plot

	while player.Parent and not plot do

		plot =
			PlotService:GetPlayerPlot(player)

		if not plot then
			task.wait(0.1)
		end

	end

	if not plot then
		return
	end

	local plant

	while player.Parent and not plant do

		plant =
			plot:FindFirstChild(
				"PlayerPlant"
			)

		if not plant then
			task.wait(0.1)
		end

	end

	if not plant
		or not plant:IsA("Model") then
		return
	end

	local plantPart =
		plant.PrimaryPart

	if not plantPart
		or not plantPart:IsA("BasePart") then

		warn(
			"[GooseServer] 加载鹅化物失败，PlayerPlant 没有 PrimaryPart：",
			player.Name
		)

		return

	end

	local data =
		DataService:GetData(player)

	if not data then

		warn(
			"[GooseServer] 加载鹅化物失败，玩家数据不存在：",
			player.Name
		)

		return

	end

	if not data.GooseInventory then
		data.GooseInventory = {}
	end

	for _, object in ipairs(
		plot:GetChildren()
		) do

		if object:GetAttribute("ItemId") then
			object:Destroy()
		end

	end

	for _, gooseItem in ipairs(
		data.GooseInventory
		) do

		if gooseItem.EquipState == true then

			local positionData =
				gooseItem.Position

			if not positionData then
				continue
			end

			local side =
				positionData.Side

			local length =
				tonumber(positionData.Length)

			if side ~= "Left"
				and side ~= "Right" then
				continue
			end

			if not length
				or length <= 0 then
				continue
			end

			local currentPlantScale =
				GetPlantScale(plant)

			local placementPlantScale =
				tonumber(
					positionData.PlantScale
				)

			if not placementPlantScale
				or placementPlantScale <= 0 then

				placementPlantScale = 1

				positionData.PlantScale =
					placementPlantScale

			end

			local heightRatio =
				tonumber(
					positionData.HeightRatio
				)

			if not heightRatio then

				local oldHeight =
					tonumber(
						positionData.Height
					)

				if oldHeight then

					local currentPlantSizeY =
						plantPart.Size.Y

					local currentScale =
						GetPlantScale(plant)

					local basePlantSizeY =
						currentPlantSizeY
						/
						math.max(currentScale, 0.0001)

					heightRatio =
						(
							oldHeight
							+
							basePlantSizeY / 2
						)
						/
						basePlantSizeY

				else

					heightRatio = 0.5

				end

				heightRatio =
					math.clamp(
						heightRatio,
						0,
						1
					)

				positionData.HeightRatio =
					heightRatio

			end

			local scaleMultiplier =
				currentPlantScale
				/
				placementPlantScale

			if scaleMultiplier <= 0 then
				scaleMultiplier = 1
			end

			local transform =
				CalculateGooseTransform(
					plant,
					side,
					heightRatio,
					length,
					scaleMultiplier
				)

			if not transform then
				continue
			end

			local gooseTemplate =
				GooseModels:FindFirstChild(
					gooseItem.GooseId
				)

			if not gooseTemplate then

				warn(
					"[GooseServer] 找不到 GooseModel：",
					gooseItem.GooseId
				)

				continue

			end

			local gooseObject =
				gooseTemplate:Clone()

			gooseObject.Name =
				"Goose_" .. gooseItem.ID

			--------------------------------------------------
			-- BasePart
			--------------------------------------------------

			if gooseObject:IsA("BasePart") then

				local originalSize =
					gooseObject.Size

				gooseObject:SetAttribute(
					"BaseSizeX",
					length
				)

				gooseObject:SetAttribute(
					"BaseSizeY",
					originalSize.Y
				)

				gooseObject:SetAttribute(
					"BaseSizeZ",
					originalSize.Z
				)

				gooseObject.Anchored = true
				gooseObject.CanCollide = false
				gooseObject.CanTouch = false
				gooseObject.CanQuery = false

				ApplyGooseScale(
					gooseObject,
					scaleMultiplier
				)

				gooseObject.CFrame =
					transform.CFrame

				--------------------------------------------------
				-- ✅ Model：加载后也能同步变大
				--------------------------------------------------

			elseif gooseObject:IsA("Model") then

				for _, object in ipairs(
					gooseObject:GetDescendants()
					) do

					if object:IsA("BasePart") then

						object.Anchored = true
						object.CanCollide = false

						if object.Name == "Hitbox" then
							object.CanTouch = true
							object.CanQuery = true
							object.Transparency = 1
						else
							object.CanTouch = false
							object.CanQuery = false
						end

					end

				end

				local hitbox =
					gooseObject:FindFirstChild("Hitbox", true)

				if hitbox and hitbox:IsA("BasePart") then
					gooseObject.PrimaryPart = hitbox
				end

				local visual =
					gooseObject:FindFirstChild("Visual", true)

				local originalSizeX

				if visual and visual:IsA("BasePart") then
					originalSizeX = visual.Size.X
				else
					local _, originalSize = gooseObject:GetBoundingBox()
					originalSizeX = originalSize.X
				end

				if not originalSizeX or originalSizeX <= 0 then

					gooseObject:Destroy()
					continue

				end

				local baseModelScale =
					length / originalSizeX

				gooseObject:SetAttribute(
					"BaseModelScale",
					baseModelScale
				)

				ApplyGooseScale(
					gooseObject,
					scaleMultiplier
				)

				gooseObject:PivotTo(
					transform.CFrame
				)

			else

				gooseObject:Destroy()

				continue

			end

			gooseObject:SetAttribute(
				"ItemId",
				gooseItem.ID
			)

			gooseObject:SetAttribute(
				"GooseId",
				gooseItem.GooseId
			)

			gooseObject:SetAttribute(
				"Side",
				side
			)

			local isLeft = positionData.IsLeft
			if isLeft == nil then
				isLeft = (side == "Left")
			end

			gooseObject:SetAttribute(
				"IsLeft",
				isLeft
			)

			gooseObject:SetAttribute(
				"HeightRatio",
				heightRatio
			)

			gooseObject:SetAttribute(
				"Length",
				length
			)

			gooseObject:SetAttribute(
				"CurrentScaleMultiplier",
				scaleMultiplier
			)

			gooseObject.Parent =
				plot

			SetupGooseClickDetector(
				player,
				gooseObject
			)

			positionData.Height =
				(
					-plantPart.Size.Y / 2
					+
					heightRatio * plantPart.Size.Y
				)

			positionData.HeightRatio =
				heightRatio

			positionData.PlantScale =
				placementPlantScale

		end

	end

	player:SetAttribute(
		"GooseLoaded",
		true
	)

	UpdatePlayerGoosePositions(player)

	print(
		"[GooseServer] 玩家鹅化物加载完成：",
		player.Name
	)

end

Players.PlayerRemoving:Connect(function(player)
	EditingGoose[player] = nil
end)

Players.PlayerAdded:Connect(function(player)

	task.spawn(function()
		LoadPlayerGoose(player)
	end)

end)

for _, player in ipairs(
	Players:GetPlayers()
	) do

	task.spawn(function()
		LoadPlayerGoose(player)
	end)

end

--------------------------------------------------
-- 植物平滑成长时同步鹅化物
--------------------------------------------------

local updateAccumulator = 0
local UPDATE_INTERVAL = 1 / 30

RunService.Heartbeat:Connect(function(deltaTime)

	updateAccumulator += deltaTime

	if updateAccumulator < UPDATE_INTERVAL then
		return
	end

	updateAccumulator = 0

	for _, player in ipairs(
		Players:GetPlayers()
		) do

		if player:GetAttribute("GooseLoaded") == true then

			UpdatePlayerGoosePositions(player)

		end

	end

end)