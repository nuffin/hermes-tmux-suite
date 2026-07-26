[English](README.md) | [中文](README.zh.md)

# Hermes Tmux Suite

为 [Hermes Agent](https://github.com/NousResearch/hermes-agent) 提供 tmux 集成的 skill 操作。

## 功能

派发 `delegate_task` 子代理，同时在专用 tmux pane 中实时 tail 其操作日志 — 不占用你的工作 pane，就能看到每一步执行过程。

## Skills

| Skill | 说明 |
|-------|------|
| `tmux-delegate-task` | 派发子代理 + tmux pane 实时 tail 日志 + 自动清理 |
| `tmux-socket` | 检测当前 tmux socket，提供正确的 `-L`/`-S` 参数 |

## 安装

```bash
git clone https://github.com/nuffin/hermes-tmux-suite.git
cd hermes-tmux-suite
./install.sh              # 复制到 ~/.hermes/skills/devops/
./install.sh --symlink    # 开发模式，创建符号链接
```

或通过 pip：

```bash
pip install hermes-tmux-suite
```

在 `config.yaml` 中加入 skill-graph 源目录：

```yaml
skills:
  config:
    skill-graph:
      source_dirs:
        - ~/.hermes/skills/devops/
```

## 用法

在 Hermes 中：

```
> 在当前窗口用 tmux-delegate-task 跑 code review
```

执行流程：
1. 派发 `delegate_task` 执行你的任务
2. 在当前窗口自动 split 一个 tmux pane，tail 子代理的实时日志
3. 任务完成后自动关闭 pane（除非你说 `--keep`）

## Pane/窗口默认值

| 你说... | session | window | pane |
|------------|---------|--------|------|
| (不指定) | 当前 | 当前 | split 新 pane |
| "infra session" | infra | 新建窗口 | pane 0 |
| "infra session, hermes 窗口" | infra | hermes | split 新 pane |
| "infra session, hermes 窗口, pane 3" | infra | hermes | .3（永不关闭） |

## 仓库

| 角色 | 仓库 | PyPI |
|------|------|------|
| Skill 代码（本仓库） | [hermes-tmux-suite](https://github.com/nuffin/hermes-tmux-suite) | — |
| Pip 封装 | [hermes-tmux-suite-pip](https://github.com/nuffin/hermes-tmux-suite-pip) | [hermes-tmux-suite](https://pypi.org/project/hermes-tmux-suite/) |
