# Logic Lab — UI/UX Review

基于 ui-ux-pro-max 设计规范的界面审查与优化建议。

## 已完成的优化

### 1. 无障碍性 (Accessibility)
- **Caption 字号**：11px → 12px，符合 WCAG 最小可读字号建议
- **字体缩放**：已支持 `MediaQuery.textScaler`（设置中的字号调节）

### 2. 交互反馈 (Interaction)
- **Game Card**：使用 `InkWell` 替代 `GestureDetector`，增加点击时的水波纹与高亮反馈
- **触摸间距**：游戏卡片间距 12px，满足「相邻可点击元素至少 8px 间距」的规范

### 3. 间距规范 (Spacing)
- 新增 `lib/core/constants/app_spacing.dart`，定义 8px 基准网格
- 建议后续统一使用：xs(4), sm(8), md(12), lg(16), xl(20), xxl(24), xxxl(32), huge(40), hero(48)

## 当前设计系统

### 色彩
- **背景**：深色 (#0A0A12) + 金色强调
- **文字**：主色 #F5F5F5，次要 #9E9E9E，禁用 #5A5A6A
- **对比度**：深色背景 + 浅色文字，符合可读性要求

### 字体
- **Cairo**：支持阿拉伯语与拉丁字符，适合多语言
- **层级**：displayLarge(56) > displayMedium(40) > headingLarge(24) > headingMedium(20) > body(14–16) > caption(12)

### 间距现状
| 位置 | 当前值 | 建议 |
|------|--------|------|
| 屏幕水平边距 | 20px | 保持 (xl) |
| 卡片内边距 | 16px | ✓ 已统一 |
| 卡片间距 | 12px | ✓ 符合规范 |
| 底部留白 | 40px | 保持 (huge) |

## 建议的后续优化

1. **LqHero / 雷达图**：若恢复首页 LQ 展示，建议 padding 14→16 对齐 8px 网格
2. **过渡动画**：关键操作可增加 150–300ms 的 `AnimatedContainer` 或 `AnimatedOpacity`
3. **焦点状态**：确保 `FocusNode` 与键盘导航有可见焦点样式
4. **prefers-reduced-motion**：可考虑在系统开启时减少或关闭动画

## Pre-Delivery 检查清单

- [x] 无 emoji 作为图标（使用 Material Icons）
- [x] 可点击元素有视觉反馈（InkWell）
- [x] 深色模式文字对比度充足
- [x] 触摸目标间距 ≥ 8px
- [ ] 响应式：建议在 375px、414px、768px 下验证布局
