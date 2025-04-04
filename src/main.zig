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
    p.sleep_ms(2000);
    print("Starting ...");

    p.gpio_init(BUTTON_PIN);
    p.gpio_set_dir(BUTTON_PIN, GPIO_IN);

    platform.init_arch();

    while (true) {
        print("Going to sleep");
        platform.sleep_until_gpio_high(BUTTON_PIN);

        // Resuming from here after wake up
        // platform.init_arch();
        p.gpio_init(BUTTON_PIN);
        p.gpio_set_dir(BUTTON_PIN, GPIO_IN);
        platform.set_cyw43_led(true);

        print("Connecting to wifi...");
        platform.connect_wifi(@embedFile("wifi.txt"), @embedFile("password.txt"));
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
    }
}

pub fn send_doorbell_notification() !void {
    var store: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&store);
    const allocator = fba.allocator();

    var client = &httpClient.Client{ .allocator = allocator };

    const request = &httpClient.HttpRequest{ .method = .POST, .url = try std.Uri.parse("http://ntfy.sh/todo-channel-name"), .body = "Csengo", .headers = &[_]httpClient.HttpHeader{
        httpClient.HttpHeader{ .name = "Title", .value = "Csengo" },
    } };
    const response = try client.sendRequest(request);
    if (response) |r| {
        defer allocator.destroy(r);
    }
}
