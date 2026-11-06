local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local leftVisualOffset = -1
local currentWorldPosition = nil

--------------------------------------------------
-- RemoteEvent
--------------------------------------------------

local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")

local PlaceGoose =
	RemoteEvent:WaitForChild("PlaceGoose")

local GooseInteraction =
	RemoteEvent:WaitForChild("GooseInteraction")

--------------------------------------------------
-- BindableEvent
--------------------------------------------------

local StartGoosePlacementEvent =
	ReplicatedStorage:WaitForChild("BindableEvent")
	:WaitForChild("StartGoosePlacement")

--------------------------------------------------
-- Config
--------------------------------------------------

local GooseConfig =
	require(
		ReplicatedStorage.Config:WaitForChild("GooseConfig")
	)

local GoosePlacementConfig =
	require(
		ReplicatedStorage.Config:WaitForChild("GoosePlacementConfig")
	)

--------------------------------------------------
-- Goose Models
--------------------------------------------------

local GooseModels =
	ReplicatedStorage:WaitForChild("GooseModels")

--------------------------------------------------
-- 地图
--------------------------------------------------

local map =
	workspace:WaitForChild("Grow A Garden map")

--------------------------------------------------
-- 状态
--------------------------------------------------

local placing = false

local currentItemId = nil
local currentGooseId = nil

local currentSide = "Right"
local currentHeight = 0

local currentLength =
	GoosePlacementConfig.MinLength

local preview = nil

--------------------------------------------------
-- 编辑状态
--------------------------------------------------

local editing = false
local editingItemId = nil

--------------------------------------------------
-- 服务器传来的原始编辑数据
--------------------------------------------------

local editInitialCFrame = nil

local editReadyPending = nil

--------------------------------------------------
-- 编辑时是否已经初始化预览位置
--------------------------------------------------

local editPreviewInitialized = false

--------------------------------------------------
-- 提前声明
--------------------------------------------------

local ConfirmPlacement

--------------------------------------------------
-- 找到玩家自己的土地
--------------------------------------------------

local function GetPlayerPlot()

	local plotName =
		player:GetAttribute("PlotName")

	if not plotName then

		warn(
			"[GoosePlacementClient] 找不到 PlotName"
		)

		return nil
	end

	local plot =
		map:FindFirstChild(plotName)

	if not plot then

		warn(
			"[GoosePlacementClient] 找不到玩家土地：",
			plotName
		)

		return nil
	end

	return plot
end

--------------------------------------------------
-- 找到玩家植物
--------------------------------------------------

local function GetPlayerPlant()

	local plot =
		GetPlayerPlot()

	if not plot then
		return nil
	end

	local plant =
		plot:FindFirstChild("PlayerPlant")

	if not plant then
		return nil
	end

	if not plant:IsA("Model") then

		warn(
			"[GoosePlacementClient] PlayerPlant 不是 Model：",
			plant.ClassName
		)

		return nil
	end

	return plant
end

--------------------------------------------------
-- 等待玩家植物真正准备完成
--
-- 重点：
-- 重新进入游戏时 PlayerPlant 可能已经存在，
-- 但是 PrimaryPart 还没有完全准备好。
--
-- 不再要求等待植物下一次成长。
--------------------------------------------------

local function WaitForPlayerPlantReady(timeout)

	timeout =
		timeout or 5

	local startTime =
		os.clock()

	while os.clock() - startTime < timeout do

		local plant =
			GetPlayerPlant()

		if plant then

			local primaryPart =
				plant.PrimaryPart

			if primaryPart
				and primaryPart:IsA("BasePart") then

				return plant
			end
		end

		RunService.Heartbeat:Wait()
	end

	return nil
end

--------------------------------------------------
-- 删除预览
--------------------------------------------------

local function RemovePreview()

	if preview then

		preview:Destroy()

		preview = nil
	end

end

--------------------------------------------------
-- 设置预览物体属性
--------------------------------------------------

local function SetupPreviewPart(part)

	if not part:IsA("BasePart") then
		return
	end

	part.Anchored = true

	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false

	part.CastShadow = false

	part.Transparency = 0

	part.LocalTransparencyModifier = 0

	part.Material =
		Enum.Material.ForceField
end

--------------------------------------------------
-- 给预览加高亮
--------------------------------------------------

