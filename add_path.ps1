$oldPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($oldPath -notmatch 'D:\\android-sdk\\cmdline-tools\\latest\\bin') {
    $newPath = $oldPath + ';D:\android-sdk\cmdline-tools\latest\bin'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host 'Path updated successfully.'
} else {
    Write-Host 'Path already contains D:\android-sdk\cmdline-tools\latest\bin'
}
