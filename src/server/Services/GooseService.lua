local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

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
-- GooseModels
--------------------------------------------------

local GooseModels =
	ReplicatedStorage:WaitForChild("GooseModels")

--------------------------------------------------
-- 配置
--------------------------------------------------

local LEFT_VISUAL_OFFSET = -3
local GAP = 0.05

--------------------------------------------------
-- GooseService
--------------------------------------------------

local GooseService = {}

--------------------------------------------------
-- 正在跟随的玩家
--------------------------------------------------

local FollowingPlayers = {}

--------------------------------------------------
-- 获取玩家植物
--------------------------------------------------

function GooseService:GetPlayerPlant(player)

	local plot =
		PlotService:GetPlayerPlot(player)

	if not plot then
		return nil, nil
	end

	local plant =
		plot:FindFirstChild("PlayerPlant")

	if not plant
		or not plant:IsA("Model") then

		return nil, plot

	end

	local plantPart =
		plant.PrimaryPart

	if not plantPart
		or not plantPart:IsA("BasePart") then

		return nil, plot

	end

	return plant, plot

end

--------------------------------------------------
-- 获取植物当前 Scale
--------------------------------------------------

function GooseService:GetPlantScale(plant)

	local scale =
		plant:GetScale()

	if typeof(scale) ~= "number"
		or scale <= 0 then

		return 1

	end

	return scale

end

--------------------------------------------------
-- 计算植物缩放倍率
--
-- 例如：
--
-- 放置时植物 = 1
-- 当前植物 = 2
--
-- multiplier = 2
--
-- 鹅化物就放大 2 倍
--------------------------------------------------

function GooseService:GetScaleMultiplier(
	plant,
	placementPlantScale
)

	local currentPlantScale =
		self:GetPlantScale(plant)

	placementPlantScale =
		tonumber(placementPlantScale)
		or 1

	if placementPlantScale <= 0 then
		placementPlantScale = 1
	end

	local multiplier =
		currentPlantScale
		/
		placementPlantScale

	if multiplier <= 0 then
		multiplier = 1
	end

	return multiplier

end

--------------------------------------------------
-- 计算鹅化物当前 Transform
--------------------------------------------------

function GooseService:CalculateGooseTransform(
	plant,
	side,
	heightRatio,
	baseLength,
	scaleMultiplier
)

	local plantPart =
		plant.PrimaryPart

	if not plantPart then
		return nil
	end

	--------------------------------------------------
	-- 当前植物位置
	--------------------------------------------------

	local plantCFrame =
		plantPart.CFrame

	local plantSize =
		plantPart.Size

	--------------------------------------------------
	-- 鹅化物当前长度
	--
	-- 植物 ×2
	-- 鹅化物长度也 ×2
	--------------------------------------------------

	local currentLength =
		baseLength * scaleMultiplier

	--------------------------------------------------
	-- 植物当前宽度
	--------------------------------------------------

	local plantHalfWidth =
		plantSize.X / 2

	--------------------------------------------------
	-- 高度比例
	--
	-- 0 = 植物底部
	-- 0.5 = 植物中间
	-- 1 = 植物顶部
	--------------------------------------------------

	local safeHeightRatio =
		tonumber(heightRatio)

	if safeHeightRatio == nil then
		safeHeightRatio = 0.5
	end

	safeHeightRatio =
		math.clamp(
			safeHeightRatio,
			0,
			1
		)

	--------------------------------------------------
	-- 根据植物当前高度计算实际高度
	--------------------------------------------------

	local currentHeight =
		-plantSize.Y / 2
		+
		safeHeightRatio * plantSize.Y

	--------------------------------------------------
	-- 左右方向
	--------------------------------------------------

	local direction = 1

	if side == "Left" then
		direction = -1
	end

	--------------------------------------------------
	-- 计算鹅化物中心 X
	--------------------------------------------------

	local gooseCenterX =
		direction *
		(
			plantHalfWidth
			+
			currentLength / 2
			+
			GAP
		)

	--------------------------------------------------
	-- 左侧补偿
	--
	-- 因为左侧有180°旋转
	--------------------------------------------------

	if side == "Left" then

		gooseCenterX +=
			LEFT_VISUAL_OFFSET
			* scaleMultiplier

	end

	--------------------------------------------------
	-- 局部坐标
	--------------------------------------------------

	local localPosition =
		Vector3.new(
			gooseCenterX,
			currentHeight,
			0
		)

	--------------------------------------------------
	-- 转换世界坐标
	--------------------------------------------------

	local worldPosition =
		plantCFrame:PointToWorldSpace(
			localPosition
		)

	--------------------------------------------------
	-- 左右旋转
	--------------------------------------------------

	local sideRotation =
		CFrame.identity

	if side == "Left" then

		sideRotation =
			CFrame.Angles(
				0,
				math.rad(180),
				0
			)

	end

	--------------------------------------------------
	-- 横向旋转
	--------------------------------------------------

	local horizontalRotation =
		CFrame.Angles(
			0,
			0,
			math.rad(-90)
		)

	--------------------------------------------------
	-- 最终 CFrame
	--------------------------------------------------

	local targetCFrame =
		CFrame.new(worldPosition)
		*
		plantCFrame.Rotation
		*
		sideRotation
		*
		horizontalRotation

	return {

		CFrame = targetCFrame,

		WorldPosition = worldPosition,

		Length = currentLength,

	}

