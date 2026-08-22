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

    // ── engine module (kernel re-export shim, T341) — shared by vb_i11,
    // vb_mutants, and tools/smd1. Wired here once so the named import
    // @import("engine") resolves in every consumer.
    const engine_mod = b.createModule(.{
        .root_source_file = b.path("src/smd1_engine.zig"),
        .target = target,
        .optimize = optimize,
    });

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

    // ── claimlint C11 audit-enforcement unit tests (T491) ───────────
    // `zig test src/claimlint.zig` runs the same tests standalone; wired here
    // so `zig build test` gates the tier-A audit check on every suite run. The
    // module gets the same imports as the claimlint executable below — the
    // `version` module is load-bearing (claimlint.zig imports it by module
    // name); claims_register/absorb are mirrored for parity.
    const claimlint_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/claimlint.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    claimlint_tests.root_module.addImport("version", version_mod);
    claimlint_tests.root_module.addImport("claims_register", b.createModule(.{
        .root_source_file = b.path("src/claims_register.zig"),
        .target = target,
        .optimize = optimize,
    }));
    claimlint_tests.root_module.addImport("absorb", b.createModule(.{
        .root_source_file = b.path("src/absorb.zig"),
        .target = target,
        .optimize = optimize,
    }));
    const run_claimlint_tests = b.addRunArtifact(claimlint_tests);
    run_claimlint_tests.cwd = b.path(".");
    test_step.dependOn(&run_claimlint_tests.step);

    // ── managent UTF-8 truncation tests (T569) ─────────────────────
    // `zig test src/managent/main.zig` runs the same test standalone; wired
    // here so `zig build test` gates the no-split-multi-byte invariant on
    // every suite run (the 2026-08-22 argus-doctor crash regression).
    const managent_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/managent/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    managent_tests.root_module.addImport("version", version_mod);
    const run_managent_tests = b.addRunArtifact(managent_tests);
    run_managent_tests.cwd = b.path(".");
    test_step.dependOn(&run_managent_tests.step);

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
    vb_mutants_tests.root_module.addImport("engine", engine_mod);
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

    // ── T419: loopy-child taxonomy classification (Gap 1 + Gap 2) ──────
    // Pure classification + depth-1..3 recursion, unit-tested.  The driver
    // (reads WZO2 only) reconciles against T412's published table at run
    // time; the unit tests cover the classification logic itself.
    const t419_taxonomy_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/t419_taxonomy.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_t419_taxonomy_tests = b.addRunArtifact(t419_taxonomy_tests);
    run_t419_taxonomy_tests.cwd = b.path(".");
    test_step.dependOn(&run_t419_taxonomy_tests.step);

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

    // ── T531: evidence-artifact sink controls (two surfaces) ─────────
    // Ruling 4 (ROADMAP-2026-08-20 rev 3) split the suite's output into two
    // surfaces: the console carries the pass/fail summary and owes zero
    // failed-command noise, the artifact carries the [EXPECTED]/I4-I9
    // instrument readings.  `src/evidence.zig` is the sink; these are its
    // in-band controls — the null control writes the sink-control line that
    // `docs/infra/suite-truth-manifest.md` then requires, so a sink that quietly
    // stopped working fails the gate on its own account instead of as a silence
    // spread across every instrument.  The console half (a passing binary emits
    // nothing on stderr) is asserted from outside, in
    // tools/regression-suite-surfaces.sh, with its seeded-defect twin.
    const evidence_control_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/evidence_control.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_evidence_control_tests = b.addRunArtifact(evidence_control_tests);
    run_evidence_control_tests.cwd = b.path(".");
    test_step.dependOn(&run_evidence_control_tests.step);

    // ── T531: two-surfaces gate controls ─────────────────────────────
    const suite_surfaces_regression = b.addSystemCommand(&.{ "sh", "tools/regression-suite-surfaces.sh" });
    suite_surfaces_regression.cwd = b.path(".");
    test_step.dependOn(&suite_surfaces_regression.step);

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

    // ── fleet-aware memory guard controls (T362) ───────────────────────
    // The runner's RSS cap is per-process and absolute; T362 adds a
    // host-pressure guard that reads system-wide available memory and,
    // below a danger floor derived from hw.memsize, SIGKILLs the LARGEST
    // member of the process group.  Four arms: null (small job untouched),
    // seeded (host guard fires on the composition case via an injected
    // reading, per-process cap does NOT), seeded (progress watchdog still
    // bites — that guard is unchanged), guard-bite (per-process cap still
    // bites).  `zig build test` is the T362 acceptance gate.
    const runner_guard_regression = b.addSystemCommand(&.{ "sh", "tools/regression-runner-guard.sh" });
    runner_guard_regression.cwd = b.path(".");
    test_step.dependOn(&runner_guard_regression.step);

    // ── suite-child reaping controls (T548) ───────────────────────────
    // Dead workers must not leak suite children: on 2026-08-20 the fleet
    // measured orphaned `zig test` binaries holding multi-GB RSS (9.1 GB at
    // 16:51, free memory 0.06 GB) — the runner killed only its process
    // group and `zig build`'s children escaped it.  Arms: worker killed
    // with child + setsid-escapee reaped (A1), the same via each exit path
    // — wall, RSS cap, host floor (injected reading), directive kill — with
    // treekill survivors=0 (A2a-d), live worker's child untouched by the
    // sweeper + reaped on the runner's normal exit even when it holds the
    // runner's pipe (A3, the drain hang), sweeper takes a pre-existing
    // orphan only (A4), one-pass orphan never reaped (A5), session-
    // attached child never reaped (A6, the live-session hardening).
    const runner_reap_regression = b.addSystemCommand(&.{ "sh", "tools/regression-runner-reap.sh" });
    runner_reap_regression.cwd = b.path(".");
    test_step.dependOn(&runner_reap_regression.step);

    // ── orphan-reaper controls (T364) ─────────────────────────────────
    // Parent-side exit records + `managent reap`: the 2026-08-04 incident
    // (SIGKILLed runners wrote no exit heartbeat; rows sat in_progress with
    // nothing alive behind them).  Arms: exit-record null (clean run leaves
    // a completed record), seeded child-SIGKILL (record survives with
    // signal=9), seeded runner-SIGKILL (launch record remains, no exit
    // fields), reap report+close (orphans named and closed abandoned with
    // evidence), null (live worker never reaped), heartbeat-backed never
    // reaped, resume fleet-stall surface.  The reap arms SKIP loudly when
    // the managent binary lacks the reap command (main.zig integration).
    const orphan_reaper_regression = b.addSystemCommand(&.{ "sh", "tools/regression-orphan-reaper.sh" });
    orphan_reaper_regression.cwd = b.path(".");
    test_step.dependOn(&orphan_reaper_regression.step);

    // ── worktree-root controls (T449) ─────────────────────────────────
    // The runner's _find_repo_root() walked up for a `.git` DIRECTORY,
    // which is a FILE in a git worktree — repo_root resolved to None and
    // heartbeats/directives silently died for any runner launched from a
    // worktree (the T447 race ran five lanes with no heartbeats).  T449
    // resolves via `git rev-parse --show-toplevel` (same fix as bakeoff,
    // T376), walk-up kept as the non-git fallback.  Arms: seeded (heartbeat
    // lands in a fresh worktree's own untracked/), seeded (directive in
    // the worktree's directives.jsonl is read, exit 124), null
    // (main-checkout run unchanged — exactly one heartbeat line).
    const runner_worktree_regression = b.addSystemCommand(&.{ "sh", "tools/regression-runner-worktree.sh" });
    runner_worktree_regression.cwd = b.path(".");
    test_step.dependOn(&runner_worktree_regression.step);

    // ── T515: run records are task-id-named, never pid-named (F6) ────────
    // A degraded run (no --task-id, no MANAGENT_TASK_ID) used to write a
    // `runner_<pid>.json` run record that `managent reap` could not key to
    // any row (30 such stragglers were archived on 2026-08-20).  The fix:
    // tools/runner writes NO run record in degraded mode, so every record
    // that exists carries a real task id.  Arms: env-identity names the
    // record, degraded writes nothing, T370's loud warning is preserved,
    // --task-id auto-claim names the record too (SKIP when no managent).
    const runner_taskid_regression = b.addSystemCommand(&.{ "sh", "tools/regression-runner-taskid.sh" });
    runner_taskid_regression.cwd = b.path(".");
    test_step.dependOn(&runner_taskid_regression.step);

    // ── T572: load-test store-pollution controls ─────────────────────────
    // The T559 load test left six dummy lanes (TL1A..TL1F) in_progress in
    // the LIVE kanban: the runner auto-claims `--task-id` rows at launch,
    // the host guard SIGKILLed the lanes, and no exit path closed the rows
    // (scrubbed by T567; the TL1x ids carried no T427 fixture marker, so
    // the live-store guard never tripped).  The fix: a load test must run
    // against a scratch MANAGENT_STORE.  Arms: guard-kill lane under the
    // scratch store redirects the claim and never creates the live store
    // stand-in · seeded pre-fix shape makes the pollution checker go RED,
    // retire turns it GREEN · clean-exit auto-done also writes only the
    // scratch store · null control stays GREEN · the REAL live store is
    // byte-identical throughout.  Scratch repo + scratch stores only.
    const store_pollution_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-store-pollution.sh" });
    store_pollution_regression.cwd = b.path(".");
    test_step.dependOn(&store_pollution_regression.step);

    // ── T520: runner brief-bytes + dispatch wall-guidance controls ──────
    // tools/runner records brief_bytes/prompt_bytes/wall_budget in the run
    // record (so every exit-124 wall-kill is joinable to the brief that
    // caused it); tools/dispatch_verify.py carries per-task-class wall
    // guidance (spec/infra/verification/battery differ, sourced from the
    // DELEGATOR wall table) and a wall_advisory that flags a wall too low
    // for the brief.  Hermetic scratch repo — no managent needed.
    const runner_brief_regression = b.addSystemCommand(&.{ "sh", "tools/regression-runner-brief-telemetry.sh" });
    runner_brief_regression.cwd = b.path(".");
    test_step.dependOn(&runner_brief_regression.step);

    // ── T537: orcha-acceptance verdict controls ────────────────────────
    // The acceptance suite's summary printed ACCEPTANCE PASS while AC2/AC6/AC7
    // were warning (the verdict tested only $FAIL), and AC7 was a cumulative-
    // ever wall-kill counter labelled "today".  T537 ships a three-state
    // verdict (exit 0 clean / 1 FAIL / 2 WARN-only, warning ids on the line)
    // and re-scopes AC7 to a 24 h window over run records.  Drives the real
    // tools/orcha-acceptance.sh against a hermetic scratch repo (no managent).
    const orcha_accept_regression = b.addSystemCommand(&.{ "sh", "tools/regression-orcha-acceptance.sh" });
    orcha_accept_regression.cwd = b.path(".");
    test_step.dependOn(&orcha_accept_regression.step);

    // ── subagent-prompt controls (T315/T317) ──────────────────────────
    // bin/subagent is given a model but did not include --agent <model>
    // in the generated prompt.  T315 ships the controls standalone; T317
    // closes the wiring debt and adds model-tag→canonical validation.
    const subagent_prompt_regression = b.addSystemCommand(&.{ "sh", "tools/regression-subagent-prompt.sh" });
    subagent_prompt_regression.cwd = b.path(".");
    test_step.dependOn(&subagent_prompt_regression.step);

    // ── T466: fleet-surface controls (time notation + self-heal) ────
    // Pins the COMMITTED untracked/watch-fleet.sh contract (git show HEAD),
    // never the live working-tree file (co-owned; T469 landed the four-
    // section layout, the operator's console iterates on it). Arms: A
    // duration formatters obey the no-colon rule; B PROGRESS/CONCERNS
    // truth; C the opt-in heal reopens an old processless claim with an
    // assertion; D the heal leaves live/fresh/done rows alone. If a future
    // commit changes the script's layout or test hooks, this fails loudly
    // instead of silently stopping to test — that is the point.
    const watch_fleet_regression = b.addSystemCommand(&.{ "sh", "tools/regression-watch-fleet.sh" });
    watch_fleet_regression.cwd = b.path(".");
    test_step.dependOn(&watch_fleet_regression.step);

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

    // ── T411: dispatch-verification regression controls ─────────────
    // T408's kimi incident (2026-08-07): a dispatched agent replied
    // "OK." and executed nothing; the dispatch "passed" because every
    // check trusted the reply. These controls run stub workers through
    // the REAL dispatchers and assert the verification fails a lazy
    // worker (the incident, reproduced), believes side effects over
    // text for a failing worker, and adds no measurable latency to an
    // honest one. Scratch store + scratch perf ledger only — never the
    // live kanban or docs/infra/model-perf.md.
    const dispatch_verify_regression = b.addSystemCommand(&.{ "sh", "tools/regression-dispatch-verification.sh" });
    dispatch_verify_regression.cwd = b.path(".");
    test_step.dependOn(&dispatch_verify_regression.step);

    // ── T476: bin/dispatch regression controls ──────────────────────
    // T476's gap: the headless dispatch procedure (nohup detach, log
    // path, wall choice, provider↔model pairing, claude's refusal to go
    // through bin/subagent) lived only in the Orchestrator's head. These
    // controls pin the wrapper's contract: dry-run construction per model
    // family, refusal of in_progress/non-canonical/claude/missing-bundle/
    // unknown rows (nothing spawned on refusal), the T317 model-map sync
    // with src/managent/main.zig, and one real end-to-end dispatch
    // through a stub worker (detach → log → in_progress → done →
    // verification PASSED). Scratch store + scratch repo only — never the
    // live kanban, live repo, or docs/infra/model-perf.md.
    const dispatch_regression = b.addSystemCommand(&.{ "sh", "tools/regression-dispatch.sh" });
    dispatch_regression.cwd = b.path(".");
    test_step.dependOn(&dispatch_regression.step);

    // ── T503: model dimension profiles controls ───────────────────────
    // tools/model-profiles.py grades each model's performance dimensions
    // from the ledger and carries the operator's exploration-first
    // selection rule (no data on a task type is a reason to choose).
    // Controls: (a) a 0-data model is selected over one with data,
    // (b) when every candidate has data the type's dominant dimension
    // decides, (c) an empty dimension is `—` (null) never 0, (d) the
    // --json output round-trips byte-identically and matches hand-computed
    // averages, (e) an uncommitted declared deliverable flips
    // deliverable_conformance to 0.  Scratch store/ledger/logs only —
    // never the live kanban, live repo, or docs/infra/model-perf.md.
    const model_profiles_regression = b.addSystemCommand(&.{ "sh", "tools/regression-model-profiles.sh" });
    model_profiles_regression.cwd = b.path(".");
    test_step.dependOn(&model_profiles_regression.step);

    // ── T352: inbox-loop regression controls ──────────────────────
    // Five controls: empty inbox is a no-op, a `tell` → read → ack →
    // record timeline runs with no human action between, an unread
    // directive surfaces in `managent resume` with a STALL marker and
    // an age, the INBOX LOOP paragraph is in BOTH dispatch prompts,
    // and the rendered dry-run prompt includes the worker instruction
    // (`managent inbox <id> --ack`).  Temp store only — never the live
    // docs/infra/managent/tasks.json.  Wired here because `zig build
    // test` is the acceptance gate for T352.
    const inbox_loop_regression = b.addSystemCommand(&.{ "sh", "tools/regression-inbox-loop.sh" });
    inbox_loop_regression.cwd = b.path(".");
    test_step.dependOn(&inbox_loop_regression.step);

    // ── T399: directive/JSON write-site integrity controls ────────────
    // Unescaped free text in JSON artifacts corrupted directives.jsonl
    // (lost directive, 2026-08-06) and tasks.json (fleet outage, same
    // day).  Nine controls against a scratch store: multi-line note
    // round-trips through tell/inbox, quotes/backslash/tab/trailing-
    // newline notes round-trip byte-exactly, the ack path re-escapes,
    // the store path (amend/dispatch/done --skip-acceptance/ping) stays
    // parseable, a single-line note is unaffected, and a deliberately
    // corrupted ledger line makes the reader warn while audit reports
    // it.  RED against the 2026-08-06 binary; wired because `zig build
    // test` is the acceptance gate for T399.
    const directive_integrity_regression = b.addSystemCommand(&.{ "sh", "tools/regression-directive-integrity.sh" });
    directive_integrity_regression.cwd = b.path(".");
    test_step.dependOn(&directive_integrity_regression.step);

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
    const integrity_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-integrity.sh" });
    integrity_regression.cwd = b.path(".");
    test_step.dependOn(&integrity_regression.step);

    // ── T352: T227 acceptance-check regression controls ────────────────
    // The 2026-08-01 T227 regression timed out (>120s) and was deferred by
    // T322 and T337 S5.  T352 diagnosed the hang (pre-flock mkdir mutex
    // leaked the store lock on acceptance-failure exits; fixed by T337 S0's
    // flock) and rewired the script onto the seeded in_progress pattern with
    // a wall-clock budget per `done` call (see tools/regression-T227.sh).
    // Three controls (signal-killed acceptance REJECTED, deliverables= stops
    // at the next key=, empty --skip-acceptance REJECTED) plus the live-
    // kanban byte-identity guard.  <4s wall, scratch store only.
    const t227_regression = b.addSystemCommand(&.{ "sh", "tools/regression-T227.sh" });
    t227_regression.cwd = b.path(".");
    test_step.dependOn(&t227_regression.step);

    // ── T446: ledger/board seam controls ──────────────────────────
    // The board and `next` must render what the assertion ledger asserts:
    // a `closed` assertion supersedes tasks.json's status so finished work
    // is neither shown dispatchable nor handed out by `next`.  Four arms:
    // dispatchable + closed → done (asserted), in_progress + closed → done
    // (asserted, no live claim), `next` never hands out a closed-asserted
    // row, and the null arm (no ledger file) leaves rendering and `next`
    // unchanged.  Scratch store + scratch ledger only — never the live
    // kanban.  Wired here because `zig build test` is the T446 gate.
    const ledger_board_seam_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-ledger-board-seam.sh" });
    ledger_board_seam_regression.cwd = b.path(".");
    test_step.dependOn(&ledger_board_seam_regression.step);

    // ── T518/F9: managent assert honors the MANAGENT_STORE override ──
    // The first regression to exercise `managent assert` *writing*; the
    // T497 ledger-board-seam regression seeds the ledger by hand and only
    // reads it. Four arms against a scratch store located OUTSIDE the fake
    // repo (so the store-override path is actually exercised):
    // assert writes the record to the SCRATCH ledger (not the repo-root
    // one) · show renders the (asserted) annotation by reading the SCRATCH
    // ledger (reader honors the override too) · the assertion_next counter
    // is persisted to the SCRATCH store · and the default-store arm
    // (MANAGENT_STORE unset) still writes to repo_root's ledger so the
    // default layout is preserved. Scratch store + scratch repo only —
    // never the live kanban or the live assertion ledger.
    const assert_store_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-assert-store.sh" });
    assert_store_regression.cwd = b.path(".");
    test_step.dependOn(&assert_store_regression.step);

    // ── T478: duty mechanism + landmark gate controls ──────────────────
    // Duties are beneficial work that never completes; managent must
    // recognise them (bundle meta `duty` key / --duty flag), count task
    // closes toward a per-duty due threshold, record chunks (`duty <UID>
    // done`), and gate `landmark <Ln> --declare` while any duty is overdue
    // or last-failed.  Six arms, scratch store only: 5 closes make a duty
    // due · overdue duty refuses + names · null (no duties) declares ·
    // chunk resets due-count · next never hands out a duty · last-failed
    // blocks even when not due.
    const duty_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-duty.sh" });
    duty_regression.cwd = b.path(".");
    test_step.dependOn(&duty_regression.step);

    // ── T545: store-writer flock controls ───────────────────────────
    // Three store writers took no flock over their whole read-modify-write
    // (cmdTell, the startup migration, standing) — the audit found two more
    // (cmdAssert read-outside-lock, cmdSync/writeSyncData no lock at all).
    // Any overlapping claim/close/attribution was SILENTLY REVERTED; the
    // observed incident: 4 tells in ~3 min with 14 workers live, zero
    // directives delivered, D042/D043 minted twice, directive_next 44 → 43.
    // Five arms against a scratch MANAGENT_STORE in a scratch repo (never
    // the live kanban): N concurrent tells → N distinct ids, counter +N ·
    // tell racing a claim → the claim survives (deterministic flock-hold) ·
    // migration read racing a done → the close survives · concurrent
    // standing + set → both survive · null single tell → one id.
    const concurrency_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-concurrency.sh" });
    concurrency_regression.cwd = b.path(".");
    test_step.dependOn(&concurrency_regression.step);

    // T496: fleet-keeper loop + cooldown flag controls (scratch store + scratch
    // repo). Fires oldest-eligible until the cap, cools down on a flag, and
    // the dead-man's switch treats an unreadable cooldown dir as cooldown.
    const fleet_keeper_regression = b.addSystemCommand(&.{ "sh", "tools/regression-fleet-keeper.sh" });
    fleet_keeper_regression.cwd = b.path(".");
    test_step.dependOn(&fleet_keeper_regression.step);

    const depth_regression = b.addSystemCommand(&.{ "sh", "tools/regression-depth-enforcement.sh" });
    depth_regression.cwd = b.path(".");
    test_step.dependOn(&depth_regression.step);

    const gcm_regression = b.addSystemCommand(&.{ "sh", "tools/regression-git-commit-mine.sh" });
    gcm_regression.cwd = b.path(".");
    test_step.dependOn(&gcm_regression.step);

    const gcm_hook_regression = b.addSystemCommand(&.{ "sh", "tools/regression-git-commit-mine-hook.sh" });
    gcm_hook_regression.cwd = b.path(".");
    test_step.dependOn(&gcm_hook_regression.step);

    // ── T547: commit-mutex + holds-check controls ──────────────────
    // The shared .git/index is a fleet-scale hazard even when the
    // one-writer invariant holds: two rows can legally hold disjoint
    // files and still collide at commit time (T521: 784235a absorbed
    // T531/T545's build.zig hunks + T512's regression-dispatch.sh arms
    // under the T521 message). Controls: two concurrent runs, one
    // commit delayed → each commit contains ONLY its own paths; a path
    // held by a different in_progress row → refused naming the holder;
    // --explicit → allowed and recorded loudly; single null; two
    // concurrent disjoint nulls; an external holder → short-timeout
    // refusal proves the flock is exclusive.
    const commit_concurrency_regression = b.addSystemCommand(&.{ "sh", "tools/regression-commit-concurrency.sh" });
    commit_concurrency_regression.cwd = b.path(".");
    test_step.dependOn(&commit_concurrency_regression.step);

    // ── T450: pilot-gate scratch-and-verify controls ─────────────────
    // The gate's whole value is that a failing run leaves nothing
    // behind (T447 found four races where it wrote live tracked
    // artifacts before the verification that gates them, and
    // `rm -f data/oracle-4x4.checkpoint.wzo` before a 20-min rebuild
    // with no restore path). Controls assert: (1) fast-branch null
    // — unmodified tree passes, live tree byte-identical after;
    // (2) fast-branch seeded — single-byte perturbation in scratch
    // is detected, live tree byte-identical; (3) --full restore
    // path — a stubbed rebuild that fails fast exits non-zero, EXIT
    // trap wipes scratch, live data/ byte-identical; (4) gate source
    // contract — no destructive ops (`rm -f data/oracle-4x4`,
    // `mv ...oracle-4x4.wzo.prev`), no retracted WANT hash
    // (b42c3371...), checks the canonical checkpoint (a2174fed...),
    // EXIT trap present, RETRO_SAVE_*_OUT routes scratch writes.
    // Control 1 (fast null) takes minutes because it rebuilds the
    // four small-goban artifacts from scratch — that is the cost
    // of a real null control, not a test defect.
    const pilot_gate_regression = b.addSystemCommand(&.{ "sh", "tools/regression-pilot-gate.sh" });
    pilot_gate_regression.cwd = b.path(".");
    test_step.dependOn(&pilot_gate_regression.step);

    // ── GTP boardsize desync controls (T403) ─────────────────────────
    // Seeded (red): after rejected boardsize in deferred mode, the GTP
    // session must stay alive — known_command genmove returns true and
    // showboard returns an informative message, not ? unknown command.
    // Null: correct launch path plays a full game.  SKIPs when
    // bin/weizigo-gtp or the 4x4 artifact are missing.
    const gtp_boardsize_regression = b.addSystemCommand(&.{ "sh", "tools/regression-gtp-boardsize.sh" });
    gtp_boardsize_regression.cwd = b.path(".");
    test_step.dependOn(&gtp_boardsize_regression.step);

    // ── resume-surface controls (T286) ───────────────────────────────
    // Null control (empty kanban + clean tree says NOTHING IN FLIGHT) and
    // seeded control (in_progress task + held file both appear). SKIPs
    // loudly when no managent binary with the resume command exists —
    // build with `zig build` first (same convention as the claimlint
    // control in regression-precommit.sh).
    const resume_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-resume.sh" });
    resume_regression.cwd = b.path(".");
    test_step.dependOn(&resume_regression.step);

    // ── orient-surface controls (T353) ───────────────────────────────
    // `managent orient` replaces the ~1,524-line worker reading list with a
    // generated, ≤150-line preamble composed at read time. Controls: null
    // (empty kanban + clean tree → exit 0, ≤150 lines, stated count == wc -l),
    // seeded-floor (perturb one floor value → orient shows the new number,
    // not a stored copy), seeded-row (a temp row appears under dispatchable,
    // then leaves the live surface when done), degradation (unbuildable
    // claimlint/hook degrade to explicit markers), structure (all six sections
    // present and ordered). Same SKIP convention as the resume regression:
    // no managent binary carrying `orient` → SKIP loudly.
    const orient_regression = b.addSystemCommand(&.{ "sh", "tools/regression-orient.sh" });
    orient_regression.cwd = b.path(".");
    test_step.dependOn(&orient_regression.step);

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

    // ── absorption-machinery controls (T406) ────────────────────────
    // The two broken safety nets T404 found: weizigo-absorb parses the
    // 11-column register as empty (silent "nothing to do") and STANDING-ABSORB
    // fires its trigger into a done row that can never become dispatchable
    // again. Controls: seeded 11-col (221 rows + directives), seeded 10-col
    // (loud empty-parse hard error naming the counts), null (nothing proposed
    // at zero backlog), gen-indices (second vacuous consumer: 221 indexed,
    // 0-claim parse refused), standing reopen (done→dispatchable), live
    // guard (no duplicate instance; refusal reads as inaction), family-wide
    // reopen (STANDING-REEVIDENCE), standing null (C7=0 → no counter moves).
    // Same SKIP convention as the standing/resume regressions: no built
    // binary, or no deployed claimlint to copy into the scratch repo → SKIP.
    const absorption_machinery_regression = b.addSystemCommand(&.{ "sh", "tools/regression-absorption-machinery.sh" });
    absorption_machinery_regression.cwd = b.path(".");
    test_step.dependOn(&absorption_machinery_regression.step);

    // ── T337 S0: managent store-lock controls ──────────────────────
    // Replaces the mkdir mutex (which leaked on every exit(1) after
    // lock acquisition) with flock(2): the kernel releases the lock
    // on ANY process termination.  Two controls: (1) rejection path
    // releases lock, (2) SIGKILL holder → next command succeeds.
    const lock_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-lock.sh" });
    lock_regression.cwd = b.path(".");
    test_step.dependOn(&lock_regression.step);

    // ── T350: cmdDone two-phase lock controls ────────────────────
    // The flock covers the store mutation (validate → attribute → git
    // deliverable check → write done) but never the acceptance command's
    // runtime; on acceptance failure the done write is reverted under a
    // fresh lock and dependents re-blocked.  Controls: acceptance pass
    // keeps done · acceptance fail reverts to in_progress + re-blocks ·
    // nested store write succeeds during phase 2 (proves the lock is
    // released) and the vanish guard fires · --skip-acceptance closes ·
    // empty skip reason rejected before the write.
    const done_two_phase_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-done-two-phase.sh" });
    done_two_phase_regression.cwd = b.path(".");
    test_step.dependOn(&done_two_phase_regression.step);

    // ── T522: impression-or-waiver gate controls ──────────────────
    // `managent done` must demand a model impression or an explicit
    // waiver at every close (G6 / measurement-methodology §6), so
    // model-perf cannot lapse silently.  Seeded arms: neither flag →
    // refused · both flags → refused · empty impression → refused.
    // Null arms: --impression records the field · --impression-waiver
    // records the reason · blocked close is gated too (a stall is a
    // model datum).  Same SKIP convention: no built claimlint → SKIP.
    const impression_gate_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-impression-gate.sh" });
    impression_gate_regression.cwd = b.path(".");
    test_step.dependOn(&impression_gate_regression.step);

    // ── T516: status --json added/claim_count controls ───────────────
    // F7: `status --json` omitted `added` (registration ts) and
    // `claim_count` (per-row claim tally), forcing the keeper to shell out
    // to `show` for two fields the dashboard wants inline. Four arms,
    // scratch store only: claimed task exposes added + claim_count==1 ·
    // dispatchable task exposes added + claim_count==0 · re-claimed task
    // exposes claim_count==2 · byte-identity guard (status --json never
    // mutates tasks.json). RED against the pre-T516 binary, GREEN after.
    const status_json_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-status-json.sh" });
    status_json_regression.cwd = b.path(".");
    test_step.dependOn(&status_json_regression.step);

    // ── T517: canonical model list exposed (`managent models`) ───────
    // F7: model canonicalization was ×4 with four definitions (managent
    // canonical_models[], bin/dispatch MODELS, bin/subagent CLAUDE_MODELS,
    // watch-fleet mdl()), and the keeper's least-data picker listed only the
    // five non-Claude models — so a model-less row could never draw a Claude
    // label. This wires the regression that asserts `managent models` (and
    // `--json`) exposes canonical_models[] verbatim as the single source the
    // keeper/dispatch/subagent can shell out to: prints exactly the source
    // array (no drift), valid --json, stdout/stderr split, every Claude
    // label present, and a pure-static arm (no kanban store touched,
    // callable with no repo). RED against the pre-T517 binary, GREEN after.
    const models_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-models.sh" });
    models_regression.cwd = b.path(".");
    test_step.dependOn(&models_regression.step);

    // ── T539: holds= writer + --sync + vacuous-case controls ────────
    // The one-writer invariant was vacuous: 34 of 49 rows whose bundle
    // declared holds= had "holds": [] in the store, so holdsConflict
    // compared empty sets and always passed.  Controls: add parses
    // holds= (comma-split), --holds a,b writes rows without a bundle
    // holds, holds --sync reconciles stale rows idempotently, and a
    // claim/dispatch whose store holds is empty but whose bundle declares
    // holds warns loudly instead of silently reporting "no conflict".
    const holds_regression = b.addSystemCommand(&.{ "sh", "tools/regression-managent-holds.sh" });
    holds_regression.cwd = b.path(".");
    test_step.dependOn(&holds_regression.step);

    // ── T542: grand-race bake-off gate controls (G1/G2/G3/G4) ─────
    // G5 already held; G6 is T522's. Controls pin: G1 tokens (trailer
    // reading wins over token-capture.py; null + reason when absent; the
    // field is present, never absent), G2 isolation (main checkout -> exit 2
    // naming G2; a real worktree with keys outside proceeds; --allow-
    // unisolated records the override + reason), G3 family exclusion
    // (count_grade hard-refuses a family grade; retained in the record; the
    // family is the model family, not the dispatch family), and G4 blinding
    // (self-identifying text redacted into out.sanitized.md, original never
    // modified, lane flagged; a clean lane's sanitized copy is byte-identical
    // and unflagged). Every lane is a fake `pi` shim — no real model runs,
    // no credentials read. Scratch worktree + scratch run dirs only.
    const bakeoff_gates_regression = b.addSystemCommand(&.{ "sh", "tools/regression-bakeoff-gates.sh" });
    bakeoff_gates_regression.cwd = b.path(".");
    test_step.dependOn(&bakeoff_gates_regression.step);

    // ── T521: mechanical token capture controls (the capture path) ──
    // G1 is run-time, not retroactive (D043): tokens are captured at
    // dispatch or lost — every prior race ended at n=0 readings.  The
    // controls pin the capture path against fake claude/pi shims in a
    // scratch repo (never the live tree, never credentials): the claude
    // JSON envelope parse (text + usage), the runner's per-lane trailer
    // tokens line + run-record stamp + unwrapped stdout, the per-task raw
    // tee, the ledger (a reading or an explicit missing-with-reason,
    // never a blank cell), and the G1 `--json --cwd --since` models map
    // (ledger wins for claude; the pi session scan fills pi labels).
    const token_capture_regression = b.addSystemCommand(&.{ "sh", "tools/regression-token-capture.sh" });
    token_capture_regression.cwd = b.path(".");
    test_step.dependOn(&token_capture_regression.step);

    // ── T552: session-handle capture controls ────────────────────────
    // Every dispatch discards the resumable session id, so a follow-up
    // question to a worker costs a fresh context that reads its own prior
    // work as a stranger's.  The controls pin the capture: a seeded claude
    // envelope's session_id lands on all three token surfaces (run record,
    // lane trailer, ledger line); an envelope without the field and a pi
    // lane with no envelope at all record null + reason — never a blank,
    // never an invented id — and a normal dispatch is unchanged beyond the
    // extra field.  The resume round trip (dispatch, exit, resume the
    // captured id) is a MANUAL arm: it needs real credentials, which these
    // controls never touch (T521 rule); proven irl in findings/T552.
    const session_capture_regression = b.addSystemCommand(&.{ "sh", "tools/regression-session-capture.sh" });
    session_capture_regression.cwd = b.path(".");
    test_step.dependOn(&session_capture_regression.step);

    // ── T529: grand-race P0 gate controls ────────────────────────
    // The P0 gate (tools/race-p0-verify.sh) is the one command that says
    // GO/NO-GO before a race starts: sealed keys and packets, the frozen
    // fixture stores, the roster, and the two G2 halves — no key material
    // reachable from the run root, and no lane transcript showing a lane
    // acting on one.  Controls: an untouched copy of a store still matches
    // its seal (the MANIFEST's tar seal does NOT, which is why the seal is
    // content-based), a flipped byte is caught, a planted key.txt is
    // caught, a lane that reads a key is caught, and a packet brief that
    // merely NAMES the key path is not counted as a lane action.  The
    // sealed packets live under untracked/, so the live-tree GO/NO-GO arms
    // skip loudly on a fresh clone while the controls always run.
    const race_p0_regression = b.addSystemCommand(&.{ "sh", "tools/regression-race-p0.sh" });
    race_p0_regression.cwd = b.path(".");
    test_step.dependOn(&race_p0_regression.step);

    // ── T390: duplicate-dispatch controls ────────────────────────
    // Two consoles on one row happened three times on 2026-08-05/06
    // (T376/T389/T350); the kanban shows claim-at-close is the disease
    // (claims and done recorded back-to-back, so no concurrency safeguard
    // ever saw the row).  Controls: second dispatch refuses naming the
    // holder, --force re-dispatches loudly, claim on a claimed row refuses
    // with holder+timestamp, done within 10s of claim refuses (--force
    // closes), audit reports dirty deliverables on done/dispatchable rows.
    const dup_dispatch_regression = b.addSystemCommand(&.{ "sh", "tools/regression-duplicate-dispatch.sh" });
    dup_dispatch_regression.cwd = b.path(".");
    test_step.dependOn(&dup_dispatch_regression.step);

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

    // ── claimlint volatile-evidence controls (T421) ─────────────────
    // C10 VOLATILE: a fixture doc citing an EXISTING /tmp path must be
    // reported (the whole defect — C2 only sees missing paths), the
    // run's exit status must not change (report-only), and the output
    // must be byte-identical to baseline once the fixture is removed.
    // SKIPs loudly when no claimlint binary in zig-out/bin/.
    const claimlint_volatile_regression = b.addSystemCommand(&.{ "sh", "tools/regression-claimlint-volatile.sh" });
    claimlint_volatile_regression.cwd = b.path(".");
    test_step.dependOn(&claimlint_volatile_regression.step);

    // ── T482: claimlint c7 --json controls ─────────────────────
    // The `c7 --json` verb is the spec §7 machine-readable consumption
    // surface for `managent done` (T485). Three arms: c7-json-shape
    // asserts the eight-field contract (path, task_id, conforming,
    // conforming_reason, claims_total, new_rows_total, unabsorbed,
    // dispositioned); c7-json-counts asserts the per-file JSON counts
    // agree with the human-readable C7 block (one count, one
    // implementation); c7-nonconf-exits asserts a non-conforming file
    // alone makes `c7 --json` exit 1 (the spec §6.1 promotion that
    // closed the T454 illusion). The fixture is added and removed in
    // place; a SIGKILL trap (T448 pattern) wipes it on every exit.
    const claimlint_c7_json_regression = b.addSystemCommand(&.{ "sh", "tools/regression-claimlint-c7-json.sh" });
    claimlint_c7_json_regression.cwd = b.path(".");
    test_step.dependOn(&claimlint_c7_json_regression.step);

    // ── claim/close lifecycle controls (T424) ────────────────────────
    // Five flakes, one symptom (the kanban disagrees with reality):
    // worked-without-claiming (git-commit-mine refuses a commit whose task
    // is not in_progress), post-close corrections (amend --post-close +
    // reopen names amend instead of dead-ending + audit WARNs amended rows),
    // add --note round-trip, forced closes leave a FORCED amendment, and C10
    // no longer counts paths inside fenced code blocks. All managent arms
    // run against a scratch store in /tmp/weizigo — never the live kanban;
    // the claimlint arm uses a fixture doc created and removed in place.
    // SKIPs loudly when no managent/claimlint binary in zig-out/bin/.
    const claim_lifecycle_regression = b.addSystemCommand(&.{ "sh", "tools/regression-claim-lifecycle.sh" });
    claim_lifecycle_regression.cwd = b.path(".");
    test_step.dependOn(&claim_lifecycle_regression.step);

    // ── argus --mode doctor controls (T425, hardened by T427) ────────
    // The Orchestrator's manual weekly sweep encoded as a one-line check.
    // Sixteen arms: smoke, uncommitted files, dispatchable row with
    // uncommitted bundle, non-conforming findings, C7 unabsorbed visible,
    // C10 volatile citations, deploy staleness, in_progress with no
    // heartbeat, register/tree-map lockstep, floor counters, CAN CLOSE
    // (info), fixture-row detection in the kanban (T427), the managent
    // live-write guards (fixture-pattern add + MANAGENT_TEST tripwire,
    // tested against a fake repo), no-false-alarm on the real store, and
    // the null control: live tasks.json byte-identical before/after. All
    // managent calls run against a scratch store (MANAGENT_STORE) seeded
    // from the live store; the live kanban is never written. Reads
    // bin/argus (a Python script shipped at HEAD, not a built binary); the
    // SKIP convention is identical to the other regressions — missing
    // argus/managent/claimlint → SKIP loudly.
    const argus_doctor_regression = b.addSystemCommand(&.{ "sh", "tools/regression-argus-doctor.sh" });
    argus_doctor_regression.cwd = b.path(".");
    test_step.dependOn(&argus_doctor_regression.step);

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

    // ── verify-battery: independent move generator (vb_movegen, T340) ─
    const vb_movegen_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_movegen.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_movegen_tests.root_module.import_table = .{};
    const run_vb_movegen_tests = b.addRunArtifact(vb_movegen_tests);
    run_vb_movegen_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_movegen_tests.step);

    // ── verify-battery: closure (vb_closure, T342) ────────────────
    const vb_closure_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_closure.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_closure_tests.root_module.addImport("engine", engine_mod);
    const run_vb_closure_tests = b.addRunArtifact(vb_closure_tests);
    run_vb_closure_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_closure_tests.step);

    // ── verify-battery: battery health (vb_health, T347) ─────────
    const vb_health_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_health.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_health_tests.root_module.import_table = .{};
    const run_vb_health_tests = b.addRunArtifact(vb_health_tests);
    run_vb_health_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_health_tests.step);

    // ── verify-battery: Bellman residual (vb_bellman_4x4, T343) ──
    const vb_bellman_4x4_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_bellman_4x4.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_bellman_4x4_tests.root_module.import_table = .{};
    const run_vb_bellman_4x4_tests = b.addRunArtifact(vb_bellman_4x4_tests);
    run_vb_bellman_4x4_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_bellman_4x4_tests.step);

    // ── verify-battery: SCC containment (vb_scc_4x4, T344) ───────
    const vb_scc_4x4_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_scc_4x4.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_scc_4x4_tests.root_module.import_table = .{};
    const run_vb_scc_4x4_tests = b.addRunArtifact(vb_scc_4x4_tests);
    run_vb_scc_4x4_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_scc_4x4_tests.step);

    // ── verify-battery: I5 cross-size differential (T391) ────────────
    // Runs both I5 implementations (vb_graph general, vb_scc_4x4
    // size-specific) on the same artifact and requires identical readings.
    // The 4×3 cell is env-gated (WEIZIGO_I5_DIFF_4X3=1): linking both
    // instruments in one binary pushes the ReleaseFast codegen past the
    // tools/runner RSS cap (T391; see the test's comment).
    const i5_diff_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/i5_differential.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_i5_diff_tests = b.addRunArtifact(i5_diff_tests);
    run_i5_diff_tests.cwd = b.path(".");
    test_step.dependOn(&run_i5_diff_tests.step);

    // ── I4 cross-engine differential (T395, T388 D1) ────────────────────
    // Runs the two WZO2 Φ operators — vb_bellman_4x4.i4Bellman (R8 move
    // engine) and oracle_v2_accept.checkA2 (kernel rules.Rules) — on the
    // same 3×3 WZO2 artifact and requires identical denominator, zero
    // violations on both sides, and identical missing-child counts. D1
    // (T388): three independent I4 implementations with no overlap cell;
    // this closes the cheapest one. The general WZO1 check shares no
    // artifact with either WZO2 engine (different builds), recorded in
    // docs/infra/property-ownership.md.
    const i4_diff_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/i4_differential.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_i4_diff_tests = b.addRunArtifact(i4_diff_tests);
    run_i4_diff_tests.cwd = b.path(".");
    test_step.dependOn(&run_i4_diff_tests.step);

    // ── key-byte decode differential + F-7 control (T395, T383 F-7) ─────
    // Runs the closure instrument's production key-byte decode against the
    // artifact2 contract over all 256 key bytes × ko_bits {3,4,5}, plus the
    // seeded-defect control showing the historical kb>>1 decode (F-7) makes
    // the differential fire. Needs the engine module because vb_closure
    // imports it (same as vb_closure_tests).
    const keybyte_diff_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/keybyte_differential.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    keybyte_diff_tests.root_module.addImport("engine", engine_mod);
    const run_keybyte_diff_tests = b.addRunArtifact(keybyte_diff_tests);
    run_keybyte_diff_tests.cwd = b.path(".");
    test_step.dependOn(&run_keybyte_diff_tests.step);

    // ── verify-battery: move-set consistency (vb_i11, T346) ──────
    const vb_i11_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vb_i11.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    vb_i11_tests.root_module.addImport("engine", engine_mod);
    const run_vb_i11_tests = b.addRunArtifact(vb_i11_tests);
    run_vb_i11_tests.cwd = b.path(".");
    test_step.dependOn(&run_vb_i11_tests.step);

    // ── SMD1 tool tests (tools/smd1.zig, T341) ──────────────────
    const smd1_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/smd1.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    smd1_tests.root_module.addImport("engine", engine_mod);
    const run_smd1_tests = b.addRunArtifact(smd1_tests);
    run_smd1_tests.cwd = b.path(".");
    test_step.dependOn(&run_smd1_tests.step);

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
            .link_libc = true,
        }),
    });
    claimlint_exe.root_module.addImport("version", version_mod);
    claimlint_exe.root_module.addImport("claims_register", b.createModule(.{
        .root_source_file = b.path("src/claims_register.zig"),
        .target = target,
        .optimize = optimize,
    }));
    claimlint_exe.root_module.addImport("absorb", b.createModule(.{
        .root_source_file = b.path("src/absorb.zig"),
        .target = target,
        .optimize = optimize,
    }));
    b.installArtifact(claimlint_exe);

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

    // ── deploy weizigo-gtp to bin/weizigo-oracle (alias, T534) ─────
    // gtp.zig's own GTP `name` command replies "weizigo-oracle" (T263) —
    // that's the identity duty docs and specs (DRPLAY, argus checklist,
    // argus design) invoke it under. It reached bin/ only via a manual
    // `zig build-exe -femit-bin=bin/weizigo-oracle` (B40), so committed
    // source changes never redeployed it and it went stale (BadMagic on
    // the current .wzo2 artifact, T534). Same binary, same deploy
    // recipe, second destination name — no second compile needed.
    const oracle_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-gtp", "bin/weizigo-oracle" });
    oracle_deploy.step.dependOn(b.getInstallStep());
    const deploy_oracle_step = b.step("deploy-oracle", "Deploy weizigo-gtp to bin/weizigo-oracle (remove-copy-sign)");
    deploy_oracle_step.dependOn(&oracle_deploy.step);

    // ── weizigo-arena (adversarial self-play audit, T534) ──────────
    // Previously built only by hand (`zig build-exe src/arena.zig
    // -femit-bin=bin/weizigo-arena`, B43) — never wired into build.zig,
    // so it never got a deploy step and went stale the same way as
    // weizigo-oracle above.
    const arena_exe = b.addExecutable(.{
        .name = "weizigo-arena",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/arena.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    arena_exe.root_module.addImport("version", version_mod);
    b.installArtifact(arena_exe);

    // ── deploy weizigo-arena to bin/ ────────────────────────────────
    const arena_deploy = b.addSystemCommand(&.{ "sh", "tools/deploy.sh", "zig-out/bin/weizigo-arena", "bin/weizigo-arena" });
    arena_deploy.step.dependOn(b.getInstallStep());
    const deploy_arena_step = b.step("deploy-arena", "Deploy weizigo-arena to bin/ (remove-copy-sign)");
    deploy_arena_step.dependOn(&arena_deploy.step);

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
    deploy_step.dependOn(&managent_deploy.step);
    deploy_step.dependOn(&gtp_deploy.step);
    deploy_step.dependOn(&oracle_deploy.step);
    deploy_step.dependOn(&arena_deploy.step);
    deploy_step.dependOn(&claimlint_deploy.step);
    deploy_step.dependOn(&chainability_deploy.step);
    deploy_step.dependOn(&evse_deploy.step);
    deploy_step.dependOn(&reachcensus_deploy.step);
}
