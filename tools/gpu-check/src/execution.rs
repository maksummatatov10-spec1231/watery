//! Executes translated production kernels, then checks readback against input-derived expectations.
use std::{fs, path::Path, sync::mpsc};
use wgpu::util::DeviceExt;
pub(crate) fn buffer(
    device: &wgpu::Device,
    bytes: &[u8],
    usage: wgpu::BufferUsages,
) -> wgpu::Buffer {
    device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: None,
        contents: bytes,
        usage,
    })
}
fn words(values: &[u32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
pub(crate) fn read(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    src: &wgpu::Buffer,
) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let dst = device.create_buffer(&wgpu::BufferDescriptor {
        label: None,
        size: src.size(),
        usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });
    let mut encoder = device.create_command_encoder(&Default::default());
    encoder.copy_buffer_to_buffer(src, 0, &dst, 0, src.size());
    queue.submit([encoder.finish()]);
    let (tx, rx) = mpsc::channel();
    dst.map_async(wgpu::MapMode::Read, .., move |r| {
        let _ = tx.send(r);
    });
    device.poll(wgpu::PollType::wait_indefinitely())?;
    rx.recv()??;
    let bytes = dst.get_mapped_range(..)?.to_vec();
    dst.unmap();
    Ok(bytes)
}
pub(crate) fn dispatch(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    root: &Path,
    name: &str,
    buffers: &[&wgpu::Buffer],
    pc: &[u32],
    groups: u32,
) -> Result<(), Box<dyn std::error::Error>> {
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    let source = fs::read_to_string(root.join("generated/shaders").join(format!("{name}.wgsl")))?;
    let has_constants = source.contains("@group(1)");
    let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some(name),
        source: wgpu::ShaderSource::Wgsl(source.into()),
    });
    let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some(name),
        layout: None,
        module: &module,
        entry_point: Some("main"),
        compilation_options: Default::default(),
        cache: None,
    });
    let entries: Vec<_> = buffers
        .iter()
        .enumerate()
        .map(|(i, b)| wgpu::BindGroupEntry {
            binding: i as u32,
            resource: b.as_entire_binding(),
        })
        .collect();
    let bindings = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: None,
        layout: &pipeline.get_bind_group_layout(0),
        entries: &entries,
    });
    let constants = buffer(device, &words(pc), wgpu::BufferUsages::UNIFORM);
    let push = has_constants.then(|| {
        device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &pipeline.get_bind_group_layout(1),
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: constants.as_entire_binding(),
            }],
        })
    });
    let mut encoder = device.create_command_encoder(&Default::default());
    {
        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&pipeline);
        pass.set_bind_group(0, &bindings, &[]);
        if let Some(push) = &push {
            pass.set_bind_group(1, push, &[]);
        }
        pass.dispatch_workgroups(groups, 1, 1);
    }
    queue.submit([encoder.finish()]);
    device.poll(wgpu::PollType::wait_indefinitely())?;
    if let Some(e) = pollster::block_on(scope.pop()) {
        return Err(e.into());
    }
    Ok(())
}
pub fn run(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    root: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    let storage = wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC;
    let mut globals = watery_core::uniforms::Globals::zeroed();
    globals.caps = [1000, 200, 0, 0];
    globals.matB[2] = 3.0;
    let mut bytes = vec![0; watery_core::uniforms::Globals::BYTE_SIZE];
    globals.write_le(&mut bytes).unwrap();
    let uniform = buffer(device, &bytes, wgpu::BufferUsages::UNIFORM);
    for count in [0u32, 1, 255, 256, 257, 1000, 1001] {
        let counters = buffer(
            device,
            &words(&[count, 0, 201, 0, 1001, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
            storage,
        );
        let args = buffer(device, &words(&[0xFFFF_FFFF; 28]), storage);
        dispatch(
            device,
            queue,
            root,
            "args",
            &[&uniform, &counters, &args],
            &[0, 2, 0, 0, 0, 0, 0, 0],
            1,
        )?;
        let actual = read(device, queue, &args)?;
        let actual: Vec<u32> = actual
            .as_chunks::<4>()
            .0
            .iter()
            .map(|v| u32::from_le_bytes(*v))
            .collect();
        let n = count.min(1000);
        let expected = [
            n.div_ceil(256).max(1),
            1,
            1,
            0,
            1,
            1,
            1,
            0,
            6,
            1000,
            0,
            0,
            6,
            n,
            0,
            0,
            6,
            200,
            0,
            0,
            18,
            n,
            0,
            0,
            6,
            0,
            0,
            0,
        ];
        assert_eq!(actual, expected, "args input count={count}");
        let clamped = read(device, queue, &counters)?;
        assert_eq!(&clamped[..4], &n.to_le_bytes());
        assert_eq!(&clamped[8..12], &200u32.to_le_bytes());
    }
    // Lower bounds inclusive, upper bounds exclusive. Also dispatch padding:
    // index 5 lies inside the removal box but outside the live counter.
    globals.removeInfo[0] = 1;
    globals.removeBox[0] = [0.0, 0.0, 0.0, 0.0];
    globals.removeBox[1] = [1.0, 1.0, 1.0, 0.0];
    globals.write_le(&mut bytes).unwrap();
    let uniform = buffer(device, &bytes, wgpu::BufferUsages::UNIFORM);
    let positions = [
        [0.0f32, 0.0, 0.0],
        [0.5, 0.5, 0.5],
        [1.0, 0.5, 0.5],
        [-0.001, 0.5, 0.5],
        [0.5, 1.0, 0.5],
        [0.5, 0.5, 0.5],
    ];
    let original: Vec<u8> = positions
        .iter()
        .flat_map(|p| [p[0], p[1], p[2], 2.0, 3.0, 4.0, 5.0, 6.0])
        .flat_map(|v| v.to_le_bytes())
        .collect();
    let particles = buffer(device, &original, storage);
    let counters = buffer(device, &words(&[5; 16]), storage);
    dispatch(
        device,
        queue,
        root,
        "remove",
        &[&uniform, &particles, &counters],
        &[0; 8],
        1,
    )?;
    let mut expected = original;
    for i in [0, 1] {
        expected[i * 32 + 12..i * 32 + 16].copy_from_slice(&(-1.0f32).to_le_bytes());
    }
    assert_eq!(
        read(device, queue, &particles)?,
        expected,
        "removal must change only live, in-box position.w"
    );
    println!(
        "GPU execution: args capacity/dispatch boundaries and particle removal bounds/padding PASS"
    );
    Ok(())
}
