using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Flow;

/// <summary>
/// Windows Xray 内核管理器 — 使用 XTLS/Xray-core 官方预编译二进制 xray.exe。
/// 放置 xray.exe 在 xray-core\ 目录下即可。
/// </summary>
public static class XrayCoreManager
{
    private static Process? _process;
    private static string _configPath = "";
    private static int _socksPort = 10606;
    private static int _httpPort = 10607;

    public static bool IsRunning => _process is { HasExited: false };

    public static int SocksPort => _socksPort;
    public static int HttpPort => _httpPort;

    public static string FindXrayExe()
    {
        var candidates = new[]
        {
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "xray-core", "xray.exe"),
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "xray-core", "xray-windows-64.exe"),
            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "xray.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Flow", "xray-core", "xray.exe"),
            "xray.exe"
        };

        foreach (var c in candidates)
            if (File.Exists(c)) return Path.GetFullPath(c);

        return "";
    }

    public static bool Start(string config)
    {
        if (IsRunning) Stop();

        var xrayExe = FindXrayExe();
        if (string.IsNullOrEmpty(xrayExe) || !File.Exists(xrayExe)) return false;

        var configDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Flow", "configs");
        Directory.CreateDirectory(configDir);
        _configPath = Path.Combine(configDir, "config.json");
        File.WriteAllText(_configPath, config, Encoding.UTF8);

        _process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = xrayExe,
                Arguments = $"run -config \"{_configPath}\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                WorkingDirectory = Path.GetDirectoryName(xrayExe)!
            }
        };

        _process.Start();
        _process.BeginOutputReadLine();
        _process.BeginErrorReadLine();

        // Wait for proxy to be ready
        Thread.Sleep(1000);
        return IsRunning;
    }

    public static void Stop()
    {
        try
        {
            if (_process is { HasExited: false })
            {
                _process.Kill(entireProcessTree: true);
                _process.WaitForExit(3000);
            }
        }
        catch { }
        _process?.Dispose();
        _process = null;
    }

    public static Task<int?> TestSocksProxy(int socksPort, int timeoutMs = 6000)
    {
        return Task.Run(() =>
        {
            var testUrls = new[] { "https://www.google.com/generate_204", "https://www.gstatic.com/generate_204", "https://www.cloudflare.com/cdn-cgi/trace" };
            foreach (var url in testUrls)
            {
                try
                {
                    var start = Environment.TickCount;
                    var proxy = new WebProxy($"socks5://127.0.0.1:{socksPort}");
                    var handler = new HttpClientHandler { Proxy = proxy, UseProxy = true };
                    using var http = new HttpClient(handler) { Timeout = TimeSpan.FromMilliseconds(timeoutMs) };
                    var resp = http.GetAsync(url).Result;
                    if (resp.StatusCode is HttpStatusCode.OK or HttpStatusCode.NoContent)
                        return Environment.TickCount - start;
                }
                catch { }
            }
            return null;
        });
    }

    public static int FindAvailablePort(int start)
    {
        var port = start;
        while (port < 65000)
        {
            if (IsPortAvailable(port)) return port;
            port++;
        }
        return start;
    }

    private static bool IsPortAvailable(int port)
    {
        var listeners = IPGlobalProperties.GetIPGlobalProperties().GetActiveTcpListeners();
        foreach (var ep in listeners)
            if (ep.Port == port) return false;
        return true;
    }
}