end

--------------------------------------------------
-- 应用鹅化物缩放
--------------------------------------------------

function GooseService:ApplyGooseScale(
	gooseObject,
	scaleMultiplier
)

	--------------------------------------------------
	-- BasePart / MeshPart
	--------------------------------------------------

	if gooseObject:IsA("BasePart") then

		local baseSizeX =
			gooseObject:GetAttribute(
				"BaseSizeX"
			)

		local baseSizeY =
			gooseObject:GetAttribute(
				"BaseSizeY"
			)

		local baseSizeZ =
			gooseObject:GetAttribute(
				"BaseSizeZ"
			)

		if not baseSizeX
			or not baseSizeY
			or not baseSizeZ then

			return

		end

		gooseObject.Size =
			Vector3.new(

				baseSizeX
				* scaleMultiplier,

				baseSizeY
				* scaleMultiplier,

				baseSizeZ
				* scaleMultiplier

			)

		--------------------------------------------------
		-- Model
		--------------------------------------------------

	elseif gooseObject:IsA("Model") then

		local baseModelScale =
			gooseObject:GetAttribute(
				"BaseModelScale"
			)

		if not baseModelScale then
			return
		end

		gooseObject:ScaleTo(
			baseModelScale
				*
				scaleMultiplier
		)

	end

end

--------------------------------------------------
-- 查找已经生成的鹅化物
--------------------------------------------------

function GooseService:GetPlacedGooseObjects(
	plot
)

	local objects = {}

	for _, object in ipairs(
		plot:GetChildren()
		) do

		local itemId =
			object:GetAttribute("ItemId")

		if itemId then

			objects[itemId] =
				object

		end

	end

	return objects

end

--------------------------------------------------
-- 更新一个玩家所有鹅化物
--
-- 这个函数就是最重要的。
--
-- 植物变大时调用它：
--
-- 1. 鹅化物位置变化
-- 2. 鹅化物长度变化
-- 3. 鹅化物宽度变化
-- 4. 鹅化物高度变化
--------------------------------------------------

