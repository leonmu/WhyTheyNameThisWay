# Why They Name This Way

A World of Warcraft addon for **learning English while you play**. Hover over a monster, NPC, item or object, or walk into a new zone, and it explains the English words in the name: what they mean, where they come from, and an example sentence.

*Mangy Wolf* → **Mangy**: with patchy, dirty fur. *Thousand Needles* → a canyon full of tall, thin rock pillars like needles. *Lucifron* → sounds like Lucifer, a name for the Devil.

Built for **WoW Forever** (client 1.60.x). It may also load on other modern clients, but it is only tested there.

[中文说明见下方](#中文说明)

## Features

- **Hints in tooltips and in a window** that keeps the last explanation on screen (drag to move, corner to resize, padlock to lock).
- **About 8,300 explanations** for words in NPC, item, object and place names, with word origins and example sentences.
- **Difficulty levels**: hide everyday words (wolf, sword) or intermediate words (dagger, swamp) so only the words you don't know yet are shown.
- **Hide single hints** with the ✕ button once you've learned them.
- **Zones and sub-zones** are explained when you enter them.
- **Optional Chinese explanation (中文解释)**, off by default: click **ZH** in the window title bar.
- **Works on a Chinese game client too**: NPC, item and zone names are mapped back to English by game ID, then explained.

## Install

1. Download `WhyTheyNameThisWay-<version>.zip` from the [latest release](https://github.com/leonmu/WhyTheyNameThisWay/releases/latest).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns\` (you should end up with `AddOns\WhyTheyNameThisWay\WhyTheyNameThisWay.toc`).
3. Start (or fully restart) the game. If the addon shows as *out of date*, tick **Load out of date AddOns**.

(If you use **Code → Download ZIP** instead, rename the unzipped folder from `WhyTheyNameThisWay-main` to `WhyTheyNameThisWay`.)

## Commands

| Command | What it does |
|---|---|
| `/why` | Show or hide the window |
| `/why level 0` / `1` / `2` | Show all words / hide Basic / hide Basic + Intermediate |
| `/why zh` | Chinese explanation on/off |
| `/why font 14` | Window text size (8–24) |
| `/why lock`, `/why unlock` | Stop/allow moving and resizing |
| `/why reset` | Reset window position and size |
| `/why hidden`, `/why unhide <word>` / `all` | List or restore hints you hid |
| `/why zone` | Explain new places when you arrive (on/off) |
| `/why tooltip` | Notes in tooltips (on/off) |
| `/why check` | Target a monster to see why it does or doesn't get a hint |
| `/why debug` | Print diagnostic messages |

Settings are also in **Options → AddOns → Why They Name This Way**.

## Editing the dictionary

- `Data.lua` and `DataForever.lua`: English entries, `E(...)` / `W(level, key, meaning, roots, example)`.
- `Levels.lua`: which words count as Basic or Intermediate.
- `DataZH.lua`: Chinese explanations, `Z(key, text)`.

## Notes and credits

- Most explanations were written with AI assistance and checked by script for format, not by a human for every line. They may contain mistakes; corrections are welcome as issues or pull requests.
- The lists of game names used to choose words, and the ID-to-name tables in `Names.lua` and `NamesZH.lua`, are derived from [QuestieDB](https://github.com/Questie/QuestieDB), used under the GPL-3.0 terms its maintainers allow.
- World of Warcraft and Warcraft are trademarks of Blizzard Entertainment, Inc. This project is not affiliated with or endorsed by Blizzard Entertainment.

## License

[GPL-3.0](LICENSE)

---

## 中文说明

**Why They Name This Way（为什么这样命名）** 是一个帮你**边玩魔兽边学英语**的插件。鼠标指向怪物、NPC、物品或物体，或者进入新区域时，它会解释名字里英文单词的意思、词源，并给出例句。

适用于 **魔兽世界：永恒（WoW Forever，1.60.x 客户端）**。

### 功能

- 提示显示在**鼠标提示**和一个**常驻窗口**里（可拖动、可调整大小、可锁定）。
- 约 **8,300 条解释**，涵盖 NPC、物品、物体和地名中的英文单词。
- **难度等级**：可以隐藏常见词或中级词，只显示你还不认识的词。
- 学会的提示可以点 **✕** 隐藏。
- 进入新区域或子区域时自动解释地名。
- **中文解释（默认关闭）**：点窗口标题栏的 **ZH** 按钮，或输入 `/why zh` 开启。
- **中文客户端也能用**：插件会通过游戏 ID 把中文名称对应回英文名称再解释。

### 安装

1. 从[最新版本（Releases）](https://github.com/leonmu/WhyTheyNameThisWay/releases/latest)下载 `WhyTheyNameThisWay-<版本号>.zip`。
2. 解压到 `World of Warcraft\_forever_\Interface\AddOns\`（最终应为 `AddOns\WhyTheyNameThisWay\WhyTheyNameThisWay.toc`）。
3. 启动（或完全重启）游戏。如果插件显示「过期」，勾选「载入过期插件」。

### 常用命令

`/why` 显示/隐藏窗口 · `/why zh` 中文解释开关 · `/why level 0/1/2` 难度等级 · `/why font 14` 字体大小 · `/why check` 查看某个怪物为什么有或没有提示。

### 说明

大部分解释由 AI 辅助编写，可能有错误，欢迎通过 Issue 或 Pull Request 指正。游戏名称数据来自 [QuestieDB](https://github.com/Questie/QuestieDB)（GPL-3.0）。魔兽世界是暴雪娱乐的商标，本项目与暴雪无关。

许可证：[GPL-3.0](LICENSE)
