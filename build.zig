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

/// Generate version.zig to src/version.zig on disk before compilation.
/// Returns a LazyPath for the generated file and registers the gen step
/// as a dependency of all compilation via the install step.
fn generateVersion(b: *std.Build) std.Build.LazyPath {
    const gen_cmd = b.addSystemCommand(&.{ "sh", "tools/gen-version.sh", "src/version.zig" });
    gen_cmd.step.name = "gen-version";
    b.getInstallStep().dependOn(&gen_cmd.step);
    return b.path("src/version.zig");
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // ── version module (generated at build time) ──────────────────
    const version_path = generateVersion(b);
    const version_mod = b.addModule("version", .{
        .root_source_file = version_path,
    });

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

    exe.root_module.addImport("version", version_mod);

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
    run_unit_tests.cwd = b.path("."); // tests access project files (e.g. bin/, untracked/)

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
    engine_vs_engine_exe.root_module.addImport("version", version_mod);
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
    chainability_exe.root_module.addImport("version", version_mod);
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
    reachcensus_exe.root_module.addImport("version", version_mod);
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
    claimlint_exe.root_module.addImport("version", version_mod);
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
    absorb_exe.root_module.addImport("version", version_mod);
    absorb_exe.root_module.addImport("claims_register", b.createModule(.{
        .root_source_file = b.path("src/claims_register.zig"),
        .target = target,
        .optimize = optimize,
    }));
    b.installArtifact(absorb_exe);

    // ── deploy absorb to bin/ (post-install deploy step) ───────────
    // T268: deploy via remove-copy-sign (tools/deploy.sh) — a bare `cp` over
    // a live signed binary on Apple Silicon SIGKILLs it (exit=137, silent).
    const absorb_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-absorb", "bin/weizigo-absorb" });
    absorb_deploy.step.dependOn(b.getInstallStep());
    const deploy_absorb_step = b.step("deploy-absorb", "Deploy weizigo-absorb to bin/ (remove-copy-sign)");
    deploy_absorb_step.dependOn(&absorb_deploy.step);

    // ── deploy managent to bin/ (post-install deploy step) ─────────
    const managent_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/managent", "bin/managent" });
    managent_deploy.step.dependOn(b.getInstallStep());
    const deploy_managent_step = b.step("deploy-managent", "Deploy managent to bin/ (remove-copy-sign)");
    deploy_managent_step.dependOn(&managent_deploy.step);

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
    managent_exe.root_module.addImport("version", version_mod);
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
    verify_battery_exe.root_module.addImport("version", version_mod);
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
    oracle_v2_build_exe.root_module.addImport("version", version_mod);
    b.installArtifact(oracle_v2_build_exe);

    // ── GTP oracle player (T263) ──────────────────────────────────
    const gtp_exe = b.addExecutable(.{
        .name = "weizigo-gtp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gtp.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    gtp_exe.root_module.addImport("version", version_mod);
    b.installArtifact(gtp_exe);

    // ── deploy weizigo-gtp to bin/ ────────────────────────────────
    const gtp_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-gtp", "bin/weizigo-gtp" });
    gtp_deploy.step.dependOn(b.getInstallStep());
    const deploy_gtp_step = b.step("deploy-gtp", "Deploy weizigo-gtp to bin/ (remove-copy-sign)");
    deploy_gtp_step.dependOn(&gtp_deploy.step);

    // ── deploy all (umbrella) ──────────────────────────────────────
    const deploy_step = b.step("deploy", "Deploy every tool to bin/ (remove-copy-sign)");
    deploy_step.dependOn(&absorb_deploy.step);
    deploy_step.dependOn(&managent_deploy.step);
    deploy_step.dependOn(&gtp_deploy.step);
}
