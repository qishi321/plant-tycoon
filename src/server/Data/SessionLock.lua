--==================================================
-- SessionLock 会话锁
--
-- 作用：
--   保证同一个玩家的数据，同一时刻只被一个服务器读写。
--   玩家快速跳服 / 双端在线 / 服务器崩溃时，防止旧服务器覆盖新数据。
--
-- 原理：
--   在 DataStore 里存 { JobId, Time }。
--   加载前抢锁 → 每 20 秒续期 → 离开时释放 → 超过 60 秒没续期允许接管。
--
-- 注意：
--   锁只保证"准入"，真正写数据前仍要调用 IsHeld 再确认一次。
--==================================================

local DataStoreService = game:GetService("DataStoreService")

local LOCK_STORE = DataStoreService:GetDataStore("PlayerLock_v1")

-- 超过这个时间没续期，认为持有者已经崩溃，允许别的服务器接管
local LOCK_TIMEOUT = 60

-- 续期间隔（必须明显小于 LOCK_TIMEOUT，否则会被误判为死亡）
local HEARTBEAT_INTERVAL = 20

-- 抢锁重试
local ACQUIRE_INTERVAL = 2
local ACQUIRE_TIMEOUT = 20

local SessionLock = {}

-- player -> { Key, JobId, Thread, Lost }
local Holds = {}

--------------------------------------------------
-- 当前服务器的唯一标识
--
-- Studio 里 game.JobId 是空字符串，必须给占位值，
-- 否则同一个 Place 开两个窗口会互相判定成"同一个服务器"
--------------------------------------------------

local function GetJobId()
	if game.JobId ~= "" then
		return game.JobId
	end
	return "studio_" .. tostring(game.PlaceId)
end

local function GetKey(player)
	return "lock_" .. tostring(player.UserId)
end

--------------------------------------------------
-- 尝试抢锁（一次）
--
-- UpdateAsync 的回调返回 nil 会取消本次写入，
-- 正好用来表达"我不抢了"，而且整个过程是原子的。
--------------------------------------------------

local function TryAcquire(player)
	local key = GetKey(player)
	local jobId = GetJobId()
	local now = os.time()

	local ok, result = pcall(function()
		return LOCK_STORE:UpdateAsync(key, function(old)
			local lock = old and old.Lock

			local heldByOther = lock
				and lock.JobId ~= jobId
				and (now - (lock.Time or 0)) < LOCK_TIMEOUT

			if heldByOther then
				return nil -- 取消写入 = 抢锁失败
			end

			return {
				Lock = {
					JobId = jobId,
					Time = now,
				},
			}
		end)
	end)

	if not ok or result == nil then
		return false
	end

	return true
end

--------------------------------------------------
-- 续期
--------------------------------------------------

local function Renew(player)
	local hold = Holds[player]
	if not hold then
		return false
	end

	local now = os.time()

	local ok, result = pcall(function()
		return LOCK_STORE:UpdateAsync(hold.Key, function(old)
			if not old or not old.Lock then
				return nil
			end
			if old.Lock.JobId ~= hold.JobId then
				return nil -- 锁已经被别人接管
			end
			old.Lock.Time = now
			return old
		end)
	end)

	return ok and result ~= nil
end

--------------------------------------------------
-- 后台续期循环
--------------------------------------------------

local function StartHeartbeat(player)
	local hold = Holds[player]
	if not hold then
		return
	end

	hold.Thread = task.spawn(function()
		while Holds[player] == hold do
			task.wait(HEARTBEAT_INTERVAL)

			if Holds[player] ~= hold then
				break
			end

			if not Renew(player) then
				-- 锁被别人拿走了：标记失效，后续写入会被拒绝
				hold.Lost = true

				warn(
					"[SessionLock] 续期失败，锁已被接管："
						.. player.Name
				)

				break
			end
		end
	end)
end

--------------------------------------------------
-- 抢锁（带重试）
--
-- 玩家刚跳服时，旧服务器可能还没释放锁，
-- 所以这里轮询等待，而不是立刻失败。
--------------------------------------------------

function SessionLock:Acquire(player)

	if Holds[player] then
		return true
	end

	local deadline = os.clock() + ACQUIRE_TIMEOUT

	while true do

		if TryAcquire(player) then

			Holds[player] = {
				Key = GetKey(player),
				JobId = GetJobId(),
				Lost = false,
			}

			StartHeartbeat(player)

			print(
				"[SessionLock] 已获得会话锁："
					.. player.Name
			)

			return true
		end

		if os.clock() >= deadline then
			warn(
				"[SessionLock] 抢锁超时："
					.. player.Name
			)
			return false
		end

		if not player.Parent then
			return false
		end

		task.wait(ACQUIRE_INTERVAL)
	end
end

--------------------------------------------------
-- 当前是否持有有效锁
--------------------------------------------------

function SessionLock:IsHeld(player)

	local hold = Holds[player]

	return hold ~= nil and hold.Lost ~= true
end

--------------------------------------------------
-- 释放锁（玩家离开时调用）
--------------------------------------------------

function SessionLock:Release(player)

	local hold = Holds[player]

	if not hold then
		return
	end

	Holds[player] = nil

	if hold.Thread then
		pcall(task.cancel, hold.Thread)
	end

	local jobId = hold.JobId

	pcall(function()
		LOCK_STORE:UpdateAsync(hold.Key, function(old)

			if not old or not old.Lock then
				return nil
			end

			if old.Lock.JobId ~= jobId then
				return nil -- 锁已经不是我的了，不要动别人的
			end

			return {
				Lock = nil,
			}
		end)
	end)

	print(
		"[SessionLock] 已释放会话锁："
			.. player.Name
	)
end

return SessionLock
