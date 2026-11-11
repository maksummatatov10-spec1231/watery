#[test]
fn horizon_reads_development_package() {
    let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let path = manifest_dir.join("../artifacts/watery-1.2.2-dev.1.hnmod");
    let package = horizon_mods::index::native::Bundle::read(&path)
        .expect("actual Horizon native reader must accept the package");

    assert_eq!(package.manifest.id, "watery");
    assert_eq!(package.manifest.version, "1.2.2-dev.1");
    for suffix in [
        "api/src/lib.rs",
        "api/src/frame.rs",
        "api/core/src/lib.rs",
        "api/gpu/src/lib.rs",
        "api/data/shaders/composite_frag.wgsl",
        "api/data/original-assets/watery/shaders/common.glsl",
        "api/LICENSE",
        "api/NOTICE",
    ] {
        assert!(
            package.files.keys().any(|path| path.ends_with(suffix)),
            "development package is missing {suffix}"
        );
    }

    let root_copy = manifest_dir.join("../watery-1.2.2-dev.1.hnmod");
    assert_eq!(
        std::fs::read(&path).expect("canonical artifact is readable"),
        std::fs::read(root_copy).expect("root convenience copy is readable"),
        "root-level package copy must match artifacts/"
    );
    println!(
        "Horizon native package reader: PASS ({} entries)",
        package.files.len()
    );
}
