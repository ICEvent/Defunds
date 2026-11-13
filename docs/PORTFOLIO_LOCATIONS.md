# Portfolio 位置与持仓

状态：开发实现，尚未部署。基线：main aea6aae。旧 GroupFund、GroupProposal 和 Portfolio Asset 稳定记录不变；位置、绑定和调拨使用独立持久化字段。

## 数据模型

- Location：名称、Fund ID、类型、启用状态和 revision。支持外部 IC 钱包（Principal + 可选 subaccount）、银行参考、现金保管处、仓库和其他地点。银行等仅保存用户填写的描述/掩码参考，不接银行 API。钱包默认子账户与全零子账户归一化为同一身份，重复登记被拒绝。
- Definition：配置中的 currency ID，或已有 Portfolio Asset 的 ID。Currency 身份以 ledger ID 为准；实物定义复用已有 Asset 的名称、单位、精度及原 ICEvent 引用。不同 ledger 的同名 ticker 不合并。
- Binding：一个已有 Asset（持仓记录）对应一个 Definition + Location，首次绑定后不能通过重新绑定静默换位置。Fund + Definition + Location 唯一，包括归档持仓。
- Movement：关联源和目标持仓及两条原流水，记录数量、同资产手续费、操作者、时间和备注。它是外部已发生调拨的账务记录，不执行链上或银行转账。

旧 Asset 默认投影为“未分配位置”，不修改原余额或创建迁移流水。使用 Assign existing 明确选择定义和位置；单位与精度必须相同。已有定义被其他持仓引用后，不允许把定义根重归类为另一种资产。新增同一种实物在另一位置的持仓时选择同一个资产定义，不重复创建 ICEvent 资源。

## 余额与总览

- 位置持仓只记录属于 Fund 的数量，不能把混有个人资产的整个外部钱包余额计入 Fund。
- Fund 自有链上账户仍由 getFundTreasuryBalances 实查。所有属于本后端 Principal 的钱包地址均禁止注册成“外部手工钱包”，避免把已由系统读取的账户再自动当作手工位置。
- 总览按 Definition 汇总各处手工持仓，并在同一个配置 currency ID 下合入 Fund 子账户的实查余额。单位和精度必须一致，否则拒绝静默相加。
- 尚未取到或读取失败的链上余额显示 Unknown / Partial，不当成 0；明确查到 0 才是已知零。不同资产、不同币种不做未经汇率折算的总价值求和。
- 按位置视图保留外部手工来源、未分配记录和 Fund treasury 实查的区别。禁用位置只限制新增持仓和作为调拨目标，不隐藏原数量或历史。
- 外部钱包目前不读取链上全额余额、不验证钱包控制权；属于用户填报的 Fund 份额。非 IC 钱包可作为其他位置描述，但没有跨链查询或转账支持。

## 调拨规则

源减少 quantity + fee，目标增加 quantity，所以总数量仅减少手续费。源、目标必须为同一 Fund、相同 Definition、单位与精度相同，且属于两个不同的已登记位置。目标可先建零持仓。

两端调用同一个纯业务状态转换：先在临时状态应用转出，再应用转入，全部成功后才由 actor 原子提交。超额、旧 revision、归档目标等错误不会造成只扣源不加目标。requestId 作用域为 Fund + caller，重试返回同一结果；同 ID 不同载荷拒绝。

内部低层请求使用保留前缀 location:。公开 Portfolio 写接口拒绝此前缀；转换也拒绝已有的同名低层回执，避免历史回执被误用成新调拨的一半。调拨生成的两条流水禁止单独冲销，界面隐藏相应冲销按钮；需要纠错时记录新的反向调拨，实际手续费仍单独保留。

## 权限与容量

所有读取仅对 Fund 创建者和当前成员开放，包括公开 Fund 的位置明细。写入沿用 creator / Portfolio Manager 权限，与投票权独立。移除成员后权限立即失效。

每 Fund 最多 50 个登记位置，持仓复用 Portfolio 原有总计 200 项上限，位置操作回执最多 5,000 条；调拨还受 Portfolio 总计 5,000 条流水限制。历史分批读取，每批最多 100。达到上限后拒绝写入，不丢弃旧记录；扩容需要后续索引化存储方案。

## 接口

- getFundLocationPortfolio(fundId)：位置、含归档的持仓投影、当前币种定义、当前写权限及关联调拨流水 ID。
- writeFundLocationPortfolio(fundId, requestId, operation)：addLocation / updateLocation / bind / create / move。
- listFundLocationHistory(fundId, offset, limit)：带操作者与时间的位置、绑定和调拨历史。

旧 Portfolio UI 保留逐项增减、估值、状态和归档功能。修改后自动刷新位置总览；位置变动后也刷新原资产列表。位置重命名不改变地址或身份；位置类型/地址不可原地替换。

## 验证范围

新增 PortfolioLocations.test.mo 验证聚合前提、继承旧记录、成对数量变动、手续费、幂等、目标旧 revision 时不部分扣减、跨 Fund 隔离、位置禁用、默认子账户归一化及旧内部回执防重。portfolio-locations.test.mjs 验证按资产汇总、相同 ticker 不合并、未知余额、精度和 subaccount 输入。

扩展真实 canister E2E：权限、重复请求、跨 Fund 位置拒绝、关联流水冲销保护、成对调拨和已有数据升级。浏览器用例使用实际 Svelte 组件和模拟传输，覆盖新建位置、旧记录归属、新建目标持仓、记录调拨、两种视图及手机布局。完整结果以该分支 CI 为准；不将本地编译等同于真实 canister 验证。

提案来源位置、自动付款及外部付款登记/核验仍为后续功能，本轮没有发送任何实际资金。
