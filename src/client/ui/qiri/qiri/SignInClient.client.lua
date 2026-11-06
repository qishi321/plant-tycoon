local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local RemoteEvent =
	ReplicatedStorage:WaitForChild("RemoteEvent")

local RemoteFunction =
	ReplicatedStorage:WaitForChild("RemoteFunction")

local ClaimSignIn =
	RemoteEvent:WaitForChild("ClaimSignIn")

local GetSignInData =
	RemoteFunction:WaitForChild("GetSignInData")

local Config =
	require(
		ReplicatedStorage.Config:WaitForChild("SignInConfig")
	)

--------------------------------------------------
-- UI
--------------------------------------------------

local gui = script.Parent

local sixDay = gui:WaitForChild("6day")
local sevenDay = gui:WaitForChild("7day")

local guanbi = gui.guanbi

--------------------------------------------------
-- 状态
--------------------------------------------------

local signInData = nil

--------------------------------------------------
-- 获取按钮
--------------------------------------------------

local function GetButton(day)

	if day <= 6 then

		local item = sixDay:FindFirstChild(tostring(day))

		if not item then
			return nil
		end

		if item:IsA("GuiButton") then
			return item
		end

		local button = item:FindFirstChild("ClaimButton")

		if button and button:IsA("GuiButton") then
			return button
		end

	else

		local item = sevenDay:FindFirstChild("7")

		if not item then
			return nil
		end

		if item:IsA("GuiButton") then
			return item
		end

		local button = item:FindFirstChild("ClaimButton")

		if button and button:IsA("GuiButton") then
			return button
		end

	end

	return nil
end

--------------------------------------------------
-- 更新奖励文字
--------------------------------------------------

local function UpdateRewardText()

	for day = 1, 7 do

		local reward = Config.Rewards[day]

		if not reward then
			continue
		end

		local item

		if day <= 6 then
			item = sixDay:FindFirstChild(tostring(day))
		else
			item = sevenDay:FindFirstChild("7")
		end

		if not item then
			continue
		end

		--------------------------------------------------
		-- name
		--------------------------------------------------

		local nameLabel =
			item:FindFirstChild("name")

		if nameLabel and nameLabel:IsA("TextLabel") then

			nameLabel.Text =
				reward.Name

		end

		--------------------------------------------------
		-- day
		--------------------------------------------------

		local dayLabel =
			item:FindFirstChild("day")

		if dayLabel and dayLabel:IsA("TextLabel") then

			dayLabel.Text =
				"第 " .. day .. " 天"

		end

		--------------------------------------------------
		-- 第七天 TextLabel
		--------------------------------------------------

		if day == 7 then

			local textLabel =
				item:FindFirstChild("TextLabel")

			if textLabel and textLabel:IsA("TextLabel") then

				textLabel.Text =
					reward.Name

			end

		end

	end

end

--------------------------------------------------
-- 更新签到状态
--------------------------------------------------

local function UpdateSignInUI()

	if not signInData then
		return
	end

	local currentDay =
		signInData.CurrentDay

	for day = 1, 7 do

		local item

		if day <= 6 then
			item = sixDay:FindFirstChild(tostring(day))
		else
			item = sevenDay:FindFirstChild("7")
		end

		if not item then
			continue
		end

		local dayLabel =
			item:FindFirstChild("day")

		if dayLabel and dayLabel:IsA("TextLabel") then

			if day < currentDay then

				dayLabel.Text = "已领取"

			elseif day == currentDay and signInData.CanClaim then

				dayLabel.Text = "点击领取"

			elseif day == currentDay then

				dayLabel.Text = "明日可领取"

			else

				dayLabel.Text =
					"第 " .. day .. " 天"

			end

		end

	end

end

--------------------------------------------------
-- 连接按钮
--------------------------------------------------

local function ConnectButtons()

	for day = 1, 7 do

		local button = GetButton(day)

		if button then

			button.Activated:Connect(function()

				if not signInData then
					return
				end

				-- 只能领取当前天
				if day ~= signInData.CurrentDay then
					return
				end

				-- 今天已经领取
				if not signInData.CanClaim then
					return
				end

				ClaimSignIn:FireServer()

			end)

		end

	end

end

--------------------------------------------------
-- 领取成功
--------------------------------------------------

ClaimSignIn.OnClientEvent:Connect(
	function(result, day, rewardName)

		if result ~= "Success" then
			return
		end

		print(
			"[签到] 领取成功：",
			"Day " .. day,
			rewardName
		)

		-- 重新从服务器获取状态
		local newData =
			GetSignInData:InvokeServer()

		if newData then

			signInData = newData

			UpdateSignInUI()

		end

	end
)

guanbi.Activated:Connect(function()

	gui.Visible = false

end)

--------------------------------------------------
-- 初始化
--------------------------------------------------

UpdateRewardText()

local data =
	GetSignInData:InvokeServer()

if data then

	signInData = data

	UpdateSignInUI()

end

ConnectButtons()
