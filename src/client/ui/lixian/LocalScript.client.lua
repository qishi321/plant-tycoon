local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local TweenService =
	game:GetService("TweenService")

local player =
	game.Players.LocalPlayer

local gui =
	script.Parent

local frame =
	gui:WaitForChild("Frame")

local textLabel =
	frame:WaitForChild("TextLabel")

local OfflineIncomeEvent =
	ReplicatedStorage:WaitForChild(
		"OfflineIncomeEvent"
	)

--------------------------------------------------
-- 初始隐藏
--------------------------------------------------

frame.Visible = false

--------------------------------------------------
-- 显示离线收益
--------------------------------------------------

OfflineIncomeEvent.OnClientEvent:Connect(
	function(income)

		if typeof(income) ~= "number" then
			return
		end

		if income <= 0 then
			return
		end

		--------------------------------------------------
		-- 设置文字
		--------------------------------------------------

		textLabel.Text =
			"离线收益 +" .. tostring(income) .. " 金币"

		--------------------------------------------------
		-- 显示
		--------------------------------------------------

		frame.Visible = true

		--------------------------------------------------
		-- 防止之前的透明度影响
		--------------------------------------------------

		frame.BackgroundTransparency = 1

		textLabel.TextTransparency = 0

		--------------------------------------------------
		-- 显示3秒
		--------------------------------------------------

		task.wait(3)

		--------------------------------------------------
		-- 淡出
		--------------------------------------------------

		local frameTween =
			TweenService:Create(
				frame,
				TweenInfo.new(0.5),
				{
					BackgroundTransparency = 1
				}
			)

		local textTween =
			TweenService:Create(
				textLabel,
				TweenInfo.new(0.5),
				{
					TextTransparency = 1
				}
			)

		frameTween:Play()
		textTween:Play()

		frameTween.Completed:Wait()

		frame.Visible = false

	end
)
