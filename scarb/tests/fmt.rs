use std::fs;

use assert_fs::prelude::*;
use assert_fs::TempDir;
use indoc::indoc;

use scarb_test_support::command::Scarb;
use scarb_test_support::project_builder::ProjectBuilder;
use scarb_test_support::workspace_builder::WorkspaceBuilder;

const SIMPLE_ORIGINAL: &str = r"fn main()    ->    felt252      {      42      }";
const SIMPLE_FORMATTED: &str = indoc! {r#"
    fn main() -> felt252 {
        42
    }
    "#
};

fn build_temp_dir(data: &str) -> TempDir {
    let t = assert_fs::TempDir::new().unwrap();
    t.child("Scarb.toml")
        .write_str(
            r#"
            [package]
            name = "hello"
            version = "0.1.0"
            "#,
        )
        .unwrap();
    t.child("src/lib.cairo").write_str(data).unwrap();

    t
}

#[test]
fn simple_check_invalid() {
    let t = build_temp_dir(SIMPLE_ORIGINAL);
    Scarb::quick_snapbox()
        .arg("fmt")
        .arg("--check")
        .arg("--no-color")
        .current_dir(&t)
        .assert()
        .failure()
        .stdout_matches(indoc! {"\
            Diff in [..]/src/lib.cairo:
             --- original
            +++ modified
            @@ -1 +1,3 @@
            -fn main()    ->    felt252      {      42      }
            / No newline at end of file
            +fn main() -> felt252 {
            +    42
            +}

            "});
    let content = fs::read_to_string(t.child("src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_ORIGINAL);
}

#[test]
fn simple_check_valid() {
    let t = build_temp_dir(SIMPLE_FORMATTED);
    Scarb::quick_snapbox()
        .arg("fmt")
        .arg("--check")
        .current_dir(&t)
        .assert()
        .success();
}

#[test]
fn simple_format() {
    let t = build_temp_dir(SIMPLE_ORIGINAL);
    Scarb::quick_snapbox()
        .arg("fmt")
        .current_dir(&t)
        .assert()
        .success();

    assert!(t.child("src/lib.cairo").is_file());
    let content = fs::read_to_string(t.child("src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_FORMATTED);
}

#[test]
fn simple_format_with_filter() {
    let t = build_temp_dir(SIMPLE_ORIGINAL);
    Scarb::quick_snapbox()
        .args(["fmt", "--package", "world"])
        .current_dir(&t)
        .assert()
        .failure()
        .stdout_eq("error: package `world` not found in workspace\n");

    assert!(t.child("src/lib.cairo").is_file());
    let content = fs::read_to_string(t.child("src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_ORIGINAL);

    Scarb::quick_snapbox()
        .args(["fmt", "--package", "hell*"])
        .current_dir(&t)
        .assert()
        .success();

    assert!(t.child("src/lib.cairo").is_file());
    let content = fs::read_to_string(t.child("src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_FORMATTED);
}

#[test]
fn workspace_with_root() {
    let t = TempDir::new().unwrap().child("test_workspace");
    let pkg1 = t.child("first");
    ProjectBuilder::start()
        .name("first")
        .lib_cairo(SIMPLE_ORIGINAL)
        .build(&pkg1);
    let pkg2 = t.child("second");
    ProjectBuilder::start()
        .name("second")
        .lib_cairo(SIMPLE_ORIGINAL)
        .dep("first", r#"path = "../first""#)
        .build(&pkg2);
    let root = ProjectBuilder::start()
        .name("some_root")
        .lib_cairo(SIMPLE_ORIGINAL)
        .dep("first", r#"path = "./first""#)
        .dep("second", r#"path = "./second""#);
    WorkspaceBuilder::start()
        .add_member("first")
        .add_member("second")
        .package(root)
        .build(&t);

    Scarb::quick_snapbox()
        .arg("fmt")
        .current_dir(&t)
        .assert()
        .success();

    let content = fs::read_to_string(t.child("src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_FORMATTED);
    let content = fs::read_to_string(t.child("first/src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_ORIGINAL);
    let content = fs::read_to_string(t.child("second/src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_ORIGINAL);

    Scarb::quick_snapbox()
        .args(["fmt", "--workspace"])
        .current_dir(&t)
        .assert()
        .success();

    let content = fs::read_to_string(t.child("src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_FORMATTED);
    let content = fs::read_to_string(t.child("first/src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_FORMATTED);
    let content = fs::read_to_string(t.child("second/src/lib.cairo")).unwrap();
    assert_eq!(content, SIMPLE_FORMATTED);
}