local function AddPreviewHighlight(target)

	if not target then
		return
	end

	local old =
		target:FindFirstChild("PreviewHighlight")

	if old then
		old:Destroy()
	end

	local highlight =
		Instance.new("Highlight")

	highlight.Name =
		"PreviewHighlight"

	highlight.Adornee =
		target

	highlight.DepthMode =
		Enum.HighlightDepthMode.AlwaysOnTop

	highlight.FillColor =
		Color3.fromRGB(
			120,
			220,
			140
		)

	highlight.FillTransparency =
		0.65

	highlight.OutlineColor =
		Color3.fromRGB(
			255,
			255,
			255
		)

	highlight.OutlineTransparency =
		0

	highlight.Parent =
		target
end

--------------------------------------------------
-- 创建预览
--------------------------------------------------

local function CreatePreview()

	RemovePreview()

	if not currentGooseId then

		warn(
			"[GoosePlacementClient] currentGooseId 为空"
		)

		return false
	end

	local gooseTemplate =
		GooseModels:FindFirstChild(
			currentGooseId
		)

	if not gooseTemplate then

		warn(
			"[GoosePlacementClient] 找不到鹅化物模型：",
			currentGooseId
		)

		return false
	end

	--------------------------------------------------
	-- Clone
	--------------------------------------------------

	preview =
		gooseTemplate:Clone()

	preview.Name =
		"GoosePlacementPreview"

	--------------------------------------------------
	-- BasePart
	--------------------------------------------------

	if preview:IsA("BasePart") then

		SetupPreviewPart(preview)

		preview:SetAttribute(
			"OriginalSize",
			preview.Size
		)

		local startPosition =
			camera.CFrame.Position
			+ camera.CFrame.LookVector * 8

		preview.CFrame =
			CFrame.new(startPosition)

		preview.Parent =
			workspace

		AddPreviewHighlight(
			preview
		)

		print(
			"[GoosePlacementClient] 预览创建成功：",
			currentGooseId
		)

		return true
	end

	--------------------------------------------------
	-- Model
	--------------------------------------------------

	if preview:IsA("Model") then

		local hitbox =
			preview:FindFirstChild(
				"Hitbox",
				true
			)

		local visual =
			preview:FindFirstChild(
				"Visual",
				true
			)

		if not hitbox
			or not hitbox:IsA("BasePart") then

			warn(
				"[GoosePlacementClient] GooseModel 缺少 Hitbox：",
				currentGooseId
			)

			preview:Destroy()
			preview = nil

			return false
		end

		if not visual then

			warn(
				"[GoosePlacementClient] GooseModel 缺少 Visual：",
				currentGooseId
			)

			preview:Destroy()
			preview = nil

			return false
		end

		if not (
			visual:IsA("BasePart")
				or visual:IsA("Model")
			) then

			warn(
				"[GoosePlacementClient] Visual 类型错误：",
				currentGooseId,
				visual.ClassName
			)

			preview:Destroy()
			preview = nil

			return false
		end

		preview.PrimaryPart =
			hitbox

		for _, object in ipairs(
			preview:GetDescendants()
			) do

			if object:IsA("BasePart") then

				SetupPreviewPart(
					object
				)

				if object == hitbox then

					object.Transparency =
						1

					object.CanQuery =
						false
				end
			end
		end

		--------------------------------------------------
		-- 计算 Visual X 长度
		--------------------------------------------------

		local originalSizeX

		if visual:IsA("BasePart") then

			originalSizeX =
				visual.Size.X

		else

			local _, visualSize =
				visual:GetBoundingBox()

			originalSizeX =
				visualSize.X
		end

		preview:SetAttribute(
			"OriginalSizeX",
			originalSizeX
		)

		local startPosition =
			camera.CFrame.Position
			+ camera.CFrame.LookVector * 8

		preview:PivotTo(
			CFrame.new(startPosition)
		)

		preview.Parent =
			workspace

		AddPreviewHighlight(
			preview
		)

		print(
			"[GoosePlacementClient] Model预览创建成功：",
			currentGooseId
		)

		return true
	end

	warn(
		"[GoosePlacementClient] GooseModels 中对象类型错误：",
		preview.ClassName
	)

	preview:Destroy()
	preview = nil

	return false
end

