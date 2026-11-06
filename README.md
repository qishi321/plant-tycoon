# 植物种植大亨 · 服务端

> Roblox 多人联机经营游戏的服务端模块，使用 **Luau** 编写。
> 核心循环：种植 → 成长 → 枝条强化 → 果实产出 → 出售 → 扩大经营。

---

## 项目概况

| | |
|---|---|
| 类型 | 多人联机经营（Tycoon） |
| 我的角色 | 独立开发：玩法设计、系统拆分、服务端逻辑、数据持久化 |
| 技术栈 | Luau · Roblox Studio · DataStore · RemoteEvent / RemoteFunction |
| 架构 | ModuleScript 模块化，服务端权威，客户端只做表现 |

---

## 目录结构

```
src/server/Services/
├── PlantService.lua      植物成长、土地分配、缩放与底部对齐
├── GooseServer.lua       装饰物（鹅化物）的购买、放置、编辑、回收、跟随缩放
└── SignInService.lua     每日签到、连续签到判定、奖励发放
```

> 通过 Rojo 映射到 Studio 的 `ServerScriptService/Services`。

---

## 三个设计取舍

### 1. 植物缩放为什么不直接 `ScaleTo`

**问题**：`Model:ScaleTo()` 是以 **Pivot（模型中心）** 为基准缩放的。植物从 1 倍长到 1.5 倍时，底部会向下沉进土里。

**方案**：缩放前后各取一次包围盒，算出底面位置差，再把模型整体推回去。

```lua
-- 缩放前记录底面
local beforeBottom = boxCFrame.Position - up * (boxSize.Y / 2)
plant:ScaleTo(targetScale)
-- 缩放后重算，把偏移补回来
local moveOffset = beforeBottom - afterBottom
plant:PivotTo(plant:GetPivot() + moveOffset)
```

**为什么用包围盒而不是 `PrimaryPart.Size`**：主部件可能只是树干，果实/枝叶才是真正的轮廓。

📄 `PlantService.lua` → `UpdatePlantVisual`

---

### 2. 装饰物放置为什么不用 `RemoteFunction`

**问题**：`RemoteFunction` 是阻塞的，调用后服务端线程会挂起等待客户端返回。高频调用会堆积线程，客户端不返回还会死锁。

**方案**：改用 **请求-响应模式**——客户端发 `PlaceGoose` 事件，服务端校验后通过 `GoosePlacementResult` 回包。

```lua
-- 客户端只发"我要放哪个、放哪"
PlaceGoose:FireServer(itemId, side, height, length, worldPosition)

-- 服务端五重校验后回包
GoosePlacementResult:FireClient(player, true, itemId, gooseId, "Placed")
```

**校验了什么**：类型 → 长度范围 → 归属（是不是你的地）→ 槽位数量 → 植物是否存在。

📄 `GooseServer.lua` → `PlaceGoose.OnServerEvent`

---

### 3. 签到为什么按"自然日"而不是"24 小时"

**问题**：如果按"距离上次领取 24 小时"判定，玩家晚上 11 点签一次，第二天就得等到晚上 11 点，体验很差。

**方案**：把时间戳按固定时区偏移换算成日期字符串，按 **日期差** 判定：

```lua
-- 差值 0 = 今天签过；1 = 连续签到；≥2 = 断签，重置到第 1 天
local difference = GetDayDifference(lastClaimDate, today)
```

**关键点**：所有时间计算都在服务端，客户端改系统时间无效。

📄 `SignInService.lua` → `GetSignInState`

---

## 其他技术点

- **服务端权威**：经济、土地归属、槽位数量全部由服务端计算与校验，客户端只发意图
- **属性驱动**：成长值、高度、槽位数通过 `Attribute` 同步，客户端监听变化更新表现
- **数据集中**：`DataService` 统一管理玩家数据，业务模块不直接读写 DataStore
- **防重复领取**：领取后写入日期戳并做幂等判断

---

## 说明

为保护完整业务逻辑，本仓库只开源**服务端核心模块**，配套的 `DataService`、`PlotService`、配置表与客户端代码未包含。

代码可直接阅读；完整运行需要补齐上述依赖。

---

## 如何查看

1. 安装 [Rojo](https://github.com/rojo-rbx/rojo/releases)
2. 在项目根目录执行 `rojo serve`
3. Roblox Studio 安装 Rojo 插件，连接到 `localhost:34872`

---

## License

仅供学习与作品展示使用。
