pub const p = @cImport({
    @cInclude("pico.h");
    @cInclude("stdio.h");
    @cInclude("pico/stdlib.h");
    @cInclude("pico/sleep.h");
    // PICO W specific header
    @cInclude("pico/cyw43_arch.h");
});

fn print(text: []const u8) void {
    _ = p.printf(text.ptr);
    _ = p.printf("\r\n");
}

pub fn init_arch() void {
    if (p.cyw43_arch_init() != 0) {
        //TODO: error
        print("error in init_arch");
        return;
    }
}

pub fn connect_wifi(ssid: []const u8, password: []const u8) void {
    p.cyw43_arch_enable_sta_mode();
    if (p.cyw43_arch_wifi_connect_timeout_ms(ssid.ptr, password.ptr, p.CYW43_AUTH_WPA2_AES_PSK, 10000) == 1) {
        p.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, true);
        //TODO: error
        print("error in connect_wifi");
        return;
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
