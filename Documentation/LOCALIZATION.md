# 四语显示

LCD菜单、现代页面、设置、备份、连接提示、开发面板和游戏错误在显示时选择简体中文、繁体中文、英文或日文。角色名称优先使用角色资料中的四语名称，不改动角色ID、文件格式或旧日志。

`translations.json`包含显示模板与译文；`GameLocalization`匹配插值模板，再替换角色名、道具ID和数值。旧存档中的中文日志可在读取时翻译，不需要重写存档。日期、系统选择器等同时设置对应Locale；系统权限提示提供四份InfoPlist.strings。语言选择项使用各语言自称，方便切换回来。

`Scripts/Data/localization-overrides.json`保存人工调整的常用术语与原版名称；执行`Scripts/apply_localization_overrides.py`应用，`Scripts/validate_localization.py`校验完整语言列、重复键和全部插值参数。新增界面文字须同步加入目录，未知系统错误保留原始系统描述。

长篇说明的初稿经机器翻译后校验插值，尚需母语者审校语气和地区译名；不将翻译覆盖率当成语言质量认证。正式中文、英文、日文字体按设置切换，字体许可见FONT_CREDITS.md。
