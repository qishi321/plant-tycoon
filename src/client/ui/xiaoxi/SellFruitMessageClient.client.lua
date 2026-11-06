local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------
-- RemoteEvent
--------------------------------------------------

local RemoteEvent =
	ReplicatedStorage:WaitForChild("RemoteEvent")

local SellFruitMessage =
	RemoteEvent:WaitForChild("SellFruitMessage")

--------------------------------------------------
-- UI
--------------------------------------------------

local gui = script.Parent

local frame =
	gui:WaitForChild("Frame")

local scrollingFrame =
	frame:WaitForChild("ScrollingFrame")

local template =
	scrollingFrame:WaitForChild("Template")

--------------------------------------------------
-- Template 默认隐藏
--------------------------------------------------

template.Visible = false

--------------------------------------------------
-- 显示出售消息
--------------------------------------------------

local function ShowSellMessage(fruitName, price)

	--------------------------------------------------
	-- 克隆 Template
	--------------------------------------------------

	local message =
		template:Clone()

	message.Name = "SellMessage"

	message.Visible = true

	message.Parent =
		scrollingFrame

	--------------------------------------------------
	-- 设置文字
	--------------------------------------------------

	local messageText =
		"出售 " ..
		tostring(fruitName) ..
		"  获得 $" ..
		tostring(price)

	--------------------------------------------------
	-- 如果 Template 本身就是 TextLabel
	--------------------------------------------------

	if message:IsA("TextLabel")
		or message:IsA("TextButton")
		or message:IsA("TextBox") then

		message.Text =
			messageText

	else

		--------------------------------------------------
		-- 如果 Template 里面有 TextLabel
		--------------------------------------------------

		local textLabel =
			message:FindFirstChildWhichIsA(
				"TextLabel",
				true
			)

		if textLabel then

			textLabel.Text =
				messageText

		end

	end

	
	
	--------------------------------------------------
	-- 最多保留20条出售消息
	--------------------------------------------------

	local messages = {}

	for _, child in ipairs(scrollingFrame:GetChildren()) do

		if child.Name == "SellMessage" then
			table.insert(messages, child)
		end

	end

	if #messages > 20 then

		table.sort(
			messages,
			function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end
		)

		messages[1]:Destroy()

	end

end

--------------------------------------------------
-- 收到出售消息
--------------------------------------------------

SellFruitMessage.OnClientEvent:Connect(
	function(fruitName, price)

		ShowSellMessage(
			fruitName,
			price
		)

	end
)


