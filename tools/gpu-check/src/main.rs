//! Actual device pipeline validation, not a physics equivalence benchmark.
mod execution;
mod fluid;
mod mpm;
mod multilevel;
mod pressure_oracle;
mod whitewater;
mod surface;
mod render;
use std::{fs, path::Path};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let mut descriptor = wgpu::InstanceDescriptor::new_without_display_handle();
    descriptor.backends = wgpu::Backends::PRIMARY;
    let instance = wgpu::Instance::new(descriptor);
    let adapter =
        pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions::default()))?;
    let mut report = format!(
        "# GPU pipeline validation\n\nAdapter: {:?}\n\nPipeline creation and limited simulation regressions, not physics equivalence or performance measurement. Full adapter limits are requested; Horizon's device configuration must still be checked.\n\n",
        adapter.get_info()
    );
    let features = adapter.features() & wgpu::Features::SUBGROUP;
    let (device, queue) = pollster::block_on(adapter.request_device(&wgpu::DeviceDescriptor {
        label: Some("Watery pipeline validation"),
        required_features: features,
        required_limits: adapter.limits(),
        ..Default::default()
    }))?;
    let mut paths: Vec<_> = fs::read_dir(root.join("generated/shaders"))?
        .map(|e| e.map(|e| e.path()))
        .collect::<Result<_, _>>()?;
    paths.sort();
    let (mut passed, mut failed) = (0, 0);
    for path in paths
        .into_iter()
        .filter(|p| p.extension().is_some_and(|e| e == "wgsl")
            && !p.file_stem().unwrap().to_string_lossy().ends_with("_vert")
            && !p.file_stem().unwrap().to_string_lossy().ends_with("_frag"))
    {
        let name = path.file_name().unwrap().to_string_lossy();
        let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some(&name),
            source: wgpu::ShaderSource::Wgsl(fs::read_to_string(&path)?.into()),
        });
        let _pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: Some(&name),
            layout: None,
            module: &shader,
            entry_point: Some("main"),
            compilation_options: Default::default(),
            cache: None,
        });
        if let Some(error) = pollster::block_on(scope.pop()) {
            report.push_str(&format!("FAIL {name}\n```text\n{error}\n```\n\n"));
            failed += 1;
        } else {
            report.push_str(&format!("PASS {name}\n\n"));
            passed += 1;
        }
    }
    report.push_str(&format!("Total: {passed} passed, {failed} failed.\n"));
    if failed == 0 {
        // Persist pipeline results even if an execution regression later fails.
        fs::write(root.join("reference/gpu-check-report.md"), &report)?;
        for (name, result) in [
            ("args/removal", execution::run(&device, &queue, &root)),
            ("MPM sand", mpm::run(&device, &queue, &root)),
            ("FLIP/slime", fluid::run(&device, &queue)),
            ("multilevel FLIP", multilevel::run(&device, &queue)),
            ("whitewater", whitewater::run(&device, &queue)),
            ("surface", surface::run(&device, &queue)),
            ("graphics", render::run(&device, &queue)),
        ] {
            match result {
                Ok(()) => report.push_str(&format!("\nPASS execution: {name}\n")),
                Err(error) => {
                    report.push_str(&format!("\nFAIL execution: {name}: {error}\n"));
                    fs::write(root.join("reference/gpu-check-report.md"), &report)?;
                    return Err(error);
                }
            }
        }
    }
    fs::write(root.join("reference/gpu-check-report.md"), report)?;
    println!("GPU pipelines: {passed} passed, {failed} failed; reference/gpu-check-report.md");
    if failed != 0 {
        std::process::exit(1);
    }
    Ok(())
}
