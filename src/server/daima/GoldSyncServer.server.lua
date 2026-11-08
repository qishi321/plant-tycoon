-- 【服务器脚本】ServerScriptService/GoldSyncServer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--DataService 的实际路径
local DataService = require(game.ServerScriptService.Data:WaitForChild("DataService"))

-- 获取/创建 RemoteEvent
local RemoteEvent = ReplicatedStorage:FindFirstChild("RemoteEvent")
if not RemoteEvent then
	RemoteEvent = Instance.new("RemoteEvent")
	RemoteEvent.Name = "RemoteEvent"
	RemoteEvent.Parent = ReplicatedStorage
end

local UpdateGold = RemoteEvent:FindFirstChild("UpdateGold")
if not UpdateGold then
	UpdateGold = Instance.new("RemoteEvent")
	UpdateGold.Name = "UpdateGold"
	UpdateGold.Parent = RemoteEvent
end

--------------------------------------------------
-- 记录每个玩家上一次推送过的金币值，避免重复发
--------------------------------------------------
local lastPushedGold = {}

--------------------------------------------------
-- 向客户端推送金币
--------------------------------------------------
local function PushGoldToClient(player, gold)
	if not player or not player.Parent then
		return
	end

	-- 记录这次的值
	lastPushedGold[player] = gold

	-- RemoteEvent 推送
	UpdateGold:FireClient(player, gold)

	-- 顺便写 Attribute 作为双保险（客户端可选监听）
	player:SetAttribute("Money", gold)
end

--------------------------------------------------
-- 定时循环检查金币变化
--------------------------------------------------
local CHECK_INTERVAL = 0.25 -- 每 0.25 秒检查一次，可以按需调整

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			-- 等玩家数据加载完成
			if player:GetAttribute("DataLoaded") == true then

				local data = DataService:GetData(player)

				if data and type(data.Money) == "number" then

					local currentGold = data.Money

					-- 和上次推送的值对比，只有变化才推送
					if lastPushedGold[player] ~= currentGold then
						PushGoldToClient(player, currentGold)
					end

				end
			end
		end
	end
end)

--------------------------------------------------
-- 玩家离开时清空记录，防止内存泄漏
--------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	lastPushedGold[player] = nil
end)