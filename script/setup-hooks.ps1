# 启用本仓库的 Git 提交检查钩子（每个克隆只需运行一次）
# 用法：在仓库根目录运行  .\script\setup-hooks.ps1

git config core.hooksPath script/hooks
Write-Host "✅ 已启用提交检查 (core.hooksPath = script/hooks)"
Write-Host "   今后每次 git commit 会自动对暂存的 .gd 文件做格式 + 静态检查。"
Write-Host ""
Write-Host "若未安装检查工具，请先执行：pip install `"gdtoolkit==4.*`""
