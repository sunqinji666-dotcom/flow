using Newtonsoft.Json;

namespace Flow;

public class FlowNodeEnvelope
{
    [JsonProperty("version")] public int? Version { get; set; }
    [JsonProperty("updatedAt")] public string? UpdatedAt { get; set; }
    [JsonProperty("nodes")] public FlowNode[] Nodes { get; set; } = Array.Empty<FlowNode>();
}

public class FlowNode
{
    [JsonProperty("flag")] public string Flag { get; set; } = "\ud83c\udf10";
    [JsonProperty("name")] public string Name { get; set; } = "";
    [JsonProperty("host")] public string Host { get; set; } = "";
    [JsonProperty("port")] public int Port { get; set; } = 443;
    [JsonProperty("protocolType")] public string ProtocolType { get; set; } = "vless";
    [JsonProperty("uuid")] public string Uuid { get; set; } = "";
    [JsonProperty("flow")] public string? Flow { get; set; }
    [JsonProperty("sni")] public string Sni { get; set; } = "";
    [JsonProperty("fingerprint")] public string Fingerprint { get; set; } = "chrome";
    [JsonProperty("publicKey")] public string? PublicKey { get; set; }
    [JsonProperty("shortId")] public string? ShortId { get; set; }
    [JsonProperty("spiderX")] public string? SpiderX { get; set; }
    [JsonProperty("transport")] public string? Transport { get; set; }
    [JsonProperty("security")] public string? Security { get; set; }
    [JsonProperty("rawLink")] public string? RawLink { get; set; }
    [JsonProperty("latency")] public int? Latency { get; set; }

    public string ProtocolDisplay => ProtocolType.ToLowerInvariant() switch
    {
        "vless" => "VLESS",
        "vmess" => "VMess",
        "hysteria" or "hysteria2" => "Hysteria2",
        "trojan" => "Trojan",
        "shadowsocks" => "SS",
        _ => ProtocolType.ToUpperInvariant()
    };

    public string TransportDisplay => (Transport ?? "").ToLowerInvariant() switch
    {
        "grpc" => "gRPC",
        "hysteria" => "UDP",
        "tcp" => "TCP",
        "ws" => "WS",
        "" => (Security ?? "AUTO").ToUpperInvariant(),
        _ => (Transport ?? "").ToUpperInvariant()
    };

    public string LatencyDisplay => Latency switch
    {
        null => "—",
        >= 500 => $"{Latency.Value / 1000.0:F1}s",
        _ => $"{Latency}ms"
    };

    public static FlowNode[] Builtin => new[]
    {
        new FlowNode
        {
            Flag = "\ud83c\udf10",
            Name = "443-dtfnwuzy",
            Host = "example.com", Port = 443, ProtocolType = "vless",
            Uuid = "00000000-0000-0000-0000-000000000000",
            Flow = "xtls-rprx-vision", Sni = "www.amd.com", Fingerprint = "chrome",
            PublicKey = "REPLACE_WITH_PRIVATE_REALITY_PUBLIC_KEY",
            ShortId = "24", SpiderX = "/", Transport = "tcp", Security = "reality", Latency = 95
        }
    };
}
