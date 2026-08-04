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

    // ── verify-battery: mutation catalogue (vb_mutants, T291) ────
    const vb_mutants_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_mutants.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_vb_mutants_tests = b.addRunArtifact(vb_mutants_tests);
    run_vb_mutants_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_mutants_tests.step);

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

    // ── T312: parallel fixpoint race controls ────────────────────
    const t312_race_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/t312_race_control.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_t312_race_tests = b.addRunArtifact(t312_race_tests);
    run_t312_race_tests.cwd = b.path(".");
    test_step.dependOn(&run_t312_race_tests.step);

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

    // ── pre-commit hook regression controls (T272) ──────────────────
    const precommit_regression = b.addSystemCommand(&.{ "sh", "tools/regression-precommit.sh" });
    precommit_regression.cwd = b.path(".");
    test_step.dependOn(&precommit_regression.step);

    // ── runner reporting regression controls (T311) ──────────────────
    // Null + seeded controls for the two defects T311 fixed:
    //   1. darwin walker noise (linux /proc probe on every poll)
    //   2. prepend_releasefast optimize-flag detection (exact token
    //      equality missed -Doptimize=<mode>)
    // Plus a guard-bite control — the RSS cap still kills.
    const runner_regression = b.addSystemCommand(&.{ "sh", "tools/regression-runner-reporting.sh" });
    runner_regression.cwd = b.path(".");
    test_step.dependOn(&runner_regression.step);

    // ── subagent-prompt controls (T315/T317) ──────────────────────────
    // bin/subagent is given a model but did not include --agent <model>
    // in the generated prompt.  T315 ships the controls standalone; T317
    // closes the wiring debt and adds model-tag→canonical validation.
    const subagent_prompt_regression = b.addSystemCommand(&.{ "sh", "tools/regression-subagent-prompt.sh" });
    subagent_prompt_regression.cwd = b.path(".");
    test_step.dependOn(&subagent_prompt_regression.step);

    // ── T337 S1: ollama-dispatcher regression controls ───────────────
    // T317 item 2 passed the canonical label to ollama launch instead
    // of the Ollama tag — every ollama dispatch would have failed, and
    // four green suite runs said nothing (caught at the T336 pass
    // boundary by dry-running a dispatch and probing both tags).
    // These controls assert that the launch uses the raw tag while the
    // claim/done lines carry the canonical label, plus a mechanized
    // cross-check that OLLAMA_TAG_TO_CANONICAL and canonical_models[]
    // do not drift.
    const ollama_disp_regression = b.addSystemCommand(&.{ "sh", "tools/regression-ollama-dispatcher.sh" });
    ollama_disp_regression.cwd = b.path(".");
    test_step.dependOn(&ollama_disp_regression.step);

    // ── T322: wire remaining orphaned regression scripts ───────────────
    // Three scripts tested; two pass cleanly.  managent-integrity fails
    // (checks deployed bin/ vs zig-out/ staleness — a pre-condition that
    // zig build test does not satisfy).  Four others deferred:
    // depth-enforcement (FAILURES), git-commit-mine (writes live tasks.json),
    // T337 S5: wire four remaining orphaned regression scripts.
    // All verified passing at HEAD (2026-08-04); T322's deferral reasons
    // were stale — managent-integrity passes all 16 checks (the deployed-
    // stamp check now passes because zig build test runs after build),
    // depth-enforcement passes all 7 controls, git-commit-mine passes all
    // 9 controls and was verified NOT to write live tasks.json (operates
    // in /tmp/weizigo scratch repo), git-commit-mine-hook passes all 6
    // controls after C9 stub fix (added missing C9 output line).
    // T227 still times out (>120s) — deferred same as T322.
    const integrity_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-integrity.sh" });
    integrity_regression.cwd = b.path(".");
    test_step.dependOn(&integrity_regression.step);

    const depth_regression = b.addSystemCommand(&.{ "sh", "tools/regression-depth-enforcement.sh" });
    depth_regression.cwd = b.path(".");
    test_step.dependOn(&depth_regression.step);

    const gcm_regression = b.addSystemCommand(&.{ "sh", "tools/regression-git-commit-mine.sh" });
    gcm_regression.cwd = b.path(".");
    test_step.dependOn(&gcm_regression.step);

    const gcm_hook_regression = b.addSystemCommand(&.{ "sh", "tools/regression-git-commit-mine-hook.sh" });
    gcm_hook_regression.cwd = b.path(".");
    test_step.dependOn(&gcm_hook_regression.step);

    // ── resume-surface controls (T286) ───────────────────────────────
    // Null control (empty kanban + clean tree says NOTHING IN FLIGHT) and
    // seeded control (in_progress task + held file both appear). SKIPs
    // loudly when no managent binary with the resume command exists —
    // build with `zig build` first (same convention as the claimlint
    // control in regression-precommit.sh).
    const resume_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-resume.sh" });
    resume_regression.cwd = b.path(".");
    test_step.dependOn(&resume_regression.step);

    // ── standing-tier controls (T294) ───────────────────────────────
    // STANDING-ABSORB null + seeded controls — the standing mechanism had
    // no controls at all before T294; this is the pair the brief demands
    // (below-threshold C7 stays silent and says so; a synthetic unabsorbed
    // finding pushes C7 over and the trigger fires and names the count).
    // Same SKIP convention as the resume regression: no managent binary
    // carrying `standing`, or no deployed claimlint to copy into the
    // scratch repo → SKIP loudly.
    const standing_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-standing.sh" });
    standing_regression.cwd = b.path(".");
    test_step.dependOn(&standing_regression.step);

    // ── T337 S0: managent store-lock controls ──────────────────────
    // Replaces the mkdir mutex (which leaked on every exit(1) after
    // lock acquisition) with flock(2): the kernel releases the lock
    // on ANY process termination.  Two controls: (1) rejection path
    // releases lock, (2) SIGKILL holder → next command succeeds.
    const lock_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-lock.sh" });
    lock_regression.cwd = b.path(".");
    test_step.dependOn(&lock_regression.step);

    // ── claimlint promotion-gate controls (T308) ─────────────────
    // C8 mutation-adequacy gate: verifies no kernel-function claim has
    // been promoted past CLAIMED without the battery killing its mutants.
    const promotion_regression = b.addSystemCommand(&.{ "sh", "tools/regression-claimlint-promotion.sh" });
    promotion_regression.cwd = b.path(".");
    test_step.dependOn(&promotion_regression.step);

    // ── claimlint redirect-output controls (T307) ──────────────────
    // Null control (pipe vs file redirect byte-identical, SUMMARY
    // present) and seeded control (recorded 491-byte fragment from the
    // old buggy binary is detected as the truncation defect).
    // SKIPs loudly when no claimlint binary in zig-out/bin/.
    const claimlint_redirect_regression = b.addSystemCommand(&.{ "sh", "tools/regression-claimlint-output.sh" });
    claimlint_redirect_regression.cwd = b.path(".");
    test_step.dependOn(&claimlint_redirect_regression.step);

    // ── deployed-binaries guard (T289) ───────────────────────────────
    // tools/smoke.sh compares every deployed bin/ tool's embedded build
    // stamp against committed source history — a stale bin/ (built before
    // committed source changes affecting that tool) fails the suite. T268
    // built the check; T286 proved nothing ran it: the read-first surface
    // was deleted while its replacement lived only in zig-out/. Same gate
    // as the pre-commit and resume regressions above.
    const smoke_regression = b.addSystemCommand(&.{ "sh", "tools/smoke.sh" });
    smoke_regression.cwd = b.path(".");
    test_step.dependOn(&smoke_regression.step);

    // ── differential (T257/T267: agreement matrix + key invariant) ─
    const differential_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/differential.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    differential_tests.root_module.import_table = .{};
    const run_differential_tests = b.addRunArtifact(differential_tests);
    run_differential_tests.cwd = b.path(".");
    test_step.dependOn(&run_differential_tests.step);

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

    // ── verify-battery: golden-master baseline gate (T292) ─────────
    // Runs the freshly-built verify-battery binary on the four git-tracked
    // WZO1 artifacts (oracle-2x2/3x2/3x3/4x3) and compares against the
    // committed baseline docs/evidence/BATTERY/baselines.json under exact
    // equality — a regression is any difference in (status, numerator,
    // denominator, mode_declared, mode_actual, exit_class, sample params).
    // addArtifactArg makes the binary a compile dependency, so the gate
    // always runs the current battery. The slow full-artifact sweep (4x4
    // WZO1s + WZO2) is behind `zig build battery-sweep`, never in the suite.
    const battery_baselines = b.addSystemCommand(&.{ "sh", "tools/regression-battery-baselines.sh" });
    battery_baselines.cwd = b.path(".");
    battery_baselines.addArtifactArg(verify_battery_exe);
    test_step.dependOn(&battery_baselines.step);

    // ── oracle-v2 acceptance binary (T182/T292: battery-sweep) ─────
    // Needed by the slow sweep (zig build battery-sweep) to check the WZO2
    // artifact; installed so the sweep step can depend on it via
    // addArtifactArg. The unit tests for this file are wired separately
    // (oracle_v2_accept_tests above).
    const oracle_v2_accept_exe = b.addExecutable(.{
        .name = "oracle-v2-accept",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/oracle_v2_accept.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(oracle_v2_accept_exe);

    // ── battery-sweep: slow full-artifact baseline sweep (T292) ────
    // Explicit step — never part of `zig build test`. Covers the three
    // data/ 4x4 WZO1 artifacts and the WZO2 artifact (0c3366f0) via
    // oracle-v2-accept. Host-only artifacts absent on a fresh clone SKIP
    // loudly. Sequential by construction (one script, one artifact at a
    // time under tools/runner — GRAND-AUDIT §3).
    const battery_sweep_cmd = b.addSystemCommand(&.{ "sh", "tools/regression-battery-sweep.sh" });
    battery_sweep_cmd.cwd = b.path(".");
    battery_sweep_cmd.addArtifactArg(verify_battery_exe);
    battery_sweep_cmd.addArtifactArg(oracle_v2_accept_exe);
    const battery_sweep = b.step("battery-sweep", "Slow full-artifact golden-master sweep (4x4 WZO1s + WZO2 0c3366f0) against baselines.json");
    battery_sweep.dependOn(&battery_sweep_cmd.step);

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

    // ── deploy weizigo-claimlint to bin/ ───────────────────────────
    // GRAND-AUDIT §3 flagged bin/weizigo-claimlint as older than its source
    // and unstamped; it reached bin/ only by manual copy. Give it the same
    // mechanical remove-copy-sign deploy as every other tool (T268).
    const claimlint_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-claimlint", "bin/weizigo-claimlint" });
    claimlint_deploy.step.dependOn(b.getInstallStep());
    const deploy_claimlint_step = b.step("deploy-claimlint", "Deploy weizigo-claimlint to bin/ (remove-copy-sign)");
    deploy_claimlint_step.dependOn(&claimlint_deploy.step);

    // ── deploy the research tools to bin/ ──────────────────────────
    // weizigo-chainability / weizigo-engine-vs-engine / weizigo-reachcensus
    // are deployed to bin/ like the rest; they get the same deploy so the
    // stale-bin class cannot recur for them either (T268, "and the rest").
    const chainability_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-chainability", "bin/weizigo-chainability" });
    chainability_deploy.step.dependOn(b.getInstallStep());
    const deploy_chainability_step = b.step("deploy-chainability", "Deploy weizigo-chainability to bin/ (remove-copy-sign)");
    deploy_chainability_step.dependOn(&chainability_deploy.step);

    const evse_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-engine-vs-engine", "bin/weizigo-engine-vs-engine" });
    evse_deploy.step.dependOn(b.getInstallStep());
    const deploy_evse_step = b.step("deploy-engine-vs-engine", "Deploy weizigo-engine-vs-engine to bin/ (remove-copy-sign)");
    deploy_evse_step.dependOn(&evse_deploy.step);

    const reachcensus_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-reachcensus", "bin/weizigo-reachcensus" });
    reachcensus_deploy.step.dependOn(b.getInstallStep());
    const deploy_reachcensus_step = b.step("deploy-reachcensus", "Deploy weizigo-reachcensus to bin/ (remove-copy-sign)");
    deploy_reachcensus_step.dependOn(&reachcensus_deploy.step);

    // ── deploy all (umbrella) ──────────────────────────────────────
    const deploy_step = b.step("deploy", "Deploy every tool to bin/ (remove-copy-sign)");
    deploy_step.dependOn(&absorb_deploy.step);
    deploy_step.dependOn(&managent_deploy.step);
    deploy_step.dependOn(&gtp_deploy.step);
    deploy_step.dependOn(&claimlint_deploy.step);
    deploy_step.dependOn(&chainability_deploy.step);
    deploy_step.dependOn(&evse_deploy.step);
    deploy_step.dependOn(&reachcensus_deploy.step);
}