--------------------------------------------------
-- 根据当前参数计算正常预览位置
--------------------------------------------------

local function CalculateNormalPreview()

	local plant =
		GetPlayerPlant()

	if not plant then
		return nil
	end

	local plantPart =
		plant.PrimaryPart

	if not plantPart
		or not plantPart:IsA("BasePart") then

		return nil
	end

	local plantCFrame =
		plantPart.CFrame

	local plantSize =
		plantPart.Size

	--------------------------------------------------
	-- 鼠标位置
	--------------------------------------------------

	local mousePosition =
		mouse.Hit.Position

	--------------------------------------------------
	-- 世界 -> 植物局部
	--------------------------------------------------

	local localPosition =
		plantCFrame:PointToObjectSpace(
			mousePosition
		)

	--------------------------------------------------
	-- 高度
	--------------------------------------------------

	currentHeight =
		localPosition.Y

	--------------------------------------------------
	-- 判断左右
	--------------------------------------------------

	local mouseLocation =
		UserInputService:GetMouseLocation()

	local plantScreenPosition =
		camera:WorldToViewportPoint(
			plantPart.Position
		)

	if mouseLocation.X <
		plantScreenPosition.X then

		currentSide =
			"Left"

	else

		currentSide =
			"Right"
	end

	--------------------------------------------------
	-- 方向
	--------------------------------------------------

	local direction = 1

	if currentSide == "Left" then
		direction = -1
	end

	--------------------------------------------------
	-- 植物半宽
	--------------------------------------------------

	local plantHalfWidth =
		plantSize.X / 2

	--------------------------------------------------
	-- 和服务器一致
	--------------------------------------------------

	local gap = 0.05

	local centerX =
		direction *
		(
			plantHalfWidth
			+
			currentLength / 2
			+
			gap
		)

	if currentSide == "Left" then

		centerX +=
			leftVisualOffset
	end

	--------------------------------------------------
	-- 局部位置
	--------------------------------------------------

	local localPreviewPosition =
		Vector3.new(
			centerX,
			currentHeight,
			0
		)

	--------------------------------------------------
	-- 局部 -> 世界
	--------------------------------------------------

	local worldPosition =
		plantCFrame:PointToWorldSpace(
			localPreviewPosition
		)

	return plantCFrame, worldPosition
end

--------------------------------------------------
-- 更新预览
--------------------------------------------------

local function UpdatePreview()

	if not placing then
		return
	end

	if not preview then
		return
	end

	--------------------------------------------------
	-- 等待植物
	--------------------------------------------------

	local plant =
		WaitForPlayerPlantReady(0.15)

	if not plant then
		return
	end

	local plantPart =
		plant.PrimaryPart

	if not plantPart
		or not plantPart:IsA("BasePart") then

		return
	end

	--------------------------------------------------
	-- 编辑模式第一次更新
	--
	-- 直接使用服务器传来的原始 CFrame。
	--
	-- 这样重新进入游戏后，
	-- 不需要等待植物成长，
	-- 也不会因为鼠标位置导致鹅跳走。
	--------------------------------------------------

	if editing
		and editInitialCFrame
		and not editPreviewInitialized then

		local plantCFrame =
			plantPart.CFrame

		local localPosition =
			plantCFrame:PointToObjectSpace(
				editInitialCFrame.Position
			)

		currentHeight =
			localPosition.Y

		currentWorldPosition =
			editInitialCFrame.Position

		--------------------------------------------------
		-- 根据原始位置判断左右
		--------------------------------------------------

		if localPosition.X < 0 then
			currentSide = "Left"
		else
			currentSide = "Right"
		end

		--------------------------------------------------
		-- 先使用原始 CFrame
		--------------------------------------------------

		if preview:IsA("BasePart") then

			local originalSize =
				preview:GetAttribute(
					"OriginalSize"
				)

			if originalSize
				and originalSize.X > 0 then

				preview.Size =
					Vector3.new(
						currentLength,
						originalSize.Y,
						originalSize.Z
					)
			end

			preview.CFrame =
				editInitialCFrame

		elseif preview:IsA("Model") then

			local originalSizeX =
				preview:GetAttribute(
					"OriginalSizeX"
				)

			if originalSizeX
				and originalSizeX > 0 then

				local scale =
					currentLength
					/
					originalSizeX

				preview:ScaleTo(
					scale
				)
			end

			preview:PivotTo(
				editInitialCFrame
			)
		end

		editPreviewInitialized =
			true

		return
	end

	--------------------------------------------------
	-- 普通预览 / 编辑后的移动
	--------------------------------------------------

	local plantCFrame, worldPosition =
		CalculateNormalPreview()

	if not plantCFrame
		or not worldPosition then

		return
	end

	currentWorldPosition =
		worldPosition

	--------------------------------------------------
	-- 旋转
	--------------------------------------------------

	local sideRotation =
		CFrame.identity

	if currentSide == "Left" then

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

	local previewCFrame =
		CFrame.new(
			worldPosition
		)
		*
		plantCFrame.Rotation
		*
		sideRotation
		*
		horizontalRotation

	--------------------------------------------------
	-- BasePart
	--------------------------------------------------

	if preview:IsA("BasePart") then

		local originalSize =
			preview:GetAttribute(
				"OriginalSize"
			)

		if not originalSize then

			originalSize =
				preview.Size

			preview:SetAttribute(
				"OriginalSize",
				originalSize
			)
		end

		if originalSize.X > 0 then

			preview.Size =
				Vector3.new(
					currentLength,
					originalSize.Y,
					originalSize.Z
				)
		end

		preview.CFrame =
			previewCFrame

		--------------------------------------------------
		-- Model
		--------------------------------------------------

	elseif preview:IsA("Model") then

		local originalSizeX =
			preview:GetAttribute(
				"OriginalSizeX"
			)

		if originalSizeX
			and originalSizeX > 0 then

			local scale =
				currentLength
				/
				originalSizeX

			preview:ScaleTo(
				scale
			)
		end

		preview:PivotTo(
			previewCFrame
		)
	end
