# Group Portfolio 第一阶段验证

日期：2026-11-10。仅开发分支，未部署主网。

## 已运行

- dfx 0.30.1 `dfx build backend --check`：通过。之后最终源码又用相同 SDK moc 编译 WASM 并导出稳定类型，通过。
- `moc -r --package base <SDK/base> test/PortfolioLedger.test.mo`：通过。覆盖精确数量、增减、超额拒绝、旧 revision、幂等重试/载荷冲突、跨 Fund 修改拒绝、数量变化使估值失效、冲销/重复冲销/负余额冲销拒绝、归档/恢复、零估值、引用去重及实际授权策略。
- `node --test test/portfolio-amount.test.mjs test/personal-loan-*.test.mjs`：46 项通过（其中 2 项为新增 Portfolio 精度/汇总测试）。
- 编译 main f72a44d 与当前版本的 .most，执行 `moc --stable-compatible <baseline.most> <current.most>`：通过。这是稳定类型检查，不等同实际数据升级验证。
- 生成后端、governance、personal_loan、icp_index、icrc1_ledger_canister 声明，运行 `npx svelte-kit sync`、`npm run build --ignore-scripts`（frontend workspace）：通过。
- `svelte-check --workspace src/frontend`：0 errors，17 项既有警告；新增 Portfolio 组件单独编译无警告。
- 临时 happy-dom 实例中编译并挂载实际 Svelte 组件，检查空状态、新增提交的整数数量、成员不显示写按钮，以及 actor 切换后旧响应不覆盖：通过。此项为本地临时交互检查，未加入 CI，也不是浏览器视觉验收。
- `git diff --check`：通过。

现有后端编译仍有两项基线警告：donorCredits 相关 Nat 运算可能 trap、existingBlock 未使用；本次没有新增同类编译警告。

## 未运行 / 未开放

本地 `dfx start --clean --background` 因 Unix socket bind 被环境拒绝而失败，未运行真实 canister 端到端测试、实际升级保留/回滚测试或完整浏览器端到端验收。没有部署或更改主网数据。

ICEvent 引用仅是未验证 ID；不存在资源所有权认证、实时资料读取、双侧批准回执、源资产删除保护。附件、回填业务日期、自动行情、汇率折算、取得成本与盈亏、独立 Group/personal Portfolio 也尚未开放。

## 本地手工验收流程

1. 使用包含既有 Fund 的隔离本地环境，生成最新 backend 声明后启动前端。Fund 创建仍沿用已有投票权条件；本次不修改该条件，不使用生产捐赠来做测试。
2. 创建者进入 `/funds/<id>`，在 Portfolio 新增 2 ETH，数量精度 2；增加 1、减少 0.5，检查余额为 2.5。
3. 更新整项估值为 USD 7,200，检查数量不变；再增加数量，检查显示需要重新估值，旧估值从已知汇总排除。
4. 尝试超额减少、旧 revision 写入、相同 requestId 重复提交，核对日志与数量只更新一次。历史中冲销原增减，不删除原记录；重复冲销应报错。
5. 用零投票权成员、非成员、匿名身份分别读取。成员可读不可写；即使 Fund 公开，非成员及匿名也应收到 Portfolio access denied。
6. 创建者授予成员 Portfolio Manager，成员可以修改；撤销后立即拒绝写入。重新授予后将其移出 Fund、再加入，不应恢复原管理权。
7. 两个 Fund 间替换 assetId、读取 history，不能访问另一 Fund 的资产明细。
8. 清零后归档，默认列表隐藏，启用 Show archived 后仍可查看历史及恢复；正余额不能归档或标记 disposed。
9. 录入 ICEvent reference，确认它一直标明 unverified；不能据此读取 ICEvent 私有信息。同 Fund 相同来源拒绝重复添加。
10. 在副本保存资产、估值、授权及幂等回执后升级，验证全部保留；对旧 WASM 的回滚仅在隔离副本测试。

上述手工流程是待执行清单，不是测试通过声明。新增 Portfolio CI 工作流执行后端构建、Motoko 逻辑测试和精度测试；现有 frontend CI 负责全站构建。

## 后续验证补充

已检查第一阶段提交 aa428f4 的 GitHub CI：motoko、frontend、local_preview、ledger 全部成功；这些旧任务尚不包含 Portfolio canister E2E。

新增 `test/portfolio-e2e.sh` 并接入 Portfolio workflow：在独立临时项目/端口建立测试 Fund，随后升级到不含测试接口的生产 WASM，验证实际 Portfolio API 权限、精确流水、幂等、跨 Fund 隔离、冲销、归档，以及持有资产/估值/授权/回执/历史后的重复升级。测试夹具只跳过 Fund 创建资格，Portfolio 接口使用生产源码，未向正式后端添加测试入口。重复升级使用 --upgrade-unchanged，避免相同 WASM 被跳过。

新增脚本通过 bash 语法检查，生产 WASM、Candid 与生成的夹具通过 SDK 0.30.1 编译；本地实际执行仍在 dfx start 被 Unix socket 权限阻止。新 E2E 的最终结果以新增提交的 GitHub CI 为准，尚不能沿用旧提交的绿色状态。
