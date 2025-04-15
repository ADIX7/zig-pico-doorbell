const std = @import("std");
const cNet = @cImport({
    @cInclude("pico/cyw43_arch.h");
    @cInclude("lwip/init.h");
    @cInclude("lwip/tcp.h");
    @cInclude("lwip/dns.h");
});

const utils = @import("utils.zig");
fn print(text: []const u8) void {
    utils.print(text);
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
    if (p1 == null) {
        _ = cNet.tcp_close(pcb);
        return cNet.ERR_OK;
    }
    defer {
        _ = cNet.pbuf_free(p1);
    }
    const http_context: *HttpContext = @ptrCast(@alignCast(context));
    const response = http_context.client.allocator.create(HttpResponse) catch unreachable;
    http_context.response = response;
    http_context.finished = true;
    // std.debug.print("Received data: {s}\n", .{@ptrCast([*]const u8, p1.?.payload)});
    return cNet.ERR_OK;
}

fn send_http_request(pcb: ?*cNet.tcp_pcb, context: *HttpContext) !void {
    print("Preparing request");
    const host = if (context.request.url.host) |host| host else unreachable;
    const host_string = switch (host) {
        .raw => |v| v,
        .percent_encoded => |v| v,
    };
    const path_string = switch (context.request.url.path) {
        .raw => |v| v,
        .percent_encoded => |v| v,
    };

    const request_data = .{ @tagName(context.request.method), path_string, host_string, context.request.body.len, context.request.body };

    const raw_request = try std.fmt.allocPrint(context.client.allocator, "{s} {s} HTTP/1.1\r\nHost: {s}\r\nTitle: Csengo\r\nPriority: 5\r\nX-Tags: bell\r\nContent-Length: {}\r\n\r\n{s}", request_data);
    print("Sending request");
    print(raw_request);

    defer context.client.allocator.free(raw_request);

    _ = cNet.tcp_write(pcb, raw_request.ptr, @intCast(raw_request.len), cNet.TCP_WRITE_FLAG_COPY);
    _ = cNet.tcp_output(pcb);
    print("Sent");
}
fn tcp_connected_callback(context: ?*anyopaque, pcb: ?*cNet.tcp_pcb, err: cNet.err_t) callconv(.C) cNet.err_t {
    print("tcp_connected_callback");
    if (err != cNet.ERR_OK) {
        print("ERR");
        return err;
    }
    // std.debug.print("Connected to server\n", .{});
    print("Connected to server");
    _ = cNet.tcp_recv(pcb, tcp_recv_callback);
    // TODO: handle this error
    const http_context: *HttpContext = @ptrCast(@alignCast(context));
    send_http_request(pcb, http_context) catch unreachable;
    return cNet.ERR_OK;
}

fn tcp_connection_error(_: ?*anyopaque, err: cNet.err_t) callconv(.c) void {
    print("TCP connection error");
    utils.print_i8(err);
}

fn open_tcp_connection(ipaddr: [*c]const cNet.struct_ip4_addr, context: *const HttpContext, context2: ?*anyopaque) void {
    print("open_tcp_connection");
    const pcb = cNet.tcp_new();
    if (pcb == null) {
        print("pcb is null");
        return;
    }
    cNet.tcp_arg(pcb, context2);
    cNet.tcp_err(pcb, tcp_connection_error);
    print("Opening tcp connection");
    const tcp_result = cNet.tcp_connect(pcb, ipaddr, context.request.url.port orelse 80, tcp_connected_callback);
    if (tcp_result == cNet.ERR_OK) {
        print("TCP ok");
    } else {
        print("TCP not ok");
    }
}

fn dns_callback(_: [*c]const u8, ipaddr: [*c]const cNet.struct_ip4_addr, context: ?*anyopaque) callconv(.C) void {
    print("DNS resolution returned!");
    const http_context: *HttpContext = @ptrCast(@alignCast(context));
    if (ipaddr) |addr| {
        print("DNS resolution successful!");
        open_tcp_connection(addr, http_context, context);
    } else {
        print("DNS resolution failed");
        http_context.finished = true;
    }
}

pub const Client = struct {
    allocator: std.mem.Allocator,
    pub fn sendRequest(client: *const Client, request: *const HttpRequest) !?*const HttpResponse {
        print("Client.sendRequest");
        var context: HttpContext = .{ .client = client, .request = request };

        cNet.cyw43_arch_lwip_begin();
        var cached_address = cNet.ip_addr_t{};

        const host = if (request.url.host) |host| host else unreachable;
        const host_string = switch (host) {
            .raw => |v| v,
            .percent_encoded => |v| v,
        };

        const host_c_string = try client.allocator.alloc(u8, host_string.len + 1);
        defer client.allocator.free(host_c_string);
        host_c_string[host_c_string.len - 1] = 0;
        for (0..host_string.len) |i| {
            host_c_string[i] = host_string[i];
        }

        print("Sending DNS resolution for host");
        print(host_string);
        const result = cNet.dns_gethostbyname(@ptrCast(host_c_string), &cached_address, dns_callback, @ptrCast(@alignCast(&context)));

        if (result == cNet.ERR_OK) {
            print("DNS resolution returned with OK");
            cNet.sleep_ms(10000);
            open_tcp_connection(&cached_address, &context, @ptrCast(@alignCast(&context)));
            context.finished = true;
        } else if (result == cNet.ERR_INPROGRESS) {
            print("DNS resolution returned with INPROGRESS");
        } else if (result == cNet.ERR_ARG) {
            print("DNS resolution returned with ERR_ARG");
            context.finished = true;
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
