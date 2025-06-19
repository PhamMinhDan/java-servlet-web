# Script tự động tải WAR từ GitHub Actions và deploy lên Tomcat

# ==== Load biến môi trường từ file .env ====
Get-Content ".env" | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]*)\s*=\s*(.*)$") {
        $name, $value = $matches[1].Trim(), $matches[2].Trim()
        [System.Environment]::SetEnvironmentVariable($name, $value)
    }
}

# ==== Cấu hình ====
$repoOwner = "PhamMinhDan"
$repoName = "java-servlet-web"
$artifactName = "servlet-war"
$githubToken = $env:GITHUB_TOKEN
$tomcatWebapps = "C:\Program Files\Apache Software Foundation\Tomcat 11.0\webapps"
$tomcatStartup = "C:\Program Files\Apache Software Foundation\Tomcat 11.0\bin\startup.bat"
$warFileName = "java-servlet-web-1.0-SNAPSHOT.war"

# ==== Lấy workflow run mới nhất ====
$headers = @{
    Authorization = "Bearer $githubToken"
    Accept = "application/vnd.github+json"
}
$workflowRuns = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/actions/runs" -Headers $headers
$latestRun = $workflowRuns.workflow_runs | Where-Object { $_.status -eq "completed" -and $_.conclusion -eq "success" } | Select-Object -First 1

if (-not $latestRun) {
    Write-Error "Không tìm thấy workflow run thành công!"
    exit 1
}

# ==== Lấy artifact ====
$artifacts = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/actions/runs/$($latestRun.id)/artifacts" -Headers $headers
$artifact = $artifacts.artifacts | Where-Object { $_.name -eq $artifactName } | Select-Object -First 1

if (-not $artifact) {
    Write-Error "Không tìm thấy artifact $artifactName!"
    exit 1
}

# ==== Tải artifact ====
$artifactUrl = $artifact.archive_download_url
$zipPath = "$env:TEMP\artifact.zip"
Invoke-RestMethod -Uri $artifactUrl -Headers $headers -OutFile $zipPath

# ==== Giải nén artifact ====
$extractPath = "$env:TEMP\artifact"
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$warPath = Join-Path $extractPath $warFileName

if (-not (Test-Path $warPath)) {
    Write-Error "Không tìm thấy file WAR $warFileName trong artifact!"
    exit 1
}

# ==== Dừng Tomcat nếu đang chạy ====
if (Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*Tomcat 11.0*" }) {
    Write-Host "Dừng Tomcat..."
    & "C:\Program Files\Apache Software Foundation\Tomcat 11.0\bin\shutdown.bat"
    Start-Sleep -Seconds 5
}

# ==== Copy WAR vào webapps ====
Write-Host "Copy $warFileName vào $tomcatWebapps..."
Copy-Item -Path $warPath -Destination (Join-Path $tomcatWebapps $warFileName) -Force

# ==== Khởi động Tomcat ====
Write-Host "Khởi động Tomcat..."
Start-Process -FilePath $tomcatStartup

# ==== Kiểm tra ứng dụng ====
Write-Host "Đợi Tomcat khởi động..."
Start-Sleep -Seconds 10
try {
    $status = Invoke-WebRequest -Uri "http://localhost:8089/java-servlet-web-1.0-SNAPSHOT/hello"
    if ($status -and $status.Content -like "*Hello, World, I am a servlet!*") {
        Write-Host "✅ Ứng dụng chạy thành công!"
    } else {
        Write-Warning "⚠️ Không thể truy cập ứng dụng. Kiểm tra Tomcat log."
    }
} catch {
    Write-Warning "⚠️ Không thể kết nối đến ứng dụng."
}

# ==== Dọn dẹp ====
Remove-Item -Path $zipPath, $extractPath -Recurse -Force
