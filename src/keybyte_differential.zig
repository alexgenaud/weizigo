////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,          //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,            //
//        'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// KEY-BYTE DECODE DIFFERENTIAL + F-7 SEEDED-DEFECT CONTROL — T395.
//
// Task: T395 (does every property have exactly one production
// implementation?) · Set: Q · 2026-08-06 · Author: flash/T395
//
// The WZO2 key byte packs [passes:1][ko_point:KO_BITS][side:1][terminal:1]
// (MSB→LSB; artifact2 §2.2). The ko field lives at bits 2..(1+ko_bits), so
// the decode is `(kb >> 2) & mask`. T383 F-7 (found T380): vb_closure's
// ca1/ca2 closure decoders used `kb >> 1` — leaking the side bit (bit 1)
// into the ko field — and the bug was duplicated at two sites (both wrong).
// Witness: Black, ko=3, passes=0, ko_bits=5 (4×4) encodes kb=0b00001100=12;
// the buggy decoder returned (12 >> 1) & 31 = 6 instead of 3. White,
// ko=NONE(16) encodes kb=(16<<2)|(1<<1)=66; the buggy decoder returned
// (66 >> 1) & 31 = 1 instead of 16.
//
// This differential runs the PRODUCTION closure decoder (vb_closure.keyByteKo)
// against the contract authority (artifact2.decodeKeyByte) over the entire
// 256-key-byte space at every ko_bits the project uses (2×2: 3, 3×3: 4,
// 4×4: 5). Identical ko field on every byte is required — verdict-level
// agreement is not enough (the F-7 bug produced wrong ko points while every
// closure verdict still passed). The F-7 control then re-introduces the
// defect via keyByteKoShift(…, 1) and shows the differential fires on the
// exact historical witnesses before the fixed path returns green.
//
// Runs under `zig build test` (wired in build.zig) and directly via
// `zig test src/keybyte_differential.zig` from the repo root.

const std = @import("std");
const vb_closure = @import("vb_closure.zig");
const artifact2 = @import("artifact2.zig");

const ko_bits_list = [_]u8{ 3, 4, 5 }; // 2×2, 3×3, 4×4 WZO2 rungs

/// GREEN: production closure decode agrees with the artifact2 contract on
/// every key byte at every ko_bits rung. Returns the first disagreement, or
/// null when the whole space agrees.
fn firstDisagreement(shift: u3) ?struct { kb: u8, ko_bits: u8, closure_ko: u8, contract_ko: u8 } {
    for (ko_bits_list) |ko_bits| {
        for (0..256) |kb| {
            const closure_ko = vb_closure.keyByteKoShift(@intCast(kb), ko_bits, shift);
            const contract_ko = artifact2.decodeKeyByte(@intCast(kb), ko_bits).ko;
            if (closure_ko != contract_ko) {
                return .{ .kb = @intCast(kb), .ko_bits = ko_bits, .closure_ko = closure_ko, .contract_ko = contract_ko };
            }
        }
    }
    return null;
}

test "key-byte differential: closure decode == artifact2 contract on all 256 bytes × ko_bits {3,4,5}" {
    const d = firstDisagreement(2);
    if (d) |dd| {
        std.debug.print("[keybyte-diff] DISAGREEMENT: kb={d} ko_bits={d} closure={d} contract={d}\n", .{ dd.kb, dd.ko_bits, dd.closure_ko, dd.contract_ko });
        return error.KeyByteDifferentialFired;
    }
    std.debug.print("[keybyte-diff] GREEN: closure decode == artifact2 contract on all {d} bytes × {d} ko_bits rungs\n", .{ 256, ko_bits_list.len });
}

test "key-byte differential: F-7 control — seeded kb>>1 decode fires, fixed path is green" {
    // RED: the seeded shift-1 decode reproduces the exact F-7 witness
    // readings (kb=12 → ko=6 instead of 3; kb=66 → ko=1 instead of 16) and
    // the differential over the whole space FAILS on them.
    try std.testing.expectEqual(@as(u8, 6), vb_closure.keyByteKoShift(12, 5, 1)); // F-7 witness, buggy
    try std.testing.expectEqual(@as(u8, 1), vb_closure.keyByteKoShift(66, 5, 1)); // F-7 witness, buggy
    const d = firstDisagreement(1);
    if (d == null) {
        std.debug.print("[keybyte-diff F-7] FAIL: seeded kb>>1 decode agreed with the contract — the differential would NOT fire\n", .{});
        return error.F7ControlNotRed;
    }
    std.debug.print("[keybyte-diff F-7] RED: seeded kb>>1 decode diverges from the contract (first at kb={d} ko_bits={d}: closure ko={d} vs contract ko={d}) — the differential fires\n", .{ d.?.kb, d.?.ko_bits, d.?.closure_ko, d.?.contract_ko });

    // GREEN: the fixed production path (shift=2) agrees everywhere, and the
    // historical witnesses decode correctly.
    try std.testing.expectEqual(@as(u8, 3), vb_closure.keyByteKo(12, 5));
    try std.testing.expectEqual(@as(u8, 16), vb_closure.keyByteKo(66, 5));
    try std.testing.expect(firstDisagreement(2) == null);
    std.debug.print("[keybyte-diff F-7] GREEN: fixed path (kb>>2) agrees with the contract on every byte\n", .{});
}
