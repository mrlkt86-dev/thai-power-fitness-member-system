# MyMemberHub 2.0 — Thai Power Fitness

这是一个**手机网页系统的起步版本**，采用 Supabase 云端数据库与账号登录。它不是已经上线的网站：需要先建立 Supabase 项目、执行 SQL、填入项目连接资料，再部署网页。

## 已规划／原型内含
- 老板与员工登录
- 老板：新增会员、确认收款、停用／启用会员
- 员工：查看会员、登记签到
- 会员总览：会员总数、有效、30天内到期、已过期
- 配套：月费、3个月、6个月、12堂私人课
- 签到记录及剩余堂数
- 手机响应式页面，可加入手机主屏幕

## 重要：当前版本的边界
- 这是一份可继续开发的 starter，不是已部署服务。
- 云端同步要在 Supabase 项目建立并填入 `index.html` 的 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 后才会工作。
- 不要把 Supabase `service_role` key 放进网页。
- 目前续费／付款只是记录收款，尚未自动延长会员期限；正式上线前应把续费流程、配套价格、优惠及付款收据规则再确认。
- 目前签到 trigger 及权限应先在测试项目验证，正式使用前建议加上更严格的数据库测试。
- 不会读取、覆盖或迁移旧版 MyMemberHub 数据。

## 设置步骤
1. 到 https://supabase.com 建立一个新项目，记下 Project URL 与 anon/public key。
2. 打开 Supabase 的 SQL Editor，把 `supabase_schema.sql` 全部执行。
3. 在 Authentication > Users 建立老板账号。复制该用户的 UUID。
4. 在 SQL Editor 执行以下语句，把 UUID 换成老板账号的真实 UUID：
   ```sql
   insert into public.profiles(id, display_name, role)
   values ('AUTH_USER_UUID_HERE', 'Thai Power Fitness Owner', 'owner');
   ```
5. 建立 1–3 个员工账号，并为每个员工 UUID 建立 profile：
   ```sql
   insert into public.profiles(id, display_name, role)
   values ('STAFF_AUTH_USER_UUID', 'Coach Name', 'staff');
   ```
6. 编辑 `index.html` 顶部的 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`。
7. 将整个文件夹部署到 HTTPS 静态网站托管服务（例如 Cloudflare Pages / Netlify）；部署后用手机打开网址并添加到主屏幕。
8. 用老板账号和员工账号分别测试权限：员工不应能新增会员、确认付款或修改资料。

## 下一步上线前必须完成
- 付款确认时自动按配套延长到期日，并记录付款方式／收据编号。
- 续费历史、会员编辑、删除保护、数据导出与备份。
- PWA 图标、离线提示、登录会话管理。
- 对数据库权限和签到并发进行测试。
