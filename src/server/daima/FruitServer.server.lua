local Players = game:GetService("Players")

local ServerScriptService = game:GetService("ServerScriptService")

local PlotService = require(
	ServerScriptService.Services.PlotService
)

local FruitService = require(
	ServerScriptService.Services.FruitService
)

--------------------------------------------------
-- 配置
--------------------------------------------------

local FRUIT_INTERVAL = 5 -- 每 5 秒生成一个果实

--------------------------------------------------
-- 开始生产果实
--------------------------------------------------

local function StartFruitProduction(player)

	task.spawn(function()

		while player.Parent do

			task.wait(FRUIT_INTERVAL)

			if not player.Parent then
				break
			end

			--------------------------------------------------
			-- 获取玩家土地
			--------------------------------------------------

			local plot = PlotService:GetPlayerPlot(player)

			if not plot then
				continue
			end

			--------------------------------------------------
			-- 获取玩家植物
			--------------------------------------------------

			local plant = plot:FindFirstChild("PlayerPlant")

			if not plant then
				-- 玩家还没有植物
				continue
			end

			--------------------------------------------------
			-- 生成果实
			--------------------------------------------------

			FruitService:SpawnFruit(
				player,
				plant
			)

		end

	end)

end

--------------------------------------------------
-- 玩家进入
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)

	StartFruitProduction(player)

end)
