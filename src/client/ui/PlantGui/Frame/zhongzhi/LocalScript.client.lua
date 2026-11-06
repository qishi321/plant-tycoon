local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")

local ShowPlantButton =
	RemoteEvent:WaitForChild("ShowPlantButton")

local PlantRemote =
	RemoteEvent:WaitForChild("Plant")

local button = script.Parent

--------------------------------------------------
-- 默认隐藏
--------------------------------------------------

button.Visible = false

--------------------------------------------------
-- 控制按钮显示 / 隐藏
--------------------------------------------------

ShowPlantButton.OnClientEvent:Connect(function(show)

	button.Visible = show

end)

--------------------------------------------------
-- 点击种植
--------------------------------------------------

button.Activated:Connect(function()

	--------------------------------------------------
	-- 防止重复点击
	--------------------------------------------------

	if not button.Visible then
		return
	end

	--------------------------------------------------
	-- 点击后立即隐藏
	--------------------------------------------------

	button.Visible = false

	--------------------------------------------------
	-- 请求服务器种植
	--------------------------------------------------

	PlantRemote:FireServer()

end)