end

--------------------------------------------------
-- 开始放置 / 开始编辑
--------------------------------------------------

local function StartPlacement(
	itemId,
	gooseId,
	editData
)

	print(
		"[GoosePlacementClient] 点击鹅化物：",
		itemId,
		gooseId
	)

	--------------------------------------------------
	-- 如果已经在放置状态
	--------------------------------------------------

	if placing then

		print(
			"[GoosePlacementClient] 第二次点击，确认放置"
		)

		ConfirmPlacement()

		return
	end

	--------------------------------------------------
	-- 参数检查
	--------------------------------------------------

	if not itemId then

		warn(
			"[GoosePlacementClient] itemId 为空"
		)

		return
	end

	if not gooseId then

		warn(
			"[GoosePlacementClient] gooseId 为空"
		)

		return
	end

	--------------------------------------------------
	-- 编辑时不要要求植物已经成长
	--
	-- 只需要 PrimaryPart 准备好。
	--------------------------------------------------

	local plant =
		WaitForPlayerPlantReady(5)

	if not plant then

		warn(
			"[GoosePlacementClient] PlayerPlant 尚未准备完成，无法进入预览"
		)

		return
	end

	--------------------------------------------------
	-- 设置状态
	--------------------------------------------------

	currentItemId =
		itemId

	currentGooseId =
		gooseId

	editing =
		editData ~= nil

	editingItemId =
		editing and itemId or nil

	editPreviewInitialized =
		false

	--------------------------------------------------
	-- 编辑模式
	--------------------------------------------------

	if editData then

		currentSide =
			(
				editData.Side == "Left"
				and "Left"
				or "Right"
			)

		currentHeight =
			typeof(editData.Height) == "number"
			and editData.Height
			or 0

		currentLength =
			math.clamp(
				typeof(editData.Length) == "number"
				and editData.Length
				or GoosePlacementConfig.MinLength,

				GoosePlacementConfig.MinLength,

				GoosePlacementConfig.MaxLength
			)

		editInitialCFrame =
			editData.WorldCFrame

		--------------------------------------------------
		-- 如果服务器没有传 CFrame
		--------------------------------------------------

		if typeof(editInitialCFrame)
			~= "CFrame" then

			warn(
				"[GoosePlacementClient] 编辑数据没有有效 WorldCFrame"
			)

			editInitialCFrame =
				nil
		end

	else

		--------------------------------------------------
		-- 普通放置
		--------------------------------------------------

		currentSide =
			"Right"

		currentHeight =
			0

		currentLength =
			GoosePlacementConfig.MinLength

		editInitialCFrame =
			nil
	end

	placing =
		true

	--------------------------------------------------
	-- 创建预览
	--------------------------------------------------

	local success =
		CreatePreview()

	if not success then

		placing =
			false

		currentItemId =
			nil

		currentGooseId =
			nil

		editing =
			false

		editingItemId =
			nil

		editInitialCFrame =
			nil

		editPreviewInitialized =
			false

		return
	end

	--------------------------------------------------
	-- 第一次更新
	--------------------------------------------------

	UpdatePreview()

	print(
		"[GoosePlacementClient] 第一次点击完成，进入预览"
	)
