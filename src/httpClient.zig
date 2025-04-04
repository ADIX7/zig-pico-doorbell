const std = @import("std");
const cNet = @cImport({
    @cInclude("pico/cyw43_arch.h");
    @cInclude("lwip/init.h");
    @cInclude("lwip/tcp.h");
    @cInclude("lwip/dns.h");
});

fn print(text: []const u8) void {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const c_text = allocator.alloc(u8, text.len + 1) catch unreachable;
    allocator.free(c_text);

    for (0..text.len) |i| {
        c_text[i] = text[i];
    }
    c_text[c_text.len - 1] = 0;

    _ = cNet.printf(c_text.ptr);
    _ = cNet.printf("\r\n");
}

fn print_usize(num: usize) void {
    _ = cNet.printf("%d", num);
    _ = cNet.printf("\r\n");
}

pub const HTTP_METHOD = enum {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,
};
pub const HttpRequest = struct {
    url: std.Uri,
    method: HTTP_METHOD,
    body: []const u8,
    headers: []const HttpHeader,
};

pub const HttpResponse = struct {};

pub const HttpHeader = struct {
    name: []const u8,
    value: []const u8,
};

pub const HttpContext = struct { client: *const Client, request: *const HttpRequest, response: ?*const HttpResponse = null, finished: bool = false };

fn tcp_recv_callback(context: ?*anyopaque, pcb: ?*cNet.tcp_pcb, p1: ?*cNet.pbuf, _: cNet.err_t) callconv(.C) cNet.err_t {
    print("asd2");
    if (p1 == null) {
        print("asd3");
        _ = cNet.tcp_close(pcb);
        return cNet.ERR_OK;
    }
    defer {
        _ = cNet.pbuf_free(p1);
    }
    print("asd4");
    const http_context: *HttpContext = @ptrCast(@alignCast(context));
    const response = http_context.client.allocator.create(HttpResponse) catch unreachable;
    http_context.response = response;
    http_context.finished = true;
    // std.debug.print("Received data: {s}\n", .{@ptrCast([*]const u8, p1.?.payload)});
    return cNet.ERR_OK;
}

fn send_http_request(pcb: ?*cNet.tcp_pcb, context: *HttpContext) !void {
    print("Preparing request");
    print_usize(@intFromPtr(context));
    // const request = "POST /todo-channel-name HTTP/1.1\r\nHost: ntfy.sh\r\nTitle: Csengo\r\nContent-Length: 6\r\n\r\nCsengo";
    print("Getting request");
    if (context.request.url.host != null) {
        print("HOST");
    } else {
        print("NOT HOST");
    }
    const host = if (context.request.url.host) |host| host else unreachable;
    const host_string = switch (host) {
        .raw => |v| v,
        .percent_encoded => |v| v,
    };
    print("Got host");
    print(host_string);
    print("Getting path");
    const path_string = switch (context.request.url.path) {
        .raw => |v| v,
        .percent_encoded => |v| v,
    };
    print("Got path");
    print(path_string);

    const request_data = .{ @tagName(context.request.method), path_string, host_string, context.request.body.len, context.request.body };

    // const raw_request = try std.fmt.allocPrint(context.client.allocator, "{} {} HTTP/1.1\r\nHost: {}\r\nContent-Length: {}\r\n\r\n{}", request_data);
    const raw_request = try std.fmt.allocPrint(context.client.allocator, "{s} {s} HTTP/1.1\r\nHost: {s}\r\nTitle: Csengo\r\nContent-Length: {}\r\n\r\n{s}", request_data);
    print("Sending request");
    print(raw_request);

    defer context.client.allocator.free(raw_request);

    _ = cNet.tcp_write(pcb, raw_request.ptr, @intCast(raw_request.len), cNet.TCP_WRITE_FLAG_COPY);
    _ = cNet.tcp_output(pcb);
}
fn tcp_connected_callback(context: ?*anyopaque, pcb: ?*cNet.tcp_pcb, err: cNet.err_t) callconv(.C) cNet.err_t {
    print("tcp_connected_callback");
    print_usize(@intFromPtr(context.?));
    print(if (err != cNet.ERR_OK) "not ok" else "ok");
    if (err != cNet.ERR_OK) {
        return err;
    }
    // std.debug.print("Connected to server\n", .{});
    print("Connected to server");
    _ = cNet.tcp_recv(pcb, tcp_recv_callback);
    // TODO: handle this error
    print("asd1");
    const http_context: *HttpContext = @ptrCast(@alignCast(context));
    print_usize(@intFromPtr(http_context));
    send_http_request(pcb, http_context) catch unreachable;
    print("asd2");
    return cNet.ERR_OK;
}

