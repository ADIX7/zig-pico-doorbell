const std = @import("std");
const p = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
    @cInclude("hardware/watchdog.h");
});

const httpClient = @import("httpClient.zig");
const platform = @import("platform.zig");
const utils = @import("utils.zig");

const BUTTON_PIN = 28;
const GPIO_IN = false;

pub const std_options: std.Options = .{ .page_size_max = 4 * 1024, .page_size_min = 4 * 1024 };

fn print(text: []const u8) void {
    utils.print(text);
}

const AppSettings = struct {
    ssid: []const u8,
    password: []const u8,
    ntfy_url: []const u8,
};

const appSettings: AppSettings = x: {
    var buf: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const res = std.json.parseFromSliceLeaky(
        AppSettings,
        fba.allocator(),
        @embedFile("settings.json"),
        .{},
    );
    break :x res catch |e| {
        std.debug.print("Error parsing setting.json: {e}", .{e});
        unreachable;
    };
};

// Basically the pico_w blink sample
export fn main() c_int {
    _ = p.stdio_init_all();
    p.sleep_ms(2000);
    print("Starting ...");

    p.gpio_init(BUTTON_PIN);
    p.gpio_set_dir(BUTTON_PIN, GPIO_IN);

    platform.init_arch();

    while (true) {
        print("Going to sleep");
        platform.sleep_until_gpio_high(BUTTON_PIN);

        // Resuming from here after wake up
        // _ = p.stdio_init_all();
        // platform.init_arch();
        p.gpio_init(BUTTON_PIN);
        p.gpio_set_dir(BUTTON_PIN, GPIO_IN);
        platform.set_cyw43_led(true);

        print("Connecting to wifi...");
        platform.connect_wifi(appSettings.ssid, appSettings.password) catch unreachable;
        print("Connected!");

        send_doorbell_notification() catch unreachable;

        print("Disconnecting from wifi...");
        platform.disconnect_wifi();
        print("Disconnected!");

        while (p.gpio_get(BUTTON_PIN)) {
            print("Button is still pressed");
            p.sleep_ms(2000);
        }

        platform.set_cyw43_led(false);
        p.sleep_ms(1000);
        p.watchdog_reboot(0, 0, 0);
    }
}

pub fn send_doorbell_notification() !void {
    var store: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&store);
    const allocator = fba.allocator();

    var client = &httpClient.Client{ .allocator = allocator };

    const request = &httpClient.HttpRequest{ .method = .POST, .url = try std.Uri.parse(appSettings.ntfy_url), .body = "Csengo", .headers = &[_]httpClient.HttpHeader{
        httpClient.HttpHeader{ .name = "Title", .value = "Csengo" },
    } };
    const response = try client.sendRequest(request);
    if (response) |r| {
        defer allocator.destroy(r);
    }
}
