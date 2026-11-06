-- 【客户端】StarterGui.shuju.LocalScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvent")
local UpdateGold = RemoteEvent:WaitForChild("UpdateGold")

local propertiesFrame = script.Parent:WaitForChild("Frame")

-- 千分位格式化（可选）
local function FormatGold(gold)
	gold = math.floor(tonumber(gold) or 0)
	local str = tostring(gold)
	local k
	while true do
		str, k = string.gsub(str, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return str
end

UpdateGold.OnClientEvent:Connect(function(Gold)
	print("[客户端] 收到金币更新事件，数值：", Gold)  -- 👈 加这一行

	propertiesFrame.GoldPanel.GoldAmount.Text = "$" .. tostring(Gold)
end)