fn open_tcp_connection(ipaddr: [*c]const cNet.struct_ip4_addr, context: *HttpContext, context2: ?*anyopaque) void {
    print("open_tcp_connection");
    if (context.request.url.host != null) {
        print("HOST");
    } else {
        print("NOT HOST");
    }
    print_usize(@intFromPtr(context));
    print_usize(@intFromPtr(context2.?));
    const pcb = cNet.tcp_new();
    if (pcb == null) {
        return;
    }
    if (context.request.url.host != null) {
        print("HOST");
    } else {
        print("NOT HOST");
    }
    cNet.tcp_arg(pcb, context2);
    _ = cNet.tcp_connect(pcb, ipaddr, context.request.url.port orelse 80, tcp_connected_callback);
}

fn dns_callback(_: [*c]const u8, ipaddr: [*c]const cNet.struct_ip4_addr, context: ?*anyopaque) callconv(.C) void {
    print("DNS resolution returned!");
    if (ipaddr) |addr| {
        print("DNS resolution successful!");
        const http_context: *HttpContext = @ptrCast(@alignCast(context));
        print_usize(@intFromPtr(http_context));
        print(http_context.request.url.scheme);
        if (http_context.request.url.host != null) {
            print("HOST");
        } else {
            print("NOT HOST");
        }
        open_tcp_connection(addr, http_context, context);
    }
}

pub const Client = struct {
    allocator: std.mem.Allocator,
    pub fn sendRequest(client: *const Client, request: *const HttpRequest) !?*const HttpResponse {
        print("Client.sendRequest");
        const context: HttpContext = .{ .client = client, .request = request };

        cNet.cyw43_arch_lwip_begin();
        var cached_address = cNet.ip_addr_t{};

        if (context.request.url.host != null) {
            print("HOST");
        } else {
            print("NOT HOST");
        }

        const host = if (request.url.host) |host| host else unreachable;
        const host_string = switch (host) {
            .raw => |v| v,
            .percent_encoded => |v| v,
        };
        if (context.request.url.host != null) {
            print("HOST");
        } else {
            print("NOT HOST");
        }

        const host_c_string = try client.allocator.alloc(u8, host_string.len + 1);
        defer client.allocator.free(host_c_string);
        print_usize(host_string.len);
        print_usize(host_c_string.len);
        host_c_string[host_c_string.len - 1] = 0;
        // @memcpy(host_c_string, host_string);
        for (0..host_string.len) |i| {
            host_c_string[i] = host_string[i];
        }
        if (context.request.url.host != null) {
            print("HOST");
        } else {
            print("NOT HOST");
        }

        print("Request host is");
        print(host_c_string);
        print_usize(host_string.len);
        print_usize(host_c_string.len);
        if (context.request.url.host != null) {
            print("HOST");
        } else {
            print("NOT HOST");
        }
        print(context.request.url.scheme);
        const result = cNet.dns_gethostbyname(@ptrCast(host_c_string), &cached_address, dns_callback, @ptrCast(@alignCast(@constCast(&context))));

        if (result == cNet.ERR_OK) {
            print("DNS resolution returned with OK");
        } else if (result == cNet.ERR_INPROGRESS) {
            print("DNS resolution returned with INPROGRESS");
        } else if (result == cNet.ERR_ARG) {
            print("DNS resolution returned with ERR_ARG");
        }
        print("Calling cyw43_arch_lwip_end");
        cNet.cyw43_arch_lwip_end();
        print("Ending sendRequest...");
        while (!context.finished) {
            cNet.sleep_ms(2000);
            print("loop...");
        }

        print("Request finished");
        return context.response;
    }
};
