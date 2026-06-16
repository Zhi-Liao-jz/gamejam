# 快速创建分支脚本 (Windows PowerShell 版本)
# 创建格式为 {用户名缩写}{日期缩写}-{分支内容} 的分支

param(
    [string]$BranchSuffix = "dev",
    [switch]$Local,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# 获取脚本所在目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Join-Path $scriptDir "..\" | Resolve-Path
$configFile = Join-Path $projectRoot ".branch-user"
$hasChanges = $false

function Show-Help {
    Write-Host "快速创建分支脚本"
    Write-Host ""
    Write-Host "用法:"
    Write-Host "  .\new-branch.ps1 [选项] [分支后缀]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -Local            在当前分支上创建新分支 (不切换到 main、不检查工作区状态)"
    Write-Host "  -Help             显示此帮助信息"
    Write-Host ""
    Write-Host "参数:"
    Write-Host "  分支后缀          分支名称的后缀部分（默认: dev）"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\new-branch.ps1              # 创建 xxx61k-dev 格式的分支"
    Write-Host "  .\new-branch.ps1 feature      # 创建 xxx61k-feature 格式的分支"
    Write-Host "  .\new-branch.ps1 fix-bug      # 创建 xxx61k-fix-bug 格式的分支"
    Write-Host ""
    Write-Host "说明:"
    Write-Host "  - 首次运行时会提示输入 3 位用户名缩写（保存在 .branch-user 文件中）"
    Write-Host "  - 自动切换到 main 分支并拉取最新代码"
    Write-Host "  - 如果分支名已存在，会自动添加数字后缀（如 xxx61k-dev2）"
    Write-Host "  - 未提交的更改会自动暂存并在新分支创建后恢复"
    Write-Host ""
    exit 0
}

if ($Help) {
    Show-Help
}

Write-Host "========================================"
Write-Host "  快速创建分支"
Write-Host "========================================"
Write-Host ""

# 1. 获取用户名缩写
Write-Host "[1/5] 获取用户名缩写..."

if (Test-Path $configFile) {
    $username = Get-Content $configFile -Raw
    $username = $username.Trim()
    Write-Host "[INFO] 用户名缩写: $username"
} else {
    Write-Host "[INFO] 首次使用，请输入你的 3 位用户名缩写（纯小写字母）:"
    $username = Read-Host
    $username = $username.ToLower().Trim()

    # 验证格式
    if ($username -notmatch '^[a-z]{3}$') {
        Write-Host "[ERROR] 用户名缩写必须是 3 位纯小写字母" -ForegroundColor Red
        exit 1
    }

    $username | Out-File -FilePath $configFile -Encoding utf8 -NoNewline
    Write-Host "[SUCCESS] 用户名已保存到 .branch-user" -ForegroundColor Green
}

# 2. 切换到 main 分支（可选）
Set-Location $projectRoot

if ($Local) {
    Write-Host "[2/5] 本地模式: 在当前分支上创建新分支"
} else {
    Write-Host "[2/5] 切换到 main 分支..."

    # 检查是否有未提交的更改
    git diff --quiet 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $hasChanges = $true
        Write-Host "[INFO] 检测到未提交的更改，暂存中..."
        git stash push -m "new-branch-script-auto-stash"
    }

    # 获取当前分支
    $currentBranch = git branch --show-current

    # 切换到 main 分支
    if ($currentBranch -ne "main") {
        Write-Host "[INFO] 从 $currentBranch 切换到 main..."
        git checkout main
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] 无法切换到 main 分支" -ForegroundColor Red
            if ($hasChanges) { git stash pop }
            exit 1
        }
    }

    # 拉取最新代码
    Write-Host "[INFO] 拉取最新代码..."
    git pull
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] 拉取 main 分支失败" -ForegroundColor Red
        if ($hasChanges) { git stash pop }
        exit 1
    }

    # 更新远程分支列表
    Write-Host "[INFO] 更新远程分支列表..."
    git fetch origin --prune

    Write-Host "[SUCCESS] 已切换到 main 分支并拉取最新代码" -ForegroundColor Green
}

# 3. 获取日期缩写
Write-Host "[3/5] 获取日期缩写..."

$now = Get-Date
$year = $now.Year % 10
$month = $now.Month
$day = $now.Day

# 月份映射: 1-9用1-9, 10用a, 11用b, 12用c
$monthChar = if ($month -le 9) { $month.ToString() }
             elseif ($month -eq 10) { "a" }
             elseif ($month -eq 11) { "b" }
             else { "c" }

# 日期映射: 1-9用1-9, 10-35用a-z
$dayChar = if ($day -le 9) { $day.ToString() }
           else { [char](97 + $day - 10) }

$dateShort = "$year$monthChar$dayChar"
Write-Host "[INFO] 日期缩写: $dateShort"

# 4. 生成分支名
Write-Host "[4/5] 生成分支名..."

$baseBranchName = "$username$dateShort-$BranchSuffix"
$branchName = $baseBranchName
$counter = 2

# 检查分支名是否已存在
while ($true) {
    $localExists = git branch -a | Select-String -Pattern "^\s+$branchName$" -Quiet
    $remoteExists = git branch -a | Select-String -Pattern "^\s+remotes/origin/$branchName$" -Quiet

    if (-not $localExists -and -not $remoteExists) {
        break
    }

    $branchName = "$baseBranchName$counter"
    $counter++
}

Write-Host "[INFO] 分支名: $branchName"

# 5. 创建分支
Write-Host "[5/5] 创建分支..."

git checkout -b $branchName
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] 创建分支失败" -ForegroundColor Red
    if ($hasChanges) { git stash pop }
    exit 1
}

Write-Host "[SUCCESS] 分支创建成功: $branchName" -ForegroundColor Green

# 恢复之前暂存的更改
if ($hasChanges) {
    Write-Host "[INFO] 正在恢复暂存的更改..."
    git stash pop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] 恢复暂存的更改时出现冲突，请手动解决" -ForegroundColor Yellow
        Write-Host "[INFO] 使用 'git stash show' 查看暂存内容"
    } else {
        Write-Host "[SUCCESS] 已恢复之前的未提交更改" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "[SUCCESS] 完成" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "当前分支: $branchName"
Write-Host ""