end

--------------------------------------------------
-- 取消放置
--------------------------------------------------

local function CancelPlacement()

	print(
		"[GoosePlacementClient] 取消放置"
	)

	--------------------------------------------------
	-- 如果正在编辑
	--------------------------------------------------

	if editing
		and editingItemId then

		GooseInteraction:FireServer(
			"CancelEdit",
			editingItemId
		)
	end

	--------------------------------------------------
	-- 清理客户端状态
	--------------------------------------------------

	placing =
		false

	currentItemId =
		nil

	currentGooseId =
		nil

	editing =
		false

	editingItemId =
		nil

	editInitialCFrame =
		nil

	editReadyPending =
		nil

	editPreviewInitialized =
		false

	currentWorldPosition =
		nil

	currentSide =
		"Right"

	currentHeight =
		0

	currentLength =
		GoosePlacementConfig.MinLength

	RemovePreview()
end

--------------------------------------------------
-- 点击确定
--------------------------------------------------

ConfirmPlacement = function()

	if not placing then
		return
	end

	if not currentItemId then

		warn(
			"[GoosePlacementClient] 没有 ItemId"
		)

		return
	end

	if not currentGooseId then

		warn(
			"[GoosePlacementClient] 没有 GooseId"
		)

		return
	end

	--------------------------------------------------
	-- 确认前更新一次
	--------------------------------------------------

	--------------------------------------------------
	-- 编辑模式第一次确认时：
	-- 使用原始 CFrame。
	--
	-- 后续移动过鼠标后，
	-- UpdatePreview 会进入正常计算。
	--------------------------------------------------

	UpdatePreview()

	if not currentWorldPosition then

		warn(
			"[GoosePlacementClient] 没有有效的世界坐标"
		)

		return
	end

	--------------------------------------------------
	-- 发送服务器
	--------------------------------------------------

	PlaceGoose:FireServer(
		currentItemId,
		currentSide,
		currentHeight,
		currentLength,
		currentWorldPosition
	)

	print(
		"[GoosePlacementClient] 请求放置鹅化物：",
		currentItemId,
		currentGooseId,
		currentSide,
		currentHeight,
		currentLength
	)

	--------------------------------------------------
	-- 清理客户端状态
	--------------------------------------------------

	placing =
		false

	currentItemId =
		nil

	currentGooseId =
		nil

	editing =
		false

	editingItemId =
		nil

	editInitialCFrame =
		nil

	editReadyPending =
		nil

	editPreviewInitialized =
		false

	RemovePreview()
end

--------------------------------------------------
-- 判断鹅化物背包当前是否打开
--------------------------------------------------

local function IsGooseBackpackOpen()

	local playerGui =
		player:FindFirstChild("PlayerGui")

	if not playerGui then
		return false
	end

	local gui =
		playerGui:FindFirstChild(
			"GooseSlotGui"
		)

	if not gui then
		return false
	end

	if gui:IsA("ScreenGui")
		and gui.Enabled == false then

		return false
	end

	local backpack =
		gui:FindFirstChild(
			"beibao",
			true
		)

	if backpack
		and backpack:IsA("GuiObject") then

		return backpack.Visible
	end

	return true
end

--------------------------------------------------
-- 已放置鹅化物交互
--
-- 左键：编辑
-- 右键：回收
--------------------------------------------------

