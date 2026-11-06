local Players = game:GetService("Players")

local PlantService = require(
	game.ServerScriptService.Services.PlantService
)


--------------------------------------------------
-- 植物成长速度
--------------------------------------------------

local GROW_INTERVAL = 1


--------------------------------------------------
-- 玩家成长循环
--------------------------------------------------

local function StartGrowth(player)

	task.spawn(function()

		while player.Parent do

			--------------------------------------------------
			-- 每 5 秒成长一次
			--------------------------------------------------

			task.wait(GROW_INTERVAL)


			--------------------------------------------------
			-- 玩家已经离开
			--------------------------------------------------

			if not player.Parent then
				break
			end


			--------------------------------------------------
			-- 让植物成长
			--------------------------------------------------
			
			PlantService:GrowPlant(
				player
			)

		end

	end)

end


--------------------------------------------------
-- 玩家加入
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)

	StartGrowth(player)

end)


--------------------------------------------------
-- 防止脚本启动时玩家已经存在
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
	) do

	StartGrowth(player)

end
