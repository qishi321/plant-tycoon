local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--------------------------------------------------
-- Remote / Bindable
--------------------------------------------------

local StartGoosePlacementEvent =
	ReplicatedStorage.BindableEvent:WaitForChild("StartGoosePlacement")

local GetGooseInventory =
	ReplicatedStorage.RemoteFunction:WaitForChild("GetGooseInventory")

--------------------------------------------------
-- 玩家
--------------------------------------------------

local player = Players.LocalPlayer
local playerui = script.Parent.Parent

local mainUI = script.Parent

local RemoteEvent =
	ReplicatedStorage:WaitForChild(
		"RemoteEvent"
	)

local SetSelectedFruit =
	RemoteEvent:WaitForChild("SetSelectedFruit")



--------------------------------------------------
-- GooseSlotGui
--------------------------------------------------

local GooseSlotGui =
	playerui:WaitForChild("GooseSlotGui")

local openshop =
	mainUI.lan:WaitForChild("shop")

local openbeibao =
	mainUI.lan:WaitForChild("beibao")

local openguoshi =
	mainUI.lan:WaitForChild("guoshi")

--------------------------------------------------
-- 鹅化物 UI
--------------------------------------------------

local beibaoui =
	GooseSlotGui:WaitForChild("beibao")

local shopui =
	GooseSlotGui:WaitForChild("shop")

--------------------------------------------------
-- 果实 UI
--------------------------------------------------

local guoshui =
	GooseSlotGui:WaitForChild("guoshi")

--------------------------------------------------
-- UI 平滑出现动画
--------------------------------------------------

local currentOpenUI = nil
local originalPositions = {}

local function ShowUIWithTween(targetUI)
	-- 如果当前界面已经打开，只刷新内容，不重复播放动画
	if currentOpenUI == targetUI and targetUI.Visible then
		return
	end

	-- 隐藏其他界面
	for _, ui in ipairs({beibaoui, shopui, guoshui}) do
		if ui ~= targetUI then
			ui.Visible = false
		end
	end

	currentOpenUI = targetUI

	-- 保存界面原始位置
	if not originalPositions[targetUI] then
		originalPositions[targetUI] = targetUI.Position
	end

	local originalPosition = originalPositions[targetUI]

	-- 获取或创建 UIScale
	local uiScale = targetUI:FindFirstChildOfClass("UIScale")

	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = targetUI
	end

	-- 开始位置：稍微向下偏移
	targetUI.Position = originalPosition + UDim2.fromOffset(0, 18)
	uiScale.Scale = 0.96
	targetUI.Visible = true

	-- 平滑移动 + 轻微放大
	local tweenInfo = TweenInfo.new(
		0.25,
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)

	TweenService:Create(targetUI, tweenInfo, {
		Position = originalPosition
	}):Play()

	TweenService:Create(uiScale, tweenInfo, {
		Scale = 1
	}):Play()
end

--------------------------------------------------
-- 鹅化物配置
--------------------------------------------------

local GooseConfig =
	require(
		ReplicatedStorage.Config:WaitForChild("GooseConfig")
	)

--------------------------------------------------
-- 果实背包 RemoteFunction
--------------------------------------------------

local GetFruitInventory =
	ReplicatedStorage.RemoteFunction:WaitForChild(
		"GetFruitInventory"
	)

--------------------------------------------------
-- 打开 UI
--------------------------------------------------

local function OpenGui(frame)

	for _, template in pairs(frame:GetChildren()) do

		if template.Name ~= "Template"
			and template:IsA("ImageButton") then

			template:Destroy()

		end

	end

end

--------------------------------------------------
-- 打开鹅化物背包
--------------------------------------------------