GooseInteraction.OnClientEvent:Connect(
	function(
		action,
		itemId,
		gooseId,
		side,
		height,
		length,
		worldCFrame
	)

		--------------------------------------------------
		-- 编辑请求
		--------------------------------------------------

		if action == "EditRequest" then

			if not IsGooseBackpackOpen() then
				return
			end

			if placing then
				return
			end

			--------------------------------------------------
			-- 保存服务器传来的编辑数据
			--------------------------------------------------

			editReadyPending = {

				ItemId =
					itemId,

				GooseId =
					gooseId,

				Side =
					side,

				Height =
					height,

				Length =
					length,

				WorldCFrame =
					worldCFrame
			}

			--------------------------------------------------
			-- 通知服务器开始编辑
			--------------------------------------------------

			GooseInteraction:FireServer(
				"BeginEdit",
				itemId
			)

			return
		end

		--------------------------------------------------
		-- 服务器允许编辑
		--------------------------------------------------

		if action == "EditReady" then

			if not editReadyPending then
				return
			end

			if editReadyPending.ItemId
				~= itemId then

				return
			end

			--------------------------------------------------
			-- 如果玩家在服务器回应之前关闭了背包
			--------------------------------------------------

			if not IsGooseBackpackOpen() then

				GooseInteraction:FireServer(
					"CancelEdit",
					itemId
				)

				editReadyPending =
					nil

				return
			end

			--------------------------------------------------
			-- 取出编辑数据
			--------------------------------------------------

			local editData =
				editReadyPending

			editReadyPending =
				nil

			--------------------------------------------------
			-- 开始编辑
			--------------------------------------------------

			StartPlacement(
				editData.ItemId,
				editData.GooseId,
				editData
			)

			return
		end

		--------------------------------------------------
		-- 回收请求
		--------------------------------------------------

		if action == "RecycleRequest" then

			if not IsGooseBackpackOpen() then
				return
			end

			if placing then
				return
			end

			GooseInteraction:FireServer(
				"Recycle",
				itemId
			)

		end
	end)

--------------------------------------------------
-- 背包点击开始放置
--------------------------------------------------

StartGoosePlacementEvent.Event:Connect(
	function(
		itemId,
		gooseId
	)

		print(
			"[GoosePlacementClient] 收到开始放置事件"
		)

		StartPlacement(
			itemId,
			gooseId
		)

	end
)

--------------------------------------------------
-- 鼠标移动
--------------------------------------------------

RunService.RenderStepped:Connect(
	function()

		if not placing then
			return
		end

		if not preview then
			return
		end

		UpdatePreview()

	end
)

--------------------------------------------------
-- 键盘操作
--------------------------------------------------

UserInputService.InputBegan:Connect(
	function(
		input,
		gameProcessed
	)

		--------------------------------------------------
		-- 编辑 GUI 输入时忽略
		--------------------------------------------------

		if gameProcessed then
			return
		end

		if not placing then
			return
		end

		--------------------------------------------------
		-- 左键确认
		--------------------------------------------------

		if input.UserInputType
			== Enum.UserInputType.MouseButton1 then

			ConfirmPlacement()

			--------------------------------------------------
			-- 右键取消
			--------------------------------------------------

		elseif input.UserInputType
			== Enum.UserInputType.MouseButton2 then

			CancelPlacement()

			--------------------------------------------------
			-- ESC取消
			--------------------------------------------------

		elseif input.KeyCode
			== Enum.KeyCode.Escape then

			CancelPlacement()

			--------------------------------------------------
			-- Q缩短
			--------------------------------------------------

		elseif input.KeyCode
			== Enum.KeyCode.Q then

			currentLength =
				math.max(
					GoosePlacementConfig.MinLength,
					currentLength - 1
				)

			UpdatePreview()

			--------------------------------------------------
			-- E增长
			--------------------------------------------------

		elseif input.KeyCode
			== Enum.KeyCode.E then

			currentLength =
				math.min(
					GoosePlacementConfig.MaxLength,
					currentLength + 1
				)

			UpdatePreview()

		end

	end)

--------------------------------------------------
-- 玩家角色重新生成
--------------------------------------------------

player.CharacterAdded:Connect(
	function()

		if not placing then
			return
		end

		task.wait(0.5)

		local plant =
			WaitForPlayerPlantReady(5)

		if not plant then

			CancelPlacement()

			return
		end

		CreatePreview()

		UpdatePreview()

	end
)

--------------------------------------------------
-- 客户端加载完成
--------------------------------------------------

print(
	"[GoosePlacementClient] 客户端加载完成"
)