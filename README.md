# TrendRadar 涉外监管与跨境风险情报服务

本目录是独立于原 `TrendRadar` 的第二套服务，面向跨国公司法务、涉外律师和出海企业合规人员。原服务继续负责知识产权、AI与科技产业情报；本服务专门监控：

1. 制裁与出口管制；
2. 外资准入与国家安全审查；
3. 国际贸易与供应链；
4. 国际争端与域外执法。

两套服务使用独立配置、数据目录、容器名称、端口和飞书Webhook，互不读取对方的历史数据。

## 当前运行策略

- 时区：`Asia/Shanghai`。
- 采集：Docker在每小时 `00/30` 分运行，仅采集并落库。
- 日报：每天北京时间08:05生成并推送一次（时间线窗口为08:05—08:35）。
- 统计期间：执行时刻向前24小时；定时执行通常为昨天08:05至今天08:05。
- AI：暂未配置DeepSeek API，当前关闭AI分析，只做关键词筛选与汇总。
- 热榜：关闭，只分析专业RSS，减少社会新闻噪声。
- 启动即运行：关闭，避免部署时误推送。

## 与第一套服务的隔离

| 项目 | 知识产权实例 | 本实例 |
|---|---|---|
| 本地目录 | `TrendRadar-IP-Cousel` | `TrendRadar-Global-Legal` |
| 主容器 | `trendradar` | `trendradar-global` |
| MCP容器 | `trendradar-mcp` | `trendradar-global-mcp` |
| Web端口 | 8080 | 8081 |
| MCP端口 | 3333 | 3334 |
| 数据目录 | 各自的 `output` | 各自的 `output` |
| 飞书群 | 知识产权群 | 新建的涉外法务群 |

## 关键配置文件

- `config/config.yaml`：数据源、滚动24小时统计、报告长度和AI开关。
- `config/frequency_words.txt`：涉外监管关键词与优先级。
- `config/ai_analysis_prompt.txt`：跨国公司涉外风险分析提示词。
- `config/timeline.yaml`：北京时间08:05日报窗口。
- `docker/.env`：飞书、DeepSeek、端口与运行方式。
- `docker/docker-compose.yml`：使用官方镜像部署。
- `docker/docker-compose-build.yml`：需要使用本地代码构建时使用。

## 数据源设计

信息源分为三层：

### 1. 已启用的官方RSS或Atom

- WTO Latest News：国际贸易规则和争端动态。
- Council of the EU Press Releases：欧盟制裁、贸易与安全政策。
- European Data Protection Board News：GDPR、跨境数据和欧洲数据监管。
- UK OFSI News：英国金融制裁执法和指引。
- UK NSI Updates：英国国家安全与投资审查。

### 2. 已启用的解释和地缘政治来源

包括Politico EU、CSIS、CFR、Carnegie、The Diplomat、Foreign Policy和Bloomberg Markets。它们用于判断政策背景和弱信号，不作为“规则已经生效”的唯一依据。

### 3. 已启用的自建网页转RSS源

以下9个订阅已经写入 `config/config.yaml` 并启用：

- 中国出口管制信息网-国内；
- 中国出口管制信息网-国际；
- 商务部政策发布；
- 商务部贸易救济调查局-贸易摩擦应对；
- 商务部贸易救济调查局-贸易救济调查；
- 国家发展改革委政策发布；
- 国家网信办数据治理政策法规；
- 市场监管总局反垄断执法-案件公示；
- 美国OFAC Recent Actions。

至此，本实例共有25个已启用订阅源：5个官方原生RSS或Atom、9个自建官方网页转RSS源、11个政策解释和地缘政治源。

### 4. 尚待网页转RSS的官方来源

以下9个来源已经作为占位项写入 `config/config.yaml`，当前保持 `enabled: false`：

- 美国BIS Federal Register Notices；
- 美国CFIUS；
- 美国DOJ FCPA Enforcement Actions；
- 欧盟Investment Screening；
- EUR-Lex个性化检索订阅；
- UK Sanctions List；
- ICSID案件数据库；
- UNCITRAL Transparency Registry；
- PCA案件库。

使用你的网页转RSS服务生成地址后，找到对应条目：

```yaml
- id: "us-bis-federal-register"
  name: "US BIS Federal Register Notices"
  url: "替换为转换后的RSS地址"
  enabled: true
```

不要直接把普通HTML地址设为启用状态。OFAC等清单类页面还应尽量生成“新增、修改、删除”都能体现的RSS，而不只是抓取页面标题。

EUR-Lex建议分别建立保存检索并生成RSS，不要只建立一个全站源。首批检索主题建议为：

- restrictive measures / sanctions；
- dual-use / export control；
- foreign direct investment screening；
- data transfer / GDPR；
- competition / merger control；
- artificial intelligence。

## 飞书与DeepSeek配置

打开 `docker/.env`：

```dotenv
FEISHU_WEBHOOK_URL=https://open.feishu.cn/open-apis/bot/v2/hook/新群机器人地址
AI_ANALYSIS_ENABLED=false
AI_API_KEY=你的DeepSeek_API_Key
AI_MODEL=deepseek/deepseek-v4-flash
AI_API_BASE=https://api.deepseek.com
CRON_SCHEDULE=*/30 * * * *
REPORT_CRON_SCHEDULE=5 8 * * *
```

容器会生成两条独立任务：`--collect-only` 在整点和半点采集，`--report-only` 在08:05读取已存储数据并推送。报告任务本身不再采集；手动以 `RUN_MODE=once` 完整执行时，仍会先采集并按实际执行时刻向前汇总24小时。

复制目录时保留了DeepSeek模型名称和接口地址，但当前API Key及新飞书Webhook均为空。部署前必须分别填写。

请勿把 `docker/.env` 提交到公开Git仓库或发送给他人。

## 在VPS上部署

建议上传到：

```text
/opt/trendradar-global
```

上传完成后，在VPS执行：

```bash
cd /opt/trendradar-global/docker
docker compose config
docker compose up -d
docker compose ps
docker compose logs --tail=100 trendradar
```

本实例使用：

```text
Web: 127.0.0.1:8081
MCP: 127.0.0.1:3334
```

如无需MCP服务，可以只启动主服务：

```bash
docker compose up -d trendradar
```

停止或更新本实例时，应当在本目录的 `docker` 文件夹中运行Docker Compose命令，不要在第一套实例目录执行。

## 部署前检查

1. 新飞书群机器人Webhook已经填写。
2. 当前无需 DeepSeek API Key；启用AI前再核对Key、模型名称和账户支持情况。
3. `docker compose config`没有YAML错误。
4. 8081和3334没有被VPS其他服务占用。
5. 所有网页转换RSS均能返回合法XML，并至少包含标题、链接和发布日期。
6. VPS系统时间和容器时区均为 `Asia/Shanghai`。
7. 首次运行建议先保持 `IMMEDIATE_RUN=false`，观察一次采集日志后再等待日报窗口。

## 风险边界

本服务生成的是公开信息筛查和内部研究线索，不代替针对具体交易、主体和法域的正式法律意见。制裁和出口管制事项必须进一步核验正式清单、主体别名、所有权或控制关系、物项分类、最终用途、许可证和规则生效时间。

当前服务生成每日汇总，不等于实时名单筛查。对于OFAC、BIS、英国和欧盟制裁清单等高时效事项，后续宜另设即时预警流程。