local function Openbeibaoui()

	local frame =
		beibaoui:WaitForChild("ScrollingFrame")

	--------------------------------------------------
	-- UI显示（平滑动画）
	--------------------------------------------------

	ShowUIWithTween(beibaoui)

	--------------------------------------------------
	-- 清除旧物品
	--------------------------------------------------

	for _, child in ipairs(frame:GetChildren()) do

		if child ~= frame.Template
			and child:IsA("ImageButton") then

			child:Destroy()

		end

	end

	--------------------------------------------------
	-- 获取玩家鹅化物背包
	--------------------------------------------------

	local GooseInventory =
		GetGooseInventory:InvokeServer()

	if not GooseInventory then

		warn("获取鹅化物背包失败")

		return

	end

	print(
		"玩家鹅化物总数量：",
		#GooseInventory
	)

	--------------------------------------------------
	-- 统计鹅化物
	--------------------------------------------------

	local GooseCount = {}

	for _, inventoryItem in ipairs(GooseInventory) do

		local gooseId =
			inventoryItem.GooseId

		if gooseId
			and inventoryItem.EquipState ~= true then

			GooseCount[gooseId] =
				(GooseCount[gooseId] or 0) + 1

		end

	end

	--------------------------------------------------
	-- 创建背包 UI
	--------------------------------------------------

	local order = 0

	for gooseId, quantity in pairs(GooseCount) do

		local item =
			GooseConfig[gooseId]

		if not item then

			warn(
				"找不到鹅化物配置：",
				gooseId
			)

			continue

		end

		order += 1

		--------------------------------------------------
		-- 克隆 Template
		--------------------------------------------------

		local Template =
			frame.Template:Clone()

		Template.Name =
			gooseId

		Template.LayoutOrder =
			order

		Template.Visible = true

		--------------------------------------------------
		-- 点击鹅化物
		--------------------------------------------------

		Template.Activated:Connect(function()

			local selectedItem = nil

			for _, inventoryItem in ipairs(
				GooseInventory
				) do

				if inventoryItem.GooseId == gooseId
					and inventoryItem.EquipState ~= true then

					selectedItem =
						inventoryItem

					break

				end

			end

			if not selectedItem then

				warn(
					"没有可放置的鹅化物：",
					gooseId
				)

				return

			end

			print(
				"选择鹅化物：",
				selectedItem.ID,
				selectedItem.GooseId
			)

			StartGoosePlacementEvent:Fire(
				selectedItem.ID,
				selectedItem.GooseId
			)

		end)

		--------------------------------------------------
		-- 设置图标
		--------------------------------------------------

		local icon =
			ReplicatedStorage.Icons:FindFirstChild(
				item.Icon
			)

		if icon then

			Template.Image =
				icon.Image

		else

			warn(
				"找不到鹅化物图标：",
				item.Icon
			)

		end

		--------------------------------------------------
		-- 设置名称
		--------------------------------------------------

		local nameLabel =
			Template:FindFirstChild("Name")

		if nameLabel then

			nameLabel.Text =
				item.Name

		end

		--------------------------------------------------
		-- 设置数量
		--------------------------------------------------

		local quantityLabel =
			Template:FindFirstChild("shu")

		if quantityLabel then

			quantityLabel.Text =
				"x" .. quantity

		end

		--------------------------------------------------
		-- 放入 ScrollingFrame
		--------------------------------------------------

		Template.Parent =
			frame

	end

end

--------------------------------------------------
-- 打开鹅化物商店
--------------------------------------------------

local function Openshopui()

	local frame =
		shopui.ScrollingFrame

	ShowUIWithTween(shopui)

	OpenGui(frame)

	--------------------------------------------------
	-- 商品顺序
	--------------------------------------------------

	local jishu = 0

	local gooseList = {}

	for gooseId, item in pairs(
		GooseConfig
		) do

		table.insert(
			gooseList,
			{
				Id = gooseId,
				Data = item
			}
		)

	end

	table.sort(
		gooseList,
		function(a, b)

			local numberA =
				tonumber(
					a.Id:match("%d+")
				)
				or 0

			local numberB =
				tonumber(
					b.Id:match("%d+")
				)
				or 0

			return numberA < numberB

		end
	)

	--------------------------------------------------
	-- 创建商品
	--------------------------------------------------

	for _, goose in ipairs(
		gooseList
		) do

		local gooseId =
			goose.Id

		local item =
			goose.Data

		jishu += 1

		local Template =
			frame.Template:Clone()

		Template.Name =
			gooseId

		Template.LayoutOrder =
			jishu

		--------------------------------------------------
		-- 图标
		--------------------------------------------------

		local icon =
			ReplicatedStorage.Icons:FindFirstChild(
				item.Icon
			)

		if icon then

			Template.Icon.Image =
				icon.Image

		end

		--------------------------------------------------
		-- 商品信息
		--------------------------------------------------

		Template.ItemName.Text =
			item.Name

		Template.Price.Text =
			"$" .. item.Price

		Template.Rarity.Text =
			item.Rarity

		Template.Description.Text =
			item.Description

		Template.Effect.Text =
			item.Effect.Text

		Template.Visible = true
		Template.Parent = frame

	end

