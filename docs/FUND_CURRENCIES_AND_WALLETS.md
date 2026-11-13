# Fund 多币种、钱包分仓与提案执行

## 本轮实现

Fund 配置一组独立币种。链上资产 ID 为 `ic:<ledger principal>`，自定义记账币种 ID 为 `manual:<code>`；同名 ticker 不合并。Ledger 的 symbol/name/decimals 从所选 canister 读取；元数据不代表代币可信背书。CAD 等记账币种由创建者定义代码、名称与精度，不冒充链上余额。每 Fund 最多 16 个定义。

新增提案使用 `createGroupProposalWithCurrency`，保存币种定义快照。停用币种仅限制新提案，历史提案保留原币种和精度。原 GroupFund/GroupProposal 稳定布局不变，注册表及快照使用独立持久化字段。旧接口继续按历史默认币种解释金额；旧自定义 ICRC 提案仍按 raw base units（精度 0）展示，不追溯重算。

`getFundTreasuryBalances` 读取配置中每个 ledger 的 `icrc1_balance_of`，目标账户为后端 Principal + 已有 Fund 32-byte subaccount。只对当前成员开放，并在外部 await 后重新检查成员资格。失败显示 unavailable，不能当成 0；停用的 ledger 仍读取并显示余额，避免隐藏已有资产。

Portfolio 中的 Fund treasury 显示只读链上余额；页面打开、重新获得焦点及手动刷新时更新。每次读取都是快照，不增加持仓流水，不重复导入。手工资产估值与链上余额分开，不产生未经汇率折算的混合币种总资产值。它不导入逐笔交易历史，也没有自动发现尚未配置的 token。

重要：现有 `group.account` 是原始子账户字节，不是 legacy ICP AccountIdentifier。界面同时显示 owner Principal 与 subaccount，并明确这一边界。向后端默认账户转账不会自动分配给某个 Fund。

## 钱包与持仓模型（下一阶段规格，尚未实现）

同一资产可存于多个钱包，资产定义不能与钱包混成一个对象：

| 对象 | 身份与内容 |
|---|---|
| AssetDefinition | network + ledger/contract/native asset identity；币种名称与不可变精度 |
| WalletAccount | 钱包名称、网络、owner/address、可选 subaccount；是否由 Fund 后端控制 |
| HoldingPosition | Fund + AssetDefinition + WalletAccount 唯一组合；数量、数据来源、核验时间 |
| Portfolio | 同一资产跨钱包汇总数量，展开保留每个钱包的位置明细 |

例如同一个 ICP ledger，在 Fund 子账户有 10 ICP，在外部成员钱包有 5 ICP，显示总量 15 ICP 并分别列出位置。两个 ledger 即使都叫 USDC 也不是同一资产；ckETH 与 Ethereum 原生 ETH 也不能直接合成一个链上余额。

外部钱包地址不等于 Fund 拥有权；关联与披露必须获得明确授权。个人钱包混有个人资产时，不能把整个钱包余额计入 Fund，只记录明确属于 Fund 的份额。钱包间调拨关联同一 transferId，源/目标分仓相应改变，总持有量除手续费外不增加。自动读取与手工录入不能同时作为同一分仓的余额来源。

第一轮多币种代码只读取 Fund 自有子账户，没有实现外部钱包注册、分仓与跨钱包汇总；不能把本轮 treasury 卡片解释成完整多钱包功能。

## 提案执行模型（下一阶段规格，尚未实现）

提案创建时固定资产、精度、金额、收款账户和来源钱包。币种选择不代表来源钱包选择。来源不能在通过后被静默更换。

审批状态与付款状态分开：

- Fund 自有账户：审批通过后进入 ready；由具备执行权限的后端按固定来源子账户调用 ledger 转账。执行前验证余额、手续费、权限和提案状态，先持久化执行锁；同一提案不能并发付款。ledger 返回确认回执后标记 paid。网络响应未知时进入 reconciliationRequired，禁止直接重试；查询并核对交易后再收尾。
- 外部钱包：审批通过后进入 awaitingExternalTransfer。成员在自己的钱包操作，再录入转账金额、币种/网络、付款与收款地址、手续费、时间、交易哈希/区块号和备注/凭证。提交后为 reported，不能仅凭一段哈希标为 paid。
- 能读取链上回执时，核验实际网络、资产、来源、目标、金额、成功状态及重复回执；无法链上核验时走明确的人工确认，显示 recordedManually，保留提交人与确认人。失败或不匹配显示异常，不自动改为完成。

Ledger 实际余额是 Fund 自有分仓的权威来源；外部手工分仓应在核验/人工确认时以唯一执行 ID 登记数量和手续费变动。不能把“提交提案”“审批通过”或“填写转账信息”当作资金已经转出。外部提交不能解锁 Fund 自动转账的未知结果锁。

本轮没有自动执行提案、外部付款登记或链上回执核验；已通过的现有 Proposal 仍表示治理决策，资金执行待后续独立实现与安全测试。
