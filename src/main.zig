pub const p = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
});

const httpClient = @import("httpClient.zig");
const platform = @import("platform.zig");

const std = @import("std");
const BUTTON_PIN = 15;
const GPIO_IN = false;

pub const std_options: std.Options = .{ .page_size_max = 4 * 1024, .page_size_min = 4 * 1024 };

fn print(text: []const u8) void {
    _ = p.printf(text.ptr);
    _ = p.printf("\r\n");
}

// Basically the pico_w blink sample
export fn main() c_int {
    _ = p.stdio_init_all();
    p.sleep_ms(5000);
    print("Starting ...");

    p.gpio_init(BUTTON_PIN);
    p.gpio_set_dir(BUTTON_PIN, GPIO_IN);

    platform.init_arch();

    // platform.sleep_until_gpio_high(BUTTON_PIN);

    print("Connecting to wifi...");
    platform.connect_wifi(@embedFile("wifi.txt"), @embedFile("password.txt"));
    print("Connected!");

    main2() catch unreachable;

    // p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    // p.sleep_ms(200);
    // p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    // p.sleep_ms(200);

    // p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    while (true) {
        // // printf("Switching to XOSC\n");
        // p.uart_default_tx_wait_blocking();
        //
        // // Set the crystal oscillator as the dormant clock source, UART will be reconfigured from here
        // // This is necessary before sending the pico into dormancy
        // p.sleep_run_from_xosc();
        //
        // // printf("Going dormant until GPIO %d goes edge high\n", WAKE_GPIO);
        // p.uart_default_tx_wait_blocking();
        //
        // // Go to sleep until we see a high edge on GPIO 10
        // p.sleep_goto_dormant_until_edge_high(BUTTON_PIN);
        //
        // p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        // // Re-enabling clock sources and generators.
        // p.sleep_power_up();
        // _ = p.stdio_init_all();
        // printf("Now awake for 10s\n");
        platform.set_cyw43_led(true);
        p.sleep_ms(5000);

        // while (p.gpio_get(BUTTON_PIN)) {
        //     p.sleep_ms(50);
        // }
        platform.set_cyw43_led(false);
        p.sleep_ms(2000);
    }
}

// fn tcp_recv_callback(_: ?*anyopaque, pcb: ?*c.tcp_pcb, p1: ?*c.pbuf, _: c.err_t) callconv(.C) c.err_t {
//     if (p1 == null) {
//         _ = c.tcp_close(pcb);
//         return c.ERR_OK;
//     }
//     defer {
//         _ = c.pbuf_free(p1);
//     }
//     // std.debug.print("Received data: {s}\n", .{@ptrCast([*]const u8, p1.?.payload)});
//     return c.ERR_OK;
// }
//
// fn send_http_request(pcb: ?*c.tcp_pcb) void {
//     const request = "POST /todo-channel-name HTTP/1.1\r\nHost: ntfy.sh\r\nTitle: Csengo\r\nContent-Length: 6\r\n\r\nCsengo";
//     _ = c.tcp_write(pcb, request, request.len, c.TCP_WRITE_FLAG_COPY);
//     _ = c.tcp_output(pcb);
// }
//
// fn tcp_connected_callback(_: ?*anyopaque, pcb: ?*c.tcp_pcb, err: c.err_t) callconv(.C) c.err_t {
//     if (err != c.ERR_OK) {
//         return err;
//     }
//     // std.debug.print("Connected to server\n", .{});
//     _ = c.tcp_recv(pcb, tcp_recv_callback);
//     send_http_request(pcb);
//     return c.ERR_OK;
// }
//
// fn dns_callback(_: [*c]const u8, ipaddr: [*c]const c.struct_ip4_addr, _: ?*anyopaque) callconv(.C) void {
// if (ipaddr) |addr| {
//         const pcb = c.tcp_new();
//         if (pcb == null) {
//             return;
//         }
//         _ = c.tcp_connect(pcb, addr, 80, tcp_connected_callback);
//     }
// }

pub fn main2() !void {
    // c.cyw43_arch_lwip_begin();
    // var cached_address = c.ip_addr_t{};
    //
    // const result = c.dns_gethostbyname("ntfy.sh", &cached_address, dns_callback, null);
    //
    // if (result == c.ERR_OK) {} else if (result == c.ERR_INPROGRESS) {} else if (result == c.ERR_ARG) {}
    // c.cyw43_arch_lwip_end();

    var store: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&store);
    const allocator = fba.allocator();

    var client = &httpClient.Client{ .allocator = allocator };

    const request = &httpClient.HttpRequest{ .method = .POST, .url = try std.Uri.parse("http://ntfy.sh/todo-channel-name"), .body = "Csengo", .headers = &[_]httpClient.HttpHeader{
        httpClient.HttpHeader{ .name = "Title", .value = "Csengo" },
    } };
    try client.sendRequest(request);
}
