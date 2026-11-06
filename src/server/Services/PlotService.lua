local Players = game:GetService("Players") 

local PlotService = {} 

local Map = workspace:WaitForChild("Grow A Garden map") 

-- 当前玩家占用的土地 
local PlayerPlots = {} 

-- 当前土地的主人 
local PlotOwners = {} 


-------------------------------------------------- 
-- 创建土地指引光带 
-------------------------------------------------- 

local function CreatePlotGuide(player, plot) 

	local character = player.Character 

	if not character then 
		character = player.CharacterAdded:Wait() 
	end 

	local hrp = character:WaitForChild("HumanoidRootPart") 

	-------------------------------------------------- 
	-- 删除旧光带 
	-------------------------------------------------- 

	local oldBeam = hrp:FindFirstChild("PlotGuideBeam") 

	if oldBeam then 
		oldBeam:Destroy() 
	end 

	local oldAttachment = hrp:FindFirstChild("PlotGuideAttachment") 

	if oldAttachment then 
		oldAttachment:Destroy() 
	end 

	-------------------------------------------------- 
	-- 玩家身上的 Attachment 
	-------------------------------------------------- 

	local attachTop = Instance.new("Attachment") 
	attachTop.Name = "PlotGuideAttachment" 
	attachTop.Position = Vector3.new(0, 1, 0) 
	attachTop.Parent = hrp 

	-------------------------------------------------- 
	-- 找到土地目标位置 
	-------------------------------------------------- 

	local targetPart 

	if plot:IsA("BasePart") then 

		targetPart = plot 

	else 

		-- 优先寻找 Spawn 
		targetPart = plot:FindFirstChild("Spawn") 

		-- 如果没有 Spawn，就使用 PrimaryPart 
		if not targetPart and plot.PrimaryPart then 
			targetPart = plot.PrimaryPart 
		end 

		-- 最后寻找土地中的 BasePart 
		if not targetPart then 

			targetPart = plot:FindFirstChildWhichIsA( 
				"BasePart", 
				true 
			) 

		end 
	end 

	-------------------------------------------------- 
	-- 找不到目标 
	-------------------------------------------------- 

	if not targetPart then 

		warn( 
			"土地 " .. 
				plot.Name .. 
				" 找不到可以连接光带的 BasePart" 
		) 

		attachTop:Destroy() 

		return 
	end 

	-------------------------------------------------- 
	-- 土地上的 Attachment 
	-------------------------------------------------- 

	local attachBottom = targetPart:FindFirstChild( 
		"PlotGuideTarget" 
	) 

	if not attachBottom then 

		attachBottom = Instance.new("Attachment") 

		attachBottom.Name = "PlotGuideTarget" 

		attachBottom.Position = Vector3.new( 
			0, 
			targetPart.Size.Y / 2 + 3, 
			0 
		) 

		attachBottom.Parent = targetPart 

	end 

	-------------------------------------------------- 
	-- 创建 Beam 
	-------------------------------------------------- 

	local beam = Instance.new("Beam") 

	beam.Name = "PlotGuideBeam" 

	beam.Attachment0 = attachTop 
	beam.Attachment1 = attachBottom 

	-- 光带宽度 
	beam.Width0 = 1 
	beam.Width1 = 1 

	-- 光带弯曲 
	beam.CurveSize0 = 0 
	beam.CurveSize1 = 0 

	-- 透明度 
	beam.Transparency = NumberSequence.new(0) 

	-- 面向摄像机 
	beam.FaceCamera = true 

	-- 光带显示在角色前面 
	beam.ZOffset = 1 

	beam.Parent = hrp 

	-------------------------------------------------- 
	-- 玩家到达土地后删除光带 
	-------------------------------------------------- 

	task.spawn(function() 

		while player.Parent and beam.Parent do 

			task.wait(0.2) 

			-- 角色已经不存在 
			if not character.Parent then 
				break 
			end 

			-- 土地已经不是这个玩家的 
			if PlotOwners[plot] ~= player then 
				break 
			end 

			local distance = ( 
				hrp.Position - targetPart.Position 
			).Magnitude 

			-------------------------------------------------- 
			-- 到达土地 
			-------------------------------------------------- 

			if distance <= 8 then 

				beam:Destroy() 

				if attachTop then 
					attachTop:Destroy() 
				end 

				print( 
					player.Name .. 
						" 已到达土地 " .. 
						plot.Name 
				) 

				break 
			end 
		end 

	end) 
