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
// Re-export shim for tools/smd1.zig (T341, G3b pass0).
//
// Zig 0.16 forbids a source file from belonging to more than one module.
// src/rules.zig transitively imports src/colex.zig and src/enumerate.zig
// (in its test/cross-validation blocks), so those two files cannot be the
// roots of their own named modules alongside a "rules" module — doing so
// triggers "file exists in modules 'enumerate' and 'rules'". This shim is
// the SINGLE module root that owns all three; tools/smd1.zig imports it as
// the named module "engine" and reaches the kernel move generator
// (rules.Rules), the colex indexer (colex.Indexer) and the legal-position
// enumerator (enumerate.Enumerator) through it. No engine file is edited.
//
// Build wiring (build.zig, owned by the sprint console): create one module
// rooted at this file and addImport it as "engine" into the tools/smd1.zig
// test artifact / executable.
//
// Standalone (before wiring):
//   zig test --dep engine -Mmain=tools/smd1.zig -Mengine=src/smd1_engine.zig
//   zig run  --dep engine -Mmain=tools/smd1.zig -Mengine=src/smd1_engine.zig -- ...

pub const rules = @import("rules.zig");
pub const colex = @import("colex.zig");
pub const enumerate = @import("enumerate.zig");