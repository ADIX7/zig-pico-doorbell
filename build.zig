const std = @import("std");
const pico = @import("pico_sdk").pico_sdk;

// Modify proj_name for your project name
const proj_name = "pico_doorbell";

// supported board: pico, pico_w, pico2, pico2_w
// Modify board_name for your board
const board_name = "pico_w";
// supported pico platform: rp2040, rp2350-arm-s, rp2350-riscv
// Modify pico_platform for select arm or risc-v, but the risc-v is not supported.
const pico_platform = "rp2040";

pub fn build(b: *std.Build) anyerror!void {
    const stdio_type = .usb;
    const cwy43_arch = .threadsafe_background;
    const board = try pico.getBoardConfig(board_name, pico_platform, stdio_type, cwy43_arch);

    const target = try pico.getCrossTarget(pico_platform);
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig-pico",
        .root_source_file = b.path("src/main.zig"),
        .target = std.Build.resolveTargetQuery(b, target),
        .optimize = optimize,
    });

    const option: pico.PicoAppOption = .{
        .app_name = comptime proj_name,
        .app_lib = lib,
        .board = board,
        // additional pico libs for application, it is none in blink application
        .pico_libs = "pico_cyw43_arch_lwip_threadsafe_background",
    };

    std.log.info("Begin build app\n", .{});

    const pico_build = try pico.addPicoApp(b, option);

    const uf2_create_step = b.addInstallFile(b.path("build/pico_doorbell.uf2"), "pico_doorbell.uf2");
    uf2_create_step.step.dependOn(pico_build);

    const uf2_step = b.step("uf2", "Create firmware.uf2");
    uf2_step.dependOn(&uf2_create_step.step);

    const elf_create_step = b.addInstallFile(b.path("build/pico_doorbell.elf"), "pico_doorbell.elf");
    elf_create_step.step.dependOn(pico_build);

    const elf_step = b.step("elf", "Create firmware.elf");
    elf_step.dependOn(&elf_create_step.step);

    const copy_step = b.step("copy", "Copy firmware");
    copy_step.dependOn(uf2_step);
    copy_step.dependOn(elf_step);
    b.default_step = copy_step;
}
