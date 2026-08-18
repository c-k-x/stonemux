import Foundation

// stonemux-ctl：stonemux 控制面客户端。
// 读 ~/.stonemux/ctl.json（socket_path + token）→ Unix socket 一行往返 → 打印结果。
// 退出码 0=成功，1=失败。

func die(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("error: \(msg)\n".utf8))
    exit(1)
}

func usage() -> Never {
    print("""
    usage:
      stonemux-ctl sessions
      stonemux-ctl open <url> [--session <id>]
      stonemux-ctl navigate <url> [--panel <id>]
      stonemux-ctl back|forward|reload [--panel <id>]
      stonemux-ctl url|title [--panel <id>]
      stonemux-ctl eval <js> [--panel <id>]
      stonemux-ctl snapshot [--panel <id>]
      stonemux-ctl click <selector> [--panel <id>]
      stonemux-ctl type <selector> <text> [--panel <id>]
      stonemux-ctl send <to> [--subject <s>] [--body <b>] [--from <id>]
      stonemux-ctl inbox [--session <id>]
      stonemux-ctl reply <id> [--body <b>] [--from <id>]
      stonemux-ctl ack <id> <delivered|read>
    """)
    exit(1)
}

// ---- 参数解析：positional + 具名 flag ----
var args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else { usage() }

var panel: String?
var session: String?
var subject = ""
var body = ""
// 终端内的 shell 自带 STONEMUX_SESSION_ID（app 注入），作为默认身份
var from: String? = ProcessInfo.processInfo.environment["STONEMUX_SESSION_ID"]
var positional: [String] = []
var i = 0
while i < args.count {
    switch args[i] {
    case "--panel":
        i += 1
        panel = i < args.count ? args[i] : nil
    case "--session":
        i += 1
        session = i < args.count ? args[i] : nil
    case "--subject":
        i += 1
        subject = i < args.count ? args[i] : ""
    case "--body":
        i += 1
        body = i < args.count ? args[i] : ""
    case "--from":
        i += 1
        from = i < args.count ? args[i] : nil
    default:
        positional.append(args[i])
    }
    i += 1
}
guard let verb = positional.first else { usage() }

let command: ControlCommand
switch verb {
case "sessions":
    command = .sessions
case "open":
    guard positional.count >= 2 else { usage() }
    command = .open(url: positional[1], session: session)
case "navigate":
    guard positional.count >= 2 else { usage() }
    command = .navigate(url: positional[1], panel: panel)
case "back":
    command = .back(panel: panel)
case "forward":
    command = .forward(panel: panel)
case "reload":
    command = .reload(panel: panel)
case "url":
    command = .url(panel: panel)
case "title":
    command = .title(panel: panel)
case "eval":
    guard positional.count >= 2 else { usage() }
    command = .eval(js: positional[1], panel: panel)
case "snapshot":
    command = .snapshot(panel: panel)
case "click":
    guard positional.count >= 2 else { usage() }
    command = .click(selector: positional[1], panel: panel)
case "type":
    guard positional.count >= 3 else { usage() }
    command = .type(selector: positional[1], text: positional[2], panel: panel)
case "send":
    guard positional.count >= 2 else { usage() }
    command = .send(from: from, to: positional[1], subject: subject, body: body)
case "inbox":
    command = .inbox(session: session)
case "reply":
    guard positional.count >= 2 else { usage() }
    command = .reply(id: positional[1], from: from, body: body)
case "ack":
    guard positional.count >= 3 else { usage() }
    command = .ack(id: positional[1], status: positional[2])
default:
    usage()
}

// ---- 读凭据 ----
let ctlPath = (NSHomeDirectory() as NSString).appendingPathComponent(".stonemux/ctl.json")
guard let data = FileManager.default.contents(atPath: ctlPath),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
      let socketPath = json["socket_path"],
      let token = json["token"] else {
    die("无法读取 \(ctlPath)（stonemux 是否在跑？）")
}

// ---- 连接 Unix socket ----
let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { die("socket 创建失败") }
defer { close(fd) }

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
    let buf = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
    strcpy(buf, socketPath)
}
let connected = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
        connect(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}
guard connected == 0 else { die("连接 \(socketPath) 失败（stonemux 是否在跑？）") }

// ---- 一行往返 ----
var line = (try? JSONEncoder().encode(ControlRequest(token: token, command: command))) ?? Data()
line.append(contentsOf: "\n".utf8)
line.withUnsafeBytes { raw in
    _ = write(fd, raw.baseAddress, raw.count)
}

var received = Data()
var buf = [UInt8](repeating: 0, count: 65536)
while !received.contains(UInt8(ascii: "\n")) {
    let n = read(fd, &buf, buf.count)
    if n <= 0 { break }
    received.append(contentsOf: buf[0..<n])
}
guard let nl = received.firstIndex(of: UInt8(ascii: "\n")) else {
    die("无响应")
}
let respData = received[received.startIndex..<nl]
guard let resp = try? JSONDecoder().decode(ControlResponse.self, from: Data(respData)) else {
    die("响应解析失败")
}

if resp.ok {
    if let result = resp.result, !result.isEmpty {
        print(result)
    }
    exit(0)
} else {
    die(resp.error ?? "unknown error")
}
