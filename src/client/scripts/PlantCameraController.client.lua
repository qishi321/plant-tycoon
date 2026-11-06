local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------
-- 配置
--------------------------------------------------

local MAP_NAME = "Grow A Garden map"
local PLANT_NAME = "PlayerPlant"

--------------------------------------------------
-- 镜头距离
--------------------------------------------------

local cameraDistance = 35

-- 最近距离
local MIN_CAMERA_DISTANCE = 8

-- 最远距离
local MAX_CAMERA_DISTANCE = 100

-- 滚轮每格移动多少
local CAMERA_ZOOM_SPEED = 4

--------------------------------------------------
-- 镜头位置
--------------------------------------------------

-- 左右最大移动范围
local MAX_HORIZONTAL_OFFSET = 50

-- 上下不设置最大限制
local MAX_VERTICAL_OFFSET = nil

-- 鼠标拖动速度
local MOVE_SPEED = 0.05

--------------------------------------------------
-- 状态
--------------------------------------------------

local cameraLocked = false

local plant = nil
local primaryPart = nil

local horizontalOffset = 0
local verticalOffset = 0

local dragging = false
local lastMousePosition = nil

local oldCameraType = nil
local oldCameraSubject = nil

--------------------------------------------------
-- 获取玩家植物
--------------------------------------------------

local function GetPlayerPlant()

	local plotName =
		player:GetAttribute("PlotName")

	if not plotName then
		return nil
	end

	local map =
		workspace:FindFirstChild(MAP_NAME)

	if not map then
		return nil
	end

	local plot =
		map:FindFirstChild(plotName)

	if not plot then
		return nil
	end

	local playerPlant =
		plot:FindFirstChild(PLANT_NAME)

	if not playerPlant then
		return nil
	end

	if not playerPlant:IsA("Model") then
		return nil
	end

	if not playerPlant.PrimaryPart then
		return nil
	end

	return playerPlant

end

--------------------------------------------------
-- 打开植物视角
--------------------------------------------------

local function OpenPlantCamera()

	plant = GetPlayerPlant()

	if not plant then

		warn(
			"[PlantCamera] 找不到玩家植物"
		)

		return

	end

	primaryPart =
		plant.PrimaryPart

	--------------------------------------------------
	-- 保存原本 Camera
	--------------------------------------------------

	oldCameraType =
		camera.CameraType

	oldCameraSubject =
		camera.CameraSubject

	--------------------------------------------------
	-- 重置偏移
	--------------------------------------------------

	horizontalOffset = 0
	verticalOffset = 0

	cameraDistance = 35

	--------------------------------------------------
	-- 锁定 Camera
	--------------------------------------------------

	camera.CameraType =
		Enum.CameraType.Scriptable

	cameraLocked = true

	print(
		"[PlantCamera] 已打开植物视角"
	)

end

--------------------------------------------------
-- 关闭植物视角
--------------------------------------------------

local function ClosePlantCamera()

	cameraLocked = false

	plant = nil
	primaryPart = nil

	dragging = false
	lastMousePosition = nil

	--------------------------------------------------
	-- 恢复 Camera
	--------------------------------------------------

	camera.CameraType =
		oldCameraType
		or Enum.CameraType.Custom

	camera.CameraSubject =
		oldCameraSubject

	print(
		"[PlantCamera] 已恢复玩家视角"
	)

end

--------------------------------------------------
-- 更新 Camera
--------------------------------------------------

local function UpdateCamera()

	if not cameraLocked then
		return
	end

	if not plant then
		return
	end

	if not plant.Parent then
		return
	end

	primaryPart =
		plant.PrimaryPart

	if not primaryPart then
		return
	end

	local plantCFrame =
		primaryPart.CFrame

	local plantPosition =
		plantCFrame.Position

	--------------------------------------------------
	-- 植物方向
	--------------------------------------------------

	local rightVector =
		plantCFrame.RightVector

	local upVector =
		plantCFrame.UpVector

	local lookVector =
		plantCFrame.LookVector

	--------------------------------------------------
	-- Camera 位置
	--------------------------------------------------

	local cameraPosition =
		plantPosition

	- lookVector * cameraDistance

		+ upVector *
		verticalOffset

		+ rightVector *
		horizontalOffset

	--------------------------------------------------
	-- Camera 看向的位置
	--------------------------------------------------

	local lookAtPosition =
		plantPosition

		+ upVector *
		verticalOffset

		+ rightVector *
		horizontalOffset

	--------------------------------------------------
	-- 设置 Camera
	--------------------------------------------------

	camera.CFrame =
		CFrame.lookAt(
			cameraPosition,
			lookAtPosition,
			upVector
		)

end

--------------------------------------------------
-- 每帧更新
--------------------------------------------------

RunService.RenderStepped:Connect(function()

	if cameraLocked then

		UpdateCamera()

	end

end)

--------------------------------------------------
-- 开始右键拖动
--------------------------------------------------

UserInputService.InputBegan:Connect(function(
	input,
	gameProcessed
)

	if not cameraLocked then
		return
	end

	if gameProcessed then
		return
	end

	if input.UserInputType ==
		Enum.UserInputType.MouseButton2 then

		dragging = true

		lastMousePosition =
			UserInputService:GetMouseLocation()

	end

end)

--------------------------------------------------
-- 结束右键拖动
--------------------------------------------------

UserInputService.InputEnded:Connect(function(input)

	if input.UserInputType ==
		Enum.UserInputType.MouseButton2 then

		dragging = false

		lastMousePosition = nil

	end

end)

--------------------------------------------------
-- 鼠标移动
--------------------------------------------------

UserInputService.InputChanged:Connect(function(input)

	if not cameraLocked then
		return
	end

	--------------------------------------------------
	-- 右键拖动调整位置
	--------------------------------------------------

	if input.UserInputType ==
		Enum.UserInputType.MouseMovement then

		if not dragging then
			return
		end

		local currentMousePosition =
			UserInputService:GetMouseLocation()

		if not lastMousePosition then

			lastMousePosition =
				currentMousePosition

			return

		end

		local delta =
			currentMousePosition
		- lastMousePosition

		lastMousePosition =
			currentMousePosition

		--------------------------------------------------
		-- 左右移动
		--------------------------------------------------

		horizontalOffset -=
			delta.X * MOVE_SPEED

		horizontalOffset =
			math.clamp(
				horizontalOffset,
				-MAX_HORIZONTAL_OFFSET,
				MAX_HORIZONTAL_OFFSET
			)

		--------------------------------------------------
		-- 上下移动
		--------------------------------------------------

		verticalOffset +=
			delta.Y * MOVE_SPEED

		--------------------------------------------------
		-- 不限制上下高度
		--------------------------------------------------

	end

	--------------------------------------------------
	-- 滚轮调整距离
	--------------------------------------------------

	if input.UserInputType ==
		Enum.UserInputType.MouseWheel then

		cameraDistance -=
			input.Position.Z
			* CAMERA_ZOOM_SPEED

		cameraDistance =
			math.clamp(
				cameraDistance,
				MIN_CAMERA_DISTANCE,
				MAX_CAMERA_DISTANCE
			)

		print(
			"[PlantCamera] Camera距离：",
			cameraDistance
		)

	end

end)

--------------------------------------------------
-- 提供给其他 LocalScript
--------------------------------------------------

_G.OpenPlantCamera =
	OpenPlantCamera

_G.ClosePlantCamera =
 	ClosePlantCamera
