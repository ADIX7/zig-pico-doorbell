pub const p = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
    // PICO W specific header
    @cInclude("pico/cyw43_arch.h");
});
const std = @import("std");
const BUTTON_PIN = 15;
const GPIO_IN = false;

pub const std_options: std.Options = .{ .page_size_max = 4 * 1024, .page_size_min = 4 * 1024 };

// Basically the pico_w blink sample
export fn main() c_int {
    _ = p.stdio_init_all();
    if (p.cyw43_arch_init() != 0) {
        return -1;
    }

    p.cyw43_arch_enable_sta_mode();
    if (p.cyw43_arch_wifi_connect_timeout_ms(@embedFile("wifi.txt"), @embedFile("password.txt"), p.CYW43_AUTH_WPA2_AES_PSK, 10000) == 1) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        return -1;
    }

    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    p.sleep_ms(200);
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);

    p.gpio_init(BUTTON_PIN);
    p.gpio_set_dir(BUTTON_PIN, GPIO_IN);

    // while (true) {
    //     p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
    //     p.sleep_ms(500);
    //     p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    //     p.sleep_ms(1000);
    // }
    // _ = p.printf("Hello world\n");

    httpRequest();

    while (true) {
        while (p.gpio_get(BUTTON_PIN)) {
            p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
            p.sleep_ms(50);
        }
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, false);
    }
}

fn httpRequest() !void {
    // Create a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Create a HTTP client
    var client = std.http.Client{ .allocator = gpa.allocator() };
    defer client.deinit();

    // Allocate a buffer for server headers
    var buf: [4096]u8 = undefined;

    // Start the HTTP request
    const uri = try std.Uri.parse("https://www.google.com?q=zig");
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &buf });
    defer req.deinit();

    // Send the HTTP request headers
    try req.send();
    // Finish the body of a request
    try req.finish();

    // Waits for a response from the server and parses any headers that are sent
    try req.wait();

    std.debug.print("status={d}\n", .{req.response.status});
}