function GooseService:UpdatePlayerGoosePositions(
	player
)

	local data =
		DataService:GetData(player)

	if not data
		or not data.GooseInventory then

		return

	end

	local plant, plot =
		self:GetPlayerPlant(player)

	if not plant
		or not plot then

		return

	end

	local placementObjects =
		self:GetPlacedGooseObjects(
			plot
		)

	--------------------------------------------------
	-- 遍历玩家鹅化物
	--------------------------------------------------

	for _, gooseItem in ipairs(
		data.GooseInventory
		) do

		if gooseItem.EquipState == true then

			local positionData =
				gooseItem.Position

			if positionData then

				local side =
					positionData.Side

				local length =
					tonumber(
						positionData.Length
					)

				local heightRatio =
					tonumber(
						positionData.HeightRatio
					)

				--------------------------------------------------
				-- 兼容旧数据
				--------------------------------------------------

				if not heightRatio then

					local oldHeight =
						tonumber(
							positionData.Height
						)

					local plantPart =
						plant.PrimaryPart

					if oldHeight
						and plantPart then

						local plantHeight =
							plantPart.Size.Y

						if plantHeight > 0 then

							heightRatio =
								(
									oldHeight
									+
									plantHeight / 2
								)
								/
								plantHeight

						end

					end

				end

				if not heightRatio then
					heightRatio = 0.5
				end

				heightRatio =
					math.clamp(
						heightRatio,
						0,
						1
					)

				--------------------------------------------------
				-- 检查数据
				--------------------------------------------------

				if (
					side == "Left"
						or side == "Right"
					)
						and length
						and length > 0 then

					--------------------------------------------------
					-- 放置时植物 Scale
					--------------------------------------------------

					local placementPlantScale =
						tonumber(
							positionData.PlantScale
						)
						or 1

					--------------------------------------------------
					-- 当前植物 / 放置时植物
					--------------------------------------------------

					local scaleMultiplier =
						self:GetScaleMultiplier(
							plant,
							placementPlantScale
						)

					--------------------------------------------------
					-- 计算新位置
					--------------------------------------------------

					local transform =
						self:CalculateGooseTransform(
							plant,
							side,
							heightRatio,
							length,
							scaleMultiplier
						)

					--------------------------------------------------
					-- 找实际鹅化物
					--------------------------------------------------

					local gooseObject =
						placementObjects[
						gooseItem.ID
					]

					if gooseObject
						and transform then

						--------------------------------------------------
						-- 更新大小
						--------------------------------------------------

						self:ApplyGooseScale(
							gooseObject,
							scaleMultiplier
						)

						--------------------------------------------------
						-- 更新位置
						--------------------------------------------------

						if gooseObject:IsA(
							"BasePart"
							) then

							gooseObject.CFrame =
								transform.CFrame

						elseif gooseObject:IsA(
							"Model"
							) then

							gooseObject:PivotTo(
								transform.CFrame
							)

						end

						--------------------------------------------------
						-- 更新属性
						--------------------------------------------------

						gooseObject:SetAttribute(
							"HeightRatio",
							heightRatio
						)

						gooseObject:SetAttribute(
							"CurrentScaleMultiplier",
							scaleMultiplier
						)

					end

				end

			end

		end

	end

end

--------------------------------------------------
-- 开始自动跟随植物
--
-- 这里不依赖 PlantService。
--
-- 所以不会产生：
--
-- PlantService -> GooseService
-- GooseService -> PlantService
--
-- 的循环 require。
--------------------------------------------------

function GooseService:StartFollowing(
	player
)

	if FollowingPlayers[player] then
		return
	end

	FollowingPlayers[player] = true

	task.spawn(function()

		while player.Parent
			and FollowingPlayers[player] do

			self:UpdatePlayerGoosePositions(
				player
			)

			--------------------------------------------------
			-- 0.05秒更新一次
			--
			-- 植物平滑放大时，
			-- 鹅化物也会比较平滑地跟随。
			--------------------------------------------------

			task.wait(0.05)

		end

	end)

end

--------------------------------------------------
-- 停止跟随
--------------------------------------------------

function GooseService:StopFollowing(
	player
)

	FollowingPlayers[player] = nil

end

--------------------------------------------------
-- 创建并加载玩家以前的鹅化物
--------------------------------------------------

