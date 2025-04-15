const std = @import("std");
pub const p = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
    @cInclude("pico/sleep.h");
    // PICO W specific header
    @cInclude("pico/cyw43_arch.h");
});

const utils = @import("utils.zig");
fn print(text: []const u8) void {
    utils.print(text);
}

pub fn init_arch() void {
    if (p.cyw43_arch_init() != 0) {
        //TODO: error
        print("error in init_arch");
        return;
    }
}

const ConnectToWifiError = error{
    WifiError,
};
pub fn connect_wifi(ssid: []const u8, password: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const c_ssid = try utils.toSentinel(ssid, allocator, null);
    defer allocator.free(c_ssid);

    const c_password = try utils.toSentinel(password, allocator, null);
    defer allocator.free(c_password);

    p.cyw43_arch_enable_sta_mode();
    const connect_wifi_result = p.cyw43_arch_wifi_connect_timeout_ms(c_ssid.ptr, c_password.ptr, p.CYW43_AUTH_WPA2_AES_PSK, 10000);
    if (connect_wifi_result != 0) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);

        print("error in connect_wifi");
        utils.print_i8(@intCast(connect_wifi_result));

        return error.WifiError;
    }
}

pub fn disconnect_wifi() void {
    p.cyw43_arch_disable_sta_mode();
}

pub fn set_cyw43_led(input: bool) void {
    p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, input);
}

pub fn sleep_until_gpio_high(button_pin: u32) void {
    p.sleep_run_from_xosc();
    p.sleep_goto_dormant_until_edge_high(button_pin);
    p.sleep_power_up();
}