end 


-------------------------------------------------- 
-- 删除玩家身上的土地光带 
-------------------------------------------------- 

local function RemovePlotGuide(player) 

	local character = player.Character 

	if not character then 
		return 
	end 

	local hrp = character:FindFirstChild( 
		"HumanoidRootPart" 
	) 

	if not hrp then 
		return 
	end 

	local beam = hrp:FindFirstChild( 
		"PlotGuideBeam" 
	) 

	if beam then 
		beam:Destroy() 
	end 

	local attachment = hrp:FindFirstChild( 
		"PlotGuideAttachment" 
	) 

	if attachment then 
		attachment:Destroy() 
	end 
end 


-------------------------------------------------- 
-- 获取所有土地 
-------------------------------------------------- 

local function GetPlots() 

	local plots = {} 

	for i = 1, 6 do 

		local plot = Map:FindFirstChild( 
			tostring(i) 
		) 

		if plot then 

			table.insert( 
				plots, 
				plot 
			) 

		else 

			warn( 
				"找不到土地：" .. i 
			) 

		end 
	end 

	return plots 
end 


-------------------------------------------------- 
-- 分配土地 
-------------------------------------------------- 

function PlotService:AssignPlot(player) 

	-- 防止重复分配 
	if PlayerPlots[player] then 

		return PlayerPlots[player] 

	end 

	local plots = GetPlots() 

	for _, plot in ipairs(plots) do 

		-------------------------------------------------- 
		-- 这块土地没人 
		-------------------------------------------------- 

		if not PlotOwners[plot] then 

			PlotOwners[plot] = player 
			PlayerPlots[player] = plot 

			-------------------------------------------------- 
			-- 设置土地主人 
			-------------------------------------------------- 

			plot:SetAttribute( 
				"OwnerUserId", 
				player.UserId 
			) 

			plot:SetAttribute( 
				"OwnerName", 
				player.Name 
			) 

			-------------------------------------------------- 
			-- 创建玩家土地指引光带 
			-------------------------------------------------- 

			task.spawn(function() 

				CreatePlotGuide( 
					player, 
					plot 
				) 

			end) 

			print( 
				"[PlotService] " .. 
					player.Name .. 
					" 获得土地 " .. 
					plot.Name 
			) 

			return plot 
		end 
	end 

	-------------------------------------------------- 
	-- 没有空地 
	-------------------------------------------------- 

	warn( 
		"没有空闲土地给玩家：" .. 
			player.Name 
	) 

	return nil 
end 


-------------------------------------------------- 
-- 释放土地 
-------------------------------------------------- 

function PlotService:ReleasePlot(player) 

	local plot = PlayerPlots[player] 

	if not plot then 
		return 
	end 

	-------------------------------------------------- 
	-- 删除玩家身上的光带 
	-------------------------------------------------- 

	RemovePlotGuide(player) 

	-------------------------------------------------- 
	-- 释放土地 
	-------------------------------------------------- 

	PlotOwners[plot] = nil 
	PlayerPlots[player] = nil 

	-------------------------------------------------- 
	-- 清除土地主人 
	-------------------------------------------------- 

	plot:SetAttribute( 
		"OwnerUserId", 
		nil 
	) 

	plot:SetAttribute( 
		"OwnerName", 
		nil 
	) 

	print( 
		"[PlotService] " .. 
			player.Name .. 
			" 释放土地 " .. 
			plot.Name 
	) 
end 


-------------------------------------------------- 
-- 获取玩家土地 
-------------------------------------------------- 

function PlotService:GetPlayerPlot(player) 

	return PlayerPlots[player] 

end 


-------------------------------------------------- 
-- 获取土地主人 
-------------------------------------------------- 

function PlotService:GetPlotOwner(plot) 

	return PlotOwners[plot] 

end 

function PlotService:IsPlayerPlot(player, plot) 
	if not player or not plot then 
		return false 
	end 

	return PlayerPlots[player] == plot 
end 

function PlotService:CanPlayerUsePlot(player, plot)
	if not player or not plot then
		return false
	end

	return PlotOwners[plot] == player
end

return PlotService