function GooseService:LoadPlayerGoose(
	player
)

	if player:GetAttribute(
		"GooseLoaded"
		) == true then

		return true

	end

	--------------------------------------------------
	-- 等待数据
	--------------------------------------------------

	while player.Parent
		and player:GetAttribute(
			"DataLoaded"
		) ~= true do

		task.wait(0.1)

	end

	if not player.Parent then
		return false
	end

	--------------------------------------------------
	-- 获取数据
	--------------------------------------------------

	local data =
		DataService:GetData(player)

	if not data then

		warn(
			"[GooseService] 玩家数据不存在：",
			player.Name
		)

		return false

	end

	if not data.GooseInventory then
		data.GooseInventory = {}
	end

	--------------------------------------------------
	-- 获取土地
	--------------------------------------------------

	local plot

	while player.Parent
		and not plot do

		plot =
			PlotService:GetPlayerPlot(
				player
			)

		if not plot then
			task.wait(0.1)
		end

	end

	if not plot then
		return false
	end

	--------------------------------------------------
	-- 等待植物
	--------------------------------------------------

	local plant

	while player.Parent
		and not plant do

		plant =
			plot:FindFirstChild(
				"PlayerPlant"
			)

		if not plant then
			task.wait(0.1)
		end

	end

	if not plant then

		warn(
			"[GooseService] 没有找到 PlayerPlant：",
			player.Name
		)

		return false

	end

	--------------------------------------------------
	-- 先删除旧的 Goose
	--
	-- 防止重复加载
	--------------------------------------------------

	for _, object in ipairs(
		plot:GetChildren()
		) do

		if object:GetAttribute(
			"ItemId"
			) then

			object:Destroy()

		end

	end

	--------------------------------------------------
	-- 当前植物 Scale
	--------------------------------------------------

	local currentPlantScale =
		self:GetPlantScale(
			plant
		)

	--------------------------------------------------
	-- 加载
	--------------------------------------------------

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
				tonumber(
					positionData.Length
				)

			local heightRatio =
				tonumber(
					positionData.HeightRatio
				)

			--------------------------------------------------
			-- 兼容旧 Height
			--------------------------------------------------

			if not heightRatio then

				local oldHeight =
					tonumber(
						positionData.Height
					)

				local plantPart =
					plant.PrimaryPart

				if oldHeight
					and plantPart then

					local plantHeight =
						plantPart.Size.Y

					if plantHeight > 0 then

						heightRatio =
							(
								oldHeight
								+
								plantHeight / 2
							)
							/
							plantHeight

					end

				end

			end

			if not heightRatio then
				heightRatio = 0.5
			end

			heightRatio =
				math.clamp(
					heightRatio,
					0,
					1
				)

			--------------------------------------------------
			-- 数据检查
			--------------------------------------------------

			if (
				side ~= "Left"
					and side ~= "Right"
				)
					or not length
					or length <= 0 then

				warn(
					"[GooseService] 鹅化物位置数据错误：",
					gooseItem.ID
				)

				continue

			end

			--------------------------------------------------
			-- 找模板
			--------------------------------------------------

			local template =
				GooseModels:FindFirstChild(
					gooseItem.GooseId
				)

			if not template then

				warn(
					"[GooseService] 找不到 GooseModel：",
					gooseItem.GooseId
				)

				continue

			end

			--------------------------------------------------
			-- 放置时植物 Scale
			--------------------------------------------------

			local placementPlantScale =
				tonumber(
					positionData.PlantScale
				)
				or 1

			--------------------------------------------------
			-- 当前植物相对于放置时的倍率
			--------------------------------------------------

			local scaleMultiplier =
				currentPlantScale
				/
				placementPlantScale

			if scaleMultiplier <= 0 then
				scaleMultiplier = 1
			end

			--------------------------------------------------
			-- 计算位置
			--------------------------------------------------

			local transform =
				self:CalculateGooseTransform(
					plant,
					side,
					heightRatio,
					length,
					scaleMultiplier
				)

			if not transform then
				continue
			end

			--------------------------------------------------
			-- Clone
			--------------------------------------------------

			local gooseObject =
				template:Clone()

			gooseObject.Name =
				"Goose_" .. gooseItem.ID

			--------------------------------------------------
			-- BasePart
			--------------------------------------------------

			if gooseObject:IsA(
				"BasePart"
				) then

				local originalSize =
					gooseObject.Size

				--------------------------------------------------
				-- 注意：
				-- BaseSizeX 保存的是玩家选择的 Length
				--------------------------------------------------

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

				self:ApplyGooseScale(
					gooseObject,
					scaleMultiplier
				)

				gooseObject.CFrame =
					transform.CFrame

				--------------------------------------------------
				-- Model
				--------------------------------------------------

			elseif gooseObject:IsA(
				"Model"
				) then

				for _, object in ipairs(
					gooseObject:GetDescendants()
					) do

					if object:IsA(
						"BasePart"
						) then

						object.Anchored = true
						object.CanCollide = false
						object.CanTouch = false
						object.CanQuery = false

					end

				end

				local _, originalSize =
					gooseObject:GetBoundingBox()

				if originalSize.X <= 0 then

					gooseObject:Destroy()

					continue

				end

				local baseModelScale =
					length
					/
					originalSize.X

				gooseObject:SetAttribute(
					"BaseModelScale",
					baseModelScale
				)

				self:ApplyGooseScale(
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

			--------------------------------------------------
			-- 属性
			--------------------------------------------------

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

		end

	end

	--------------------------------------------------
	-- 标记加载完成
	--------------------------------------------------

	player:SetAttribute(
		"GooseLoaded",
		true
	)

	print(
		"[GooseService] 玩家鹅化物加载完成：",
		player.Name
	)

	--------------------------------------------------
	-- 开始自动跟随
	--------------------------------------------------

	self:StartFollowing(player)

	return true

end

--------------------------------------------------
-- 玩家离开
--------------------------------------------------

Players.PlayerRemoving:Connect(function(
	player
)

	GooseService:StopFollowing(
		player
	)

end)

return GooseService
