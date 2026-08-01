////////////////////////////////////////////
//                                        //
//    (c) 2024 Alexander E Genaud         //
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

const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "weizigo",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // ── oracle-v2 acceptance tests (M4a, T182) ────────────────────
    const oracle_v2_accept_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/oracle_v2_accept.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_oracle_v2_accept_tests = b.addRunArtifact(oracle_v2_accept_tests);
    test_step.dependOn(&run_oracle_v2_accept_tests.step);

    // ── verify-battery: table invariants (vb_table) ──────────────
    const vb_table_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_table.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_table_tests.root_module.import_table = .{};
    const run_vb_table_tests = b.addRunArtifact(vb_table_tests);
    run_vb_table_tests.cwd = b.path("."); // tests need artifacts/ from project root
    test_step.dependOn(&run_vb_table_tests.step);

    // ── verify-battery: fixpoint invariants (vb_fixpoint) ────────
    const vb_fixpoint_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_fixpoint.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vb_fixpoint_tests = b.addRunArtifact(vb_fixpoint_tests);
    run_vb_fixpoint_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_fixpoint_tests.step);

    // ── verify-battery: graph invariants (vb_graph) ──────────────
    const vb_graph_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_graph.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vb_graph_tests = b.addRunArtifact(vb_graph_tests);
    run_vb_graph_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_graph_tests.step);

    // ── engine-vs-engine ──────────────────────────────────────────
    const engine_vs_engine_exe = b.addExecutable(.{
        .name = "weizigo-engine-vs-engine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/engine-vs-engine.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(engine_vs_engine_exe);

    // ── chainability audit ─────────────────────────────────────────
    // Measures where a .wzo table value may legitimately be compared with its
    // children's (the history-free Bellman identity). Gates FP1 check 3.
    const chainability_exe = b.addExecutable(.{
        .name = "weizigo-chainability",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/chainability.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(chainability_exe);

    // ── reachable ko-sensitivity census ────────────────────────────
    // Plays whole games from the empty goban under several policies and
    // measures the KO_SENSITIVE fraction over the nodes actually REACHED —
    // the player-relevant denominator, as opposed to the chainability
    // audit's slot-uniform one.
    const reachcensus_exe = b.addExecutable(.{
        .name = "weizigo-reachcensus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/reachcensus.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(reachcensus_exe);

    // ── claim-register linter ──────────────────────────────────────
    // Parses docs/epistemic/CLAIMS.md and the repo, and reports orphaned
    // claims (a live claim derived from a falsified one), dangling evidence
    // paths, PROVEN claims whose evidence is not committed, and dangling
    // claim IDs. Each check maps to a failure this project actually suffered.
    const claimlint_exe = b.addExecutable(.{
        .name = "weizigo-claimlint",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/claimlint.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(claimlint_exe);

    // ── absorption tool ────────────────────────────────────────────
    // Reads a findings JSON file and CLAIMS.md, outputs JSON-Lines edit
    // directives. The mechanical half of knowledge-capture absorption.
    const absorb_exe = b.addExecutable(.{
        .name = "weizigo-absorb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/absorb.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    absorb_exe.root_module.addImport("claims_register", b.createModule(.{
        .root_source_file = b.path("src/claims_register.zig"),
        .target = target,
        .optimize = optimize,
    }));
    b.installArtifact(absorb_exe);

    // ── deploy absorb to bin/ (post-install copy step) ────────────
    const absorb_deploy = b.addSystemCommand(&.{ "cp", "zig-out/bin/weizigo-absorb", "bin/weizigo-absorb" });
    absorb_deploy.step.dependOn(b.getInstallStep());
    const deploy_absorb_step = b.step("deploy-absorb", "Copy weizigo-absorb to bin/");
    deploy_absorb_step.dependOn(&absorb_deploy.step);

    // ── managent ───────────────────────────────────────────────────
    const managent_exe = b.addExecutable(.{
        .name = "managent",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/managent/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(managent_exe);

    // ── verify-battery (M1 harness, T168) ──────────────────────────
    const verify_battery_exe = b.addExecutable(.{
        .name = "verify-battery",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/verify_battery.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(verify_battery_exe);

    // ── oracle-v2 builder (M2b, T165) ─────────────────────────────
    const oracle_v2_build_exe = b.addExecutable(.{
        .name = "weizigo-oracle-v2-build",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/oracle_v2_build.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(oracle_v2_build_exe);
}
