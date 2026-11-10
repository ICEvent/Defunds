# Group Portfolio 管理设计

状态：设计与第一阶段实现，尚未部署。代码基线：main / f72a44d，检查日期：2026-11-10。

## 定位与当前代码

Defunds 是财务持有、估值与资产变动台账的权威来源；ICEvent Assets 是已有资源资料、运行状态与排期的权威来源。两者通过显式绑定关联，不重复创建资源档案。兼容约定见 `GROUP_PORTFOLIO_ICEVENT_COMPATIBILITY.md`。第一阶段仅手工记账，不执行转账，不修改 Treasury 余额，不产生投票权。

当前业务后端 `src/backend/main.mo` 使用 `src/backend/group/types.mo` 的 GroupFund；成员只有 name、principal、votingPower，创建者负责成员管理。`src/governance` 另有 Group/Role 模型，不能把两套 ID 或权限直接等同。当前 main 没有 Portfolio 模块。

第一阶段在现有 GroupFund 下提供 Portfolio，入口为 `/funds/[id]`。统一归属类型预留 personal(Principal)、group(Nat)、fund(Nat)，本期只开放 fund；group 指未来独立群组，不拿现有 Fund ID 冒充。独立群组的创建不应依赖捐赠或投票权；本期现有 createGroup 的限制仍然存在。

## 用户操作

Fund 页面增加 Portfolio 页签。显示资产数量、按币种汇总的已知估值、待估值项数；资产列表显示名称、类别、数量、状态、估值及估值日期。默认只显示未归档资产。

新增提供“创建财务资产”和“关联 ICEvent 资产”两条路径；手工财务资产只要求名称、类别、计量单位、小数精度；可选初始数量、估值和备注。初始数量必须生成 opening 流水。操作按钮：增加、减少、更新估值、更新状态、查看历史、归档。没有数量变化时不要求填写交易金额。

支持现金、加密资产、证券、实物、应收款和其他类别。类别只用于分类，不代表已接入行情、钱包或借贷合约。持有状态为持有、锁定、已处置；ICEvent 关联资源的维修、停用、借出或使用情况在独立的“使用状态”列展示，不写回财务持有状态；归档独立于两者。

## 数据模型

| 对象 | 核心字段 |
|---|---|
| Portfolio | id、owner、baseCurrency（未来折算使用）、createdAt |
| AssetPosition | id、portfolioId、name、category、unit、quantityDecimals、quantityAtoms、status、archived、revision |
| AssetTransaction | id、assetId、kind、quantityAtoms、可选 consideration（金額与币种）、effectiveAt、recordedAt、actor、note、可选 reversalOf、requestId |
| AssetValuation | id、assetId、totalValueAtoms、currencyCode、valueDecimals、effectiveAt、recordedAt、actor、source、assetRevisionAtValuation |
| PortfolioEvent | id、portfolioId、assetId（可选）、kind、actor、recordedAt、变更前后值 |
| PortfolioManagers | portfolioId、principals |

数量、金额均用 Nat 最小单位，禁止浮点数。quantityDecimals 创建后不可修改；币种使用独立的代码与精度记录，不扩展当前链上 Types.Currency 来伪装 CAD 等法币为可支付币种。输入设长度、精度与数量上限，服务端验证。

数量只允许 opening/increase/decrease 以及明确引用原流水的冲销改变。quantityAtoms 为流水的原子更新缓存；不提供直接设余额接口。减少量不能超过持有量。一次冲销只能成功一次；冲销增加记录若导致负数也必须拒绝。归档要求余额为零；归档不删除记录，重新启用须生成审计事件。

估值采用整项资产总估值，避免单价与总价混淆。数量变化后旧估值显示“持有量已变化，需重新估值”，不继续计入当前估值汇总。未估值不等于零。明确录入零估值才是零。估值日期不得为未来；回填历史记录不能覆盖日期更新的当前估值。数量流水 effectiveAt 用于业务日期展示，余额按服务端写入顺序校验，第一版不提供历史时点余额。

第一版按币种分别汇总，不把不同币种相加，也不宣称提供统一 CAD 总资产。汇率与自动行情是后续功能。成本和收益统计延后，避免缺失成交成本、费用时生成不可靠盈亏。

## 权限与隐私

| 调用者 | 读取 | 资产与流水写入 | 指定管理员 |
|---|---|---|---|
| Fund creator | 是 | 是 | 是 |
| 当前成员且为 Portfolio Manager | 是 | 是 | 否 |
| 当前成员 | 是 | 否 | 否 |
| 匿名或非成员 | 否 | 否 | 否 |

公开 Fund 也不自动公开 Portfolio 明细；第一版全为成员可见。所有列表、详情、流水和估值查询都在后端执行相同权限检查。votingPower 为零不影响成员阅读资格。移除成员后，管理员授权即使留在存储中也无效，重新加入不自动恢复：移除成员时清理授权。撤销授权、数量变动和改状态都写审计事件。

权限依据 main.mo 中当前 groups 数据实时检查，本地财务权限不依赖外部 governance 或 ICEvent，也不缓存外部成员资格。验证 ICEvent 绑定使用独立桥接协议，不能直接调用现有 getAsset 并假设保留用户身份。

## 接口草案

所有写接口返回 Result，并拒绝匿名。按目标资产反查 portfolio/owner，不能信任前端传入的 groupId。创建权限与创建资产在一次消息中完成，不跨 await。

| 方法 | 用途 |
|---|---|
| getFundPortfolio(fundId) | 成员读取，未初始化返回 null |
| createFundPortfolio(fundId, requestId) | 仅 creator 初始化，Fund 唯一 |
| listPortfolioAssets(portfolioId, cursor, limit, includeArchived) | 成员分页读取 |
| getPortfolioAsset(assetId) | 返回资产与当前有效估值 |
| createPortfolioAsset(portfolioId, input, requestId) | 新增并原子写入 opening |
| recordPortfolioTransaction(assetId, expectedRevision, input, requestId) | 增减或冲销 |
| recordPortfolioValuation(assetId, expectedRevision, input, requestId) | 追加估值 |
| updatePortfolioAsset(assetId, expectedRevision, input, requestId) | 修改名称、类别、状态，记录审计 |
| setPortfolioAssetArchived(assetId, expectedRevision, archived, requestId) | 零余额归档或重新启用 |
| setPortfolioManagers(portfolioId, principals, requestId) | creator 授权当前成员 |
| listPortfolioHistory(assetId, cursor, limit) | 成员查看合并历史 |

所有写入携带 requestId（调用者 + portfolio 作用域），相同请求重试返回同一结果；相同 ID 不同载荷拒绝。expectedRevision 防止多人覆盖；冲突时要求刷新。分页 limit 设服务端上限，游标稳定按 ID 排序，历史不整库返回。金额、备注、日期、Principal、requestId、分页与对象归属必须校验。

## 最小实施路径与兼容性

1. 新增 `src/backend/portfolio/types.mo` 和纯业务库；独立 Portfolio 存储及 ID 计数，不改 GroupFund、LegacyGroupFund 的稳定记录布局。
2. 在 `src/backend/main.mo` 增加持久化状态与授权包装，接入现有升级导出/恢复流程；移除成员时清理管理员授权。不调用 ledger，不复用或更改 group.balance。
3. 生成后端 Candid 与前端声明，为 `/funds/[id]` 增加独立 Portfolio 组件；处理未初始化、无资产、加载失败、权限变化和 revision 冲突。
4. 验证后以独立 PR 交付；后续再开放 personal 与独立 group，接入 ICEvent 关联和经过核验的钱包余额。

Treasury 接入前只展示人工资产，明确其为用户填报。未来同步 Treasury 时同一账户只保留一个权威余额源；转账/借贷用唯一业务引用去重，禁止把导入流水和手工流水重复计入。应收借款不能同时把贷出现金也作为当前持有现金计算。

## 必要验收

- creator 创建、授权；普通成员可读不可写；零投票权成员可读；匿名和非成员不可读，包含公开 Fund。
- 非 A Fund 成员不能通过替换 assetId/portfolioId 访问 A；授权撤销与成员移除立即生效，重新加入不恢复旧授权。
- 新增 2 ETH、增加 1、减少 0.5 得 2.5；超额减少失败且无部分流水；重试与并发冲突不会重复增减。
- 冲销不删除历史，重复冲销与造成负余额的冲销失败；记录 actor 与服务端时间。
- 更新估值不改数量；数量变化使旧估值失效；未知与零估值分开；不同币种分别汇总。
- 归档正余额失败；零余额归档后历史保留；分页无重复和遗漏。
- 老版本升级后既有 Fund/余额/提案不变；Portfolio 数据、计数、授权、幂等记录在再次升级后保留。回滚须在隔离副本验证稳定签名兼容性，不能假设旧 WASM 可直接恢复新数据。
- Motoko 编译、Candid 兼容检查、前端构建，以及成员/管理员端到端流程全部通过后再考虑部署。

以上为完整目标验收清单；第一阶段已运行的检查及尚未运行的项目见 `GROUP_PORTFOLIO_VERIFICATION.md`。

## 第一阶段实现记录（2026-11-10）

以下实现替代前文的接口草案，尚未主网部署。Portfolio 以已有 Fund ID 为作用域，首次添加资产时开始记录，无需单独初始化 Portfolio 对象；独立 Group 和 personal 暂不开放。资产和日志存于独立持久化字段，既有 GroupFund 稳定记录不变。

- `listFundPortfolioAssets(fundId, afterId, limit, includeArchived)`：按资产 ID 分页，最多 100 项。
- `listFundPortfolioHistory(fundId, assetId, afterId, limit)`：按事件 ID 分页，最多 100 项。
- `getFundPortfolioManagers(fundId)`、`setFundPortfolioManager(fundId, member, enabled)`：当前成员角色管理；creator 自带写权限。
- `listFundPortfolioManagerHistory(fundId, offset, limit)`：授予、撤销及成员移除造成的撤销记录。
- `writeFundPortfolio(fundId, requestId, operation)`：create 或携带 expectedRevision 的 change（increase/decrease/reverse/valuation/details/archive）。数量、事件和幂等回执原子更新，没有跨 canister await。

首版 Fund 详情页以内嵌 Portfolio 区块提供入口，沿用当前产品英文 UI；不是此前概念图的完整布局复刻。支持新增、增减、更新整项估值、修改持有状态、归档/恢复、流水与冲销、管理员授权，以及未验证的 ICEvent 引用。数量与金额使用整数最小单位，精度最大 18。估值与流水使用服务端记录时间，不提供回填业务日期、附件、独立成本核算或自动行情。

未验证引用只在同一 Fund 内按 network/canister/assetId 防重复（包含已归档项，需恢复原项）；它不是跨 Fund 所有权认证，也不能阻止其他 Fund 填写同一来源。正式绑定的唯一性须由 ICEvent 回执与反向索引验证。当前不调用 ICEvent，不缓存其私有资料，不改源资产删除逻辑；正式已验证绑定仍未开放。

为限制单个 Fund 的初期数据量，最多 200 项资产（包含归档）、5,000 条资产事件、50 名资产管理员；幂等回执与事件一起保留。达到历史上限后拒绝新增资产写入，UI 显示后端原因。下一阶段在扩大容量前应改用索引化存储和可扩展分页；当前历史不可删。管理员授予历史达到 5,000 条后不再允许新授权，撤权与成员移除始终允许。

不自动转账、不改变 Treasury balance 或 votingPower。公开 Fund 的非成员也无法读取 Portfolio。成员移除时清理经理授权；重新加入不会恢复旧授权。