end


--------------------------------------------------
-- 打开果实背包
--------------------------------------------------

local function OpenGuoshiui()

	print("========== 打开果实背包 ==========")

	local frame =
		guoshui:WaitForChild("ScrollingFrame")

	local Template =
		frame:WaitForChild("Template")

	--------------------------------------------------
	-- UI显示（平滑动画）
	--------------------------------------------------

	ShowUIWithTween(guoshui)

	--------------------------------------------------
	-- 清除之前克隆出来的果实
	--------------------------------------------------

	for _, child in ipairs(frame:GetChildren()) do

		if child ~= Template
			and child:IsA("GuiObject") then

			child:Destroy()

		end

	end

	--------------------------------------------------
	-- 获取玩家果实背包
	--------------------------------------------------

	local FruitInventory =
		GetFruitInventory:InvokeServer()

	if not FruitInventory then

		warn("[果实背包] GetFruitInventory 返回 nil")

		return

	end

	print(
		"[果实背包] 获取到果实数量：",
		#FruitInventory
	)

	--------------------------------------------------
	-- 打印实际数据
	-- 方便检查你的 FruitInventory 结构
	--------------------------------------------------

	for index, fruitData in ipairs(FruitInventory) do

		print(
			"[果实背包] 数据",
			index,
			fruitData
		)

	end

	--------------------------------------------------
	-- 统计果实
	--------------------------------------------------

	local FruitCount = {}

	for _, fruitData in ipairs(FruitInventory) do

		local fruitId = nil
		local quantity = 1

		--------------------------------------------------
		-- 兼容不同的数据结构
		--------------------------------------------------

		if typeof(fruitData) == "string" then

			-- 例如：
			-- FruitInventory = {"Apple", "Apple", "Banana"}

			fruitId = fruitData

		elseif typeof(fruitData) == "table" then

			fruitId =
				fruitData.FruitId
				or fruitData.Fruit
				or fruitData.Name
				or fruitData.ID

			quantity =
				tonumber(
					fruitData.Quantity
					or fruitData.Amount
					or fruitData.Count
				)
				or 1

		end

		--------------------------------------------------
		-- 找到果实
		--------------------------------------------------

		if fruitId then

			FruitCount[fruitId] =
				(
					FruitCount[fruitId]
					or 0
				)
				+ quantity

		end

	end

	--------------------------------------------------
	-- 如果没有果实
	--------------------------------------------------

	local fruitTypeCount = 0

	for _ in pairs(FruitCount) do
		fruitTypeCount += 1
	end

	if fruitTypeCount == 0 then

		warn(
			"[果实背包] FruitInventory 里面没有可以显示的果实"
		)

		return

	end

	--------------------------------------------------
	-- 开始 Clone Template
	--------------------------------------------------

	local order = 0

	for fruitId, quantity in pairs(FruitCount) do

		order += 1

		print(
			"[果实背包] 正在创建：",
			fruitId,
			"x" .. quantity
		)

		--------------------------------------------------
		-- Clone Template
		--------------------------------------------------

		local newTemplate =
			Template:Clone()

		newTemplate.Name =
			fruitId

		newTemplate.LayoutOrder =
			order

		newTemplate.Visible = true

		--------------------------------------------------
		-- 找 Icons2 里面的图片
		--------------------------------------------------

		local icon =
			ReplicatedStorage
			:WaitForChild("Icons2")
			:FindFirstChild(fruitId)

		if icon then

			--------------------------------------------------
			-- Template 如果本身是 ImageButton / ImageLabel
			--------------------------------------------------

			if newTemplate:IsA("ImageButton")
				or newTemplate:IsA("ImageLabel") then

				newTemplate.Image =
					icon.Image

			else

				--------------------------------------------------
				-- 如果 Template 是 Frame
				-- 就找里面的 Image
				--------------------------------------------------

				local image =
					newTemplate:FindFirstChild(
						"Image",
						true
					)

				if image
					and (
						image:IsA("ImageLabel")
							or image:IsA("ImageButton")
					) then

					image.Image =
						icon.Image

				end

			end

		else

			warn(
				"[果实背包] Icons2 找不到：",
				fruitId
			)

		end

		--------------------------------------------------
		-- 设置名称
		--------------------------------------------------

		local nameLabel =
			newTemplate:FindFirstChild(
				"Name",
				true
			)

		if nameLabel
			and nameLabel:IsA("TextLabel") then

			nameLabel.Text =
				fruitId

		end

		--------------------------------------------------
		-- 设置数量
		--------------------------------------------------

		local quantityLabel =
			newTemplate:FindFirstChild(
				"shu",
				true
			)

		if quantityLabel
			and quantityLabel:IsA("TextLabel") then

			quantityLabel.Text =
				"x" .. quantity

		end

		--------------------------------------------------
		-- 点击果实进行切换
		--------------------------------------------------

		local function SelectFruit()

			print(
				"[果实背包] 选择果实：",
				fruitId
			)

			-- 发送给服务器
			-- 服务器会再次检查玩家是否拥有这个果实
			SetSelectedFruit:FireServer(
				fruitId
			)

		end

		-- Template 如果本身就是按钮
		if newTemplate:IsA("GuiButton") then

			newTemplate.Activated:Connect(SelectFruit)

		else

			-- 如果 Template 是 Frame，寻找里面的按钮
			local button =
				newTemplate:FindFirstChildWhichIsA(
					"GuiButton",
					true
				)

			if button then

				button.Activated:Connect(SelectFruit)

			else

				warn(
					"[果实背包] Template 没有可点击的 GuiButton：",
					fruitId
				)

			end

		end

		--------------------------------------------------
		-- 放入 ScrollingFrame
		--------------------------------------------------

		newTemplate.Parent =
			frame

		print(
			"[果实背包] Template 克隆成功：",
			newTemplate.Name
		)

	end

	print("========== 果实背包打开完成 ==========")

