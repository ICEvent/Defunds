# Portfolio 与 ICEvent Assets 兼容约定

状态：实施规格，尚未实现、编译或部署。2026-11-10 核对 Defunds main f72a44d，以及 ICEvent/icevent_service master 50c15a28b4eb405b0905ad2992ed5a258047ec8b。

## 源码事实

- `src/ledger/assets/types.mo` 的 AssetOwner 为 principal 或 calendar；Asset 为资源档案，没有金融持有数量、取得成本或估值流水。capacity 表示容量，不能用作持有数量。
- 资源类别包含 person；人员、可使用的场地与受托设备不表示 Fund 拥有财产，不能自动导入财务资产。
- `src/ledger/main.mo` 中 getAsset/listAssets 按调用者及 calendarService.checkPermission 检查；updateAsset/deleteAsset 要求个人所有者或 Calendar edit 权限。canister 间调用不会继承浏览器用户身份。
- getAsset 返回 null 同时可能表示不存在或无权限；不得据此把绑定标记为“源资产已删除”。
- `src/ledger/assets/lib.mo` 的 deleteAsset 会移除资产及全部排期。现有代码没有跨应用绑定保护。
- API 文档中的资产结构缺少当前源码已有的 owner；接入以固定版本的实际 Candid/源码为准。

## 数据权威与引用

ICEvent 维护名称、类型、描述、规格、容量、运行状态和排期；Defunds 维护财务主体、持有数量/份额、成本、估值和增减流水。Calendar owner 是应用授权范围，不证明法律所有权；Fund 持有关系必须另行明确记录。

AssetRef = { network（ic 或特定本地实例标识）, ledgerCanister: Principal, assetId: Nat }。
唯一键使用三个字段，不使用名称匹配。绑定是 PortfolioPosition 与 AssetRef 的关系，包含 bindingId、portfolioId、positionId、财务主体、明确持有范围、状态、revision、双方批准人及批准时间。不要在 ICEvent metadata 中塞入财务余额作为第二份账本。

绑定状态：unverified（仅引用）→ pending（待确认）→ active（双方确认）→ revoked（撤销）。来源不可访问是独立的查询结果 unavailable/permissionDenied，不等同于 revoked 或 deleted。sourceMissing 只能由可信桥接接口明确返回。

同一 Portfolio 不允许把同一资源重复绑定到多个有效 position。第一期只支持同一资源绑定一个有效财务 position；多人共有、跨 Fund 分摊待明确份额与转让协议后开放。资源被租用或代管时可以仅作运营关联，不纳入自有资产估值汇总。

缓存只保留明确允许披露的摘要，附 sourceRevision、fetchedAt；不是资源权威数据。运行资料默认用户从 ICEvent 授权读取，不因 Fund 成员身份自动公开给整个 Fund。经资源管理方明确批准后，才可发布指定字段的 Fund 可见摘要。撤权后停止刷新；历史财务凭证留在原财务权限范围，不能继续展示受限运营详情。

## 分阶段接入

### 第一阶段：引用与分离展示

Portfolio 可保存 unverified AssetRef，不冒充经过验证的资产所有权。前端通过用户自己的 ICEvent actor 查询，展示“当前用户可见”的资源信息；不能将客户端返回的内容写成后端已验证事实。无权限时保留财务 position，显示“无法读取源资料”。尚无原生资产详情路由核对结果，不拼造深链。

财务页面分为“财务记录”和“使用与排期”；来源链接旁显示未验证/已验证及刷新时间。操作为“增加持有”“减少持有”“更新估值”；运行状态编辑与排期仍在 ICEvent 执行。新增提供“创建财务资产”和“关联 ICEvent 资源”；实物逐件管理用不同资源 ID，批量资产不得把 capacity 当数量。

### 第二阶段：双方确认绑定

以下是拟新增接口，不是现有可用 API：

1. Defunds `requestAssetBinding(positionId, assetRef, expectedRevision, requestId)`：Fund creator 发起，记录申请人、随机/唯一 nonce、范围、到期时间与 pending 状态。Portfolio Manager 默认不具备代表 Fund 建立跨应用关系的权限。
2. 用户直接调用 ICEvent `approvePortfolioBinding(request)`：按当前资源 owner 检查个人所有者或 Calendar edit 权限。服务端从受信 Defunds canister 获取待绑定请求核对字段，不接受客户端声称已获 Fund 授权。记录限定 scope、目标 Fund、nonce 和有效期的回执；不授予通用资产读写权限。
3. Defunds `confirmAssetBinding(bindingId)`：通过部署配置允许的 ICEvent ledger 调用桥接接口读取回执，验证 network、两侧 canister、assetId、positionId、nonce、有效期、当前授权与状态。await 后重新检查 Fund 授权、position revision、pending 状态和唯一性，再原子激活。
4. ICEvent 桥接只向回执指定的 Defunds canister 返回已批准字段；无法靠前端传入 caller Principal 代理任意用户。任意 canister 不能通过自称 Defunds 获得权限。
5. 申请重试按 requestId 去重；过期、拒绝、撤销、确认失败都保留状态与原因。远程批准后本地失败可重试确认，不能显示 active。

双侧建立关系不意味着两次写入具备跨 canister 原子性。active 显示需要最近一次远端有效性检查；无法检查时显示“关联待复核”，保留财务记录，不显示实时同步成功。财务增减仍是本地账本操作；不触发排期、转账或资源删除。

## 状态、撤销与删除

维修不改变数量，减少持有不自动取消预约。处置关联实物时提示检查未来预约，未经独立授权不能自动修改 ICEvent。

双方可撤销自己批准的绑定；ICEvent 的当前资源管理者可撤销运营侧授权。已有批准人的权限发生变化，重新核验时要求当前管理者确认，避免旧授权无限延续。Calendar 与 Fund 不做 ID 相等映射，不自动同步成员。

在跨应用绑定正式开放前，ICEvent 必须增加持久化反向绑定索引，并在 deleteAsset 中阻止删除 active 或尚未过期的已批准绑定资源。索引随升级保留；所有删除入口使用同一保护。优先新增归档流程；当前 inactive 只是不可调度状态，不等同已归档或已删除。解绑不能删除财务历史。

已有资产和排期不搬迁；按明确 ID 手工选择关联，不按名字自动合并。发现已删除来源时保留 financial position 与历史，要求管理员处理来源关系，不能将估值或持有数量清零。

## 实施顺序与验证门槛

1. Defunds Portfolio 本地台账、成员权限、幂等和 revision 校验；允许未验证引用并准确标注。
2. ICEvent 绑定回执、受限读取、反向索引与删除保护；同时固定 Candid 版本与受信 canister 配置。
3. 接入双侧确认、来源摘要和刷新状态；跨应用测试通过后开放“已验证关联”。

必须验证：伪造来源/canister/nonce 被拒；普通成员不能批准；一侧批准不生效；请求过期与重放安全；await 期间移除成员或更改 position 后确认失败；同资源并发绑定仅一次成功；撤权后不泄露摘要；源读取 null 不误报删除；关联资产禁止硬删；升级保留回执与索引；不修改既有资金余额、投票权与排期。

未执行上述测试；本次仅静态核对与规格更新。
