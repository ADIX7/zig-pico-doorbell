pub const p = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
    @cInclude("pico/sleep.h");
    // PICO W specific header
    @cInclude("pico/cyw43_arch.h");
});

const c = @cImport({
    @cInclude("pico/cyw43_arch.h");
    @cInclude("lwip/init.h");
    @cInclude("lwip/tcp.h");
    @cInclude("lwip/dns.h");
});

const std = @import("std");
const BUTTON_PIN = 15;
const GPIO_IN = false;

pub const std_options: std.Options = .{ .page_size_max = 4 * 1024, .page_size_min = 4 * 1024 };

// Basically the pico_w blink sample
export fn main() c_int {
    p.sleep_ms(5000);
    _ = p.stdio_init_all();

    p.gpio_init(BUTTON_PIN);
    p.gpio_set_dir(BUTTON_PIN, GPIO_IN);

    if (p.cyw43_arch_init() != 0) {
        return -1;
    }

    p.sleep_run_from_xosc();
    p.sleep_goto_dormant_until_edge_high(BUTTON_PIN);
    p.sleep_power_up();


    p.cyw43_arch_enable_sta_mode();
    if (p.cyw43_arch_wifi_connect_timeout_ms(@embedFile("wifi.txt"), @embedFile("password.txt"), p.CYW43_AUTH_WPA2_AES_PSK, 10000) == 1) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        return -1;
    }

    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(200);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    p.sleep_ms(200);

    // while (true) {
    //     p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    //     p.sleep_ms(500);
    //     p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    //     p.sleep_ms(1000);
    // }
    // _ = p.printf("Hello world\n");

    // httpRequest();
    main2();

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
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(5000);

        // while (p.gpio_get(BUTTON_PIN)) {
        //     p.sleep_ms(50);
        // }
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(2000);
    }
}

fn httpRequest() void {
    // Create a general purpose allocator
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    //
    // // Create a HTTP client
    // var client = std.http.Client{ .allocator = gpa.allocator() };
    // defer client.deinit();
    //
    // // Allocate a buffer for server headers
    // var buf: [4096]u8 = undefined;
    //
    // // Start the HTTP request
    // const uri = try std.Uri.parse("https://www.google.com?q=zig");
    // var req = try client.open(.GET, uri, .{ .server_header_buffer = &buf });
    // defer req.deinit();
    //
    // // Send the HTTP request headers
    // try req.send();
    // // Finish the body of a request
    // try req.finish();
    //
    // // Waits for a response from the server and parses any headers that are sent
    // try req.wait();
    //
    // std.debug.print("status={d}\n", .{req.response.status});
}

fn tcp_recv_callback(_: ?*anyopaque, pcb: ?*c.tcp_pcb, p1: ?*c.pbuf, _: c.err_t) callconv(.C) c.err_t {
    if (p1 == null) {
        _ = c.tcp_close(pcb);
        return c.ERR_OK;
    }
    defer {
        _ = c.pbuf_free(p1);
    }
    // std.debug.print("Received data: {s}\n", .{@ptrCast([*]const u8, p1.?.payload)});
    return c.ERR_OK;
}

fn send_http_request(pcb: ?*c.tcp_pcb) void {
    const request = "POST /todo-channel-name HTTP/1.1\r\nHost: ntfy.sh\r\nTitle: Csengo\r\nContent-Length: 6\r\n\r\nCsengo";
    _ = c.tcp_write(pcb, request, request.len, c.TCP_WRITE_FLAG_COPY);
    _ = c.tcp_output(pcb);
}

fn tcp_connected_callback(_: ?*anyopaque, pcb: ?*c.tcp_pcb, err: c.err_t) callconv(.C) c.err_t {
    if (err != c.ERR_OK) {
        return err;
    }
    // std.debug.print("Connected to server\n", .{});
    _ = c.tcp_recv(pcb, tcp_recv_callback);
    send_http_request(pcb);
    return c.ERR_OK;
}

fn dns_callback(_: [*c]const u8, ipaddr: [*c]const c.struct_ip4_addr, _: ?*anyopaque) callconv(.C) void {
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(3000);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    p.sleep_ms(1000);

    if (ipaddr) |addr| {
        const pcb = c.tcp_new();
        if (pcb == null) {
            return;
        }
        _ = c.tcp_connect(pcb, addr, 80, tcp_connected_callback);
    }
}

pub fn main2() void {
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(300);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    p.sleep_ms(2000);

    // c.lwip_init();
    // c.dns_init();

    c.cyw43_arch_lwip_begin();
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(1000);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    p.sleep_ms(2000);

    // Set DNS server (Google DNS: 8.8.8.8)
    // const dns_server = c.ip_addr_t{
    //     .u_addr = .{
    //         .ip4 = c.ip4_addr{
    //             .addr = c.PP_HTONL(0x08080808), // 8.8.8.8 in hexadecimal, network byte order
    //         },
    //     },
    //     .type = c.IPADDR_TYPE_V4,
    // };
    // c.dns_setserver(0, &dns_server);
    var cached_address = c.ip_addr_t{};

    const result = c.dns_gethostbyname("ntfy.sh", &cached_address, dns_callback, null);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(1000);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    p.sleep_ms(2000);

    if (result == c.ERR_OK) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(1000);
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(2000);
    } else if (result == c.ERR_INPROGRESS) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(3000);
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(2000);
    } else if (result == c.ERR_ARG) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        p.sleep_ms(5000);
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
        p.sleep_ms(2000);
    }
    c.cyw43_arch_lwip_end();

    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(300);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    p.sleep_ms(300);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(300);
    // p.sleep_ms(300);
}
