# 植物种植大亨 · Plant Tycoon

> Roblox 多人联机经营游戏，**Luau** 编写，服务端 + 客户端完整实现。
> 核心循环：种植 → 成长 → 枝条强化 → 果实产出 → 出售 → 扩大经营。

---

## 项目概况

| | |
|---|---|
| 类型 | 多人联机经营（Tycoon） |
| 我的角色 | 独立开发：玩法设计、系统拆分、服务端 / 客户端逻辑、数据持久化 |
| 技术栈 | Luau · Roblox Studio · DataStore · RemoteEvent / RemoteFunction · TweenService |
| 代码规模 | **39 个脚本 · 约 7,800 行 Luau** |

---

## 目录结构

```
src/
├── server/                        服务端
│   ├── Main.server.lua            主控：初始化、玩家生命周期
│   ├── Data/
│   │   ├── DataService.lua        数据统一读写（缓存 + 校验）
│   │   └── DefaultData.lua        新玩家默认数据
│   ├── Services/                  业务模块（ModuleScript）
│   │   ├── PlantService.lua       植物成长、土地分配、缩放对齐
│   │   ├── GooseService.lua       装饰物数据与槽位
│   │   ├── PlotService.lua        土地归属与分配
│   │   └── FruitService.lua       果实库存、切换、结算
│   └── daima/                     各系统的服务端脚本
│       ├── PlantServer.server.lua         种植 / 成长入口
│       ├── GooseServer.server.lua         装饰物放置 / 编辑 / 回收
│       ├── SignInServer.server.lua        每日签到
│       ├── GoldSyncServer.server.lua      金币同步
│       └── FruitServer.server.lua         果实产出与出售
│
├── client/                        客户端
│   ├── scripts/
│   │   ├── GoosePlacementClient.client.lua   装饰物拖拽放置
│   │   ├── PlantCameraController.client.lua   种植视角
│   │   └── ChestClient.client.lua             宝箱交互
│   └── ui/                        各界面脚本（商店 / 签到 / 背包 / 离线收益…）
│
└── shared/                        共享
    ├── Config/                    植物 / 装饰物 / 签到配置
    └── GooseModels/               装饰物模型内嵌脚本
```

> 通过 [Rojo](https://github.com/rojo-rbx/rojo) 映射回 Studio 的实例树。

---

## 三个设计取舍

### 1. 植物缩放为什么不直接 `ScaleTo`

**问题**：`Model:ScaleTo()` 以 **Pivot（模型中心）** 为基准缩放。植物从 1 倍长到 1.5 倍时，底部会向下沉进土里。

**方案**：缩放前后各取一次包围盒，算出底面位置差，再把模型整体推回去。

```lua
local beforeBottom = boxCFrame.Position - up * (boxSize.Y / 2)
plant:ScaleTo(targetScale)
local moveOffset = beforeBottom - afterBottom
plant:PivotTo(plant:GetPivot() + moveOffset)
```

**为什么用包围盒而不是 `PrimaryPart.Size`**：主部件可能只是树干，果实和枝叶才是真正的轮廓。

📄 `src/server/Services/PlantService.lua` → `UpdatePlantVisual`

---

### 2. 装饰物放置为什么不用 `RemoteFunction`

**问题**：`RemoteFunction` 是阻塞的，调用后服务端线程会挂起等客户端返回。高频调用会堆积线程，客户端不返回还会死锁。

**方案**：改成**请求-响应**——客户端发 `PlaceGoose` 事件，服务端校验后用 `GoosePlacementResult` 回包。

```lua
PlaceGoose:FireServer(itemId, side, height, length, worldPosition)
GoosePlacementResult:FireClient(player, true, itemId, gooseId, "Placed")
```

**服务端校验链**：参数类型 → 长度范围 → 背包归属 → 槽位数量 → 植物是否存在。

📄 `src/server/daima/GooseServer.server.lua`

---

### 3. 签到为什么按"自然日"而不是"24 小时"

**问题**：按"距离上次领取 24 小时"判定，玩家晚上 11 点签一次，第二天要等到晚上 11 点，体验很差。

**方案**：把时间戳按固定时区偏移换算成日期字符串，按 **日期差** 判定。

```lua
-- 0 = 今天已签；1 = 连续签到；≥2 = 断签，重置到第 1 天
local difference = GetDayDifference(lastClaimDate, today)
```

**关键点**：时间全部由服务端计算，客户端改系统时间无效。

📄 `src/server/daima/SignInServer.server.lua` → `GetSignInState`

---

## 技术要点

- **服务端权威**：经济、土地归属、槽位、成长全部服务端计算，客户端只发意图
- **属性驱动**：成长值 / 高度 / 槽位数用 `Attribute` 同步，客户端监听变化刷新表现
- **数据集中**：`DataService` 统一管理存档，业务模块不直接读写 DataStore
- **装饰物跟随缩放**：记录摆放时的植物缩放，植物长大后按比例还原
- **模块化拆分**：数据 / 土地 / 植物 / 装饰物 / 果实各自独立，通过 ModuleScript 组合

---

## 说明

- 场景资产（地图、模型、UI 布局）保留在 Studio 工程中，本仓库只包含**脚本源码**
- 数据层使用社区模块 **DataStore2**（第三方库，未包含在本仓库）
- 地图模型内嵌的少量交互脚本随模型保留，未单独导出

---

## 如何查看

1. 安装 [Rojo](https://github.com/rojo-rbx/rojo/releases)
2. 项目根目录执行 `rojo serve`
3. Roblox Studio 安装 Rojo 插件，连接 `localhost:34872`

也可以直接浏览 `src/` 下的源码。

---

## License

仅供学习与作品展示使用。
