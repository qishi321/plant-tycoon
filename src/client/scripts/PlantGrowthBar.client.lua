local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MAX_DISTANCE = 80

local bars = {}   -- plant -> { Gui, Fill, Label, Attachment }


--------------------------------------------------
-- 更新进度
--------------------------------------------------

local function UpdateBar(plant)

	local bar = bars[plant]

	if not bar then
		return
	end

	local growth =
		tonumber(plant:GetAttribute("Growth")) or 0

	local required =
		tonumber(plant:GetAttribute("GrowthRequired")) or 100

	local ratio = 0

	if required > 0 then
		ratio = math.clamp(growth / required, 0, 1)
	end

	bar.Label.Text =
		string.format("%d / %d", math.floor(growth), math.floor(required))

	TweenService:Create(
		bar.Fill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{ Size = UDim2.fromScale(ratio, 1) }
	):Play()
end


--------------------------------------------------
-- 创建进度条
--------------------------------------------------

local function CreateBar(plant)

	if bars[plant] then
		return
	end

	local primary = plant.Part.pivot

	if not primary then
		return
	end

	--------------------------------------------------
	-- 顶部锚点（相对坐标，自动跟随缩放）
	--------------------------------------------------

	local attachment = Instance.new("Attachment")
	attachment.Name = "GrowthBarAnchor"
	attachment.Position = Vector3.new(0, -0.5, 0)
	attachment.Parent = primary

	--------------------------------------------------
	-- 容器
	--------------------------------------------------

	local gui = Instance.new("BillboardGui")
	gui.Name = "PlantGrowthBar"
	gui.Adornee = attachment
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(160, 40)
	gui.Parent = playerGui

	--------------------------------------------------
	-- 文字
	--------------------------------------------------

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.Parent = gui

	--------------------------------------------------
	-- 底槽
	--------------------------------------------------

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 24)
	back.Size = UDim2.new(1, 0, 0, 12)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = gui

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = back

	--------------------------------------------------
	-- 填充条
	--------------------------------------------------

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 200, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = back

	bars[plant] = {
		Gui = gui,
		Fill = fill,
		Label = label,
		Attachment = attachment,
	}

	--------------------------------------------------
	-- 数据变化时刷新（不要用 RenderStepped 轮询）
	--------------------------------------------------

	plant:GetAttributeChangedSignal("Growth"):Connect(function()
		UpdateBar(plant)
	end)

	plant:GetAttributeChangedSignal("GrowthRequired"):Connect(function()
		UpdateBar(plant)
	end)

	--------------------------------------------------
	-- 植物被销毁时清理
	--------------------------------------------------

	plant.AncestryChanged:Connect(function()

		if plant:IsDescendantOf(workspace) then
			return
		end

		local bar = bars[plant]

		if bar then
			bar.Gui:Destroy()
			bars[plant] = nil
		end

	end)

	UpdateBar(plant)
end


--------------------------------------------------
-- 发现植物
--------------------------------------------------

local function Watch(instance)

	if instance.Name ~= "PlayerPlant" then
		return
	end

	if not instance:IsA("Model") then
		return
	end

	-- PrimaryPart 可能晚一帧才准备好
	task.defer(function()

		local primary =
			instance.PrimaryPart
			or instance:WaitForChild("PrimaryPart", 3)

		if primary then
			CreateBar(instance)
		end

	end)

end

workspace.DescendantAdded:Connect(Watch)

for _, instance in ipairs(workspace:GetDescendants()) do
	Watch(instance)
end