end

--------------------------------------------------
-- 按钮点击
--------------------------------------------------

openshop.Activated:Connect(function()

	Openshopui()

end)

--------------------------------------------------
-- 鹅化物背包
--------------------------------------------------

openbeibao.Activated:Connect(function()

	Openbeibaoui()

	if _G.OpenPlantCamera then

		_G.OpenPlantCamera()

	end

end)

--------------------------------------------------
-- 果实背包
--------------------------------------------------

openguoshi.Activated:Connect(function()

	OpenGuoshiui()

end)

--------------------------------------------------
-- 监听鹅化物放置 / 回收成功 → 自动刷新背包
--------------------------------------------------

local GoosePlacementResult =
	RemoteEvent:WaitForChild("GoosePlacementResult")

GoosePlacementResult.OnClientEvent:Connect(function(success, itemId, gooseId, reason)

	if not success then
		return
	end

	--------------------------------------------------
	-- 只有背包当前打开时才刷新
	--------------------------------------------------

	if beibaoui.Visible == true then

		task.spawn(function()

			-- 等一帧，让服务器数据先写入完成
			task.wait(0.1)

			Openbeibaoui()

		end)

	end

	--------------------------------------------------
	-- 调试日志
	--------------------------------------------------

	if reason == "Placed" then
		print("[背包] 放置成功，刷新背包：", gooseId)
	elseif reason == "Recycled" then
		print("[背包] 回收成功，刷新背包：", gooseId)
	end

end)