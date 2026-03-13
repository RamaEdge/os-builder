/// Integration tests for exit code contract (0/1/2).
///
/// These tests verify the numeric exit codes that downstream CI pipelines depend on:
/// - verify nonexistent path -> exit 2
/// - inspect nonexistent path -> exit 2
use assert_cmd::cargo::cargo_bin_cmd;

#[test]
fn verify_nonexistent_path_exits_2() {
    cargo_bin_cmd!("edgeworks-bundle")
        .args(["verify", "/tmp/definitely-does-not-exist-xyzzy-bundle-99999"])
        .assert()
        .code(2);
}

#[test]
fn inspect_nonexistent_path_exits_2() {
    cargo_bin_cmd!("edgeworks-bundle")
        .args(["inspect", "/tmp/definitely-does-not-exist-xyzzy-bundle-99999"])
        .assert()
        .code(2);
}
