@echo off
echo === Flow Windows 一键发布 ===
echo.
echo 1. 安装 .NET 8 SDK (如果还没装):
echo    https://dotnet.microsoft.com/download/dotnet/8.0
echo.
echo 2. 运行本脚本即自动编译并打包
echo.
cd /d "%~dp0Flow"
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish
echo.
echo === 打包完成 ===
echo 绿色版路径: publish\Flow.exe
echo 将整个 publish 文件夹复制到任意 Windows 电脑即可运行
pause
