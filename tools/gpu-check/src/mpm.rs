//! Original five-pass sand timestep regression. Not yet an in-game host.
use crate::execution::{buffer, dispatch, read};
use std::path::Path;
use watery_core::uniforms::Globals;

fn floats(values: &[f32]) -> Vec<u8> {
    values.iter().flat_map(|v| v.to_le_bytes()).collect()
}
fn decode(bytes: &[u8]) -> Vec<f32> {
    bytes
        .as_chunks::<4>()
        .0
        .iter()
        .map(|b| f32::from_le_bytes(*b))
        .collect()
}
pub fn run(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    root: &Path,
) -> Result<(), Box<dyn std::error::Error>> {
    let usage =
        wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC | wgpu::BufferUsages::COPY_DST;
    let settings = watery_core::settings::Settings::default();
    let mut g = Globals::zeroed();
    g.dims = [8, 8, 8, 512];
    g.caps = [64, 1, 0, 0];
    g.boxMin = [0, 0, 0, 512];
    g.boxMax = [8, 8, 8, 0];
    // Isolated analytical free-fall case: no deformation on the first step.
    g.gravityDt = [0.0, -settings.gravity, 0.0, 1.0 / 120.0];
    g.simB = [100.0, 1.0 / settings.sandResolution as f32, 0.0, 0.0];
    g.matA = [1.0, 0.0, 0.0, 0.0];
    g.matC[1] = 1.0;
    g.matB[1] = 1.0;
    g.matE = [0.0, 100.0, 100.0, 0.0];
    g.killInfo = [-100.0, 10.0, 0.0, 0.0];
    let mut data = vec![0; Globals::BYTE_SIZE];
    g.write_le(&mut data).unwrap();
    let globals = buffer(device, &data, wgpu::BufferUsages::UNIFORM);
    let count = 4usize;
    let initial: Vec<f32> = (0..count)
        .flat_map(|i| {
            [
                3.25 + i as f32 * 0.125,
                4.0,
                3.5,
                0.0,
                0.0,
                0.0,
                0.0,
                i as f32,
            ]
        })
        .collect();
    let mut input = floats(&initial);
    input.resize(64 * 32, 0);
    let particles = [
        buffer(device, &input, usage),
        buffer(device, &[0; 64 * 32], usage),
    ];
    let states = [
        buffer(device, &[0; 64 * 28 * 4], usage),
        buffer(device, &[0; 64 * 28 * 4], usage),
    ];
    let grid = buffer(device, &[0xFF; 512 * 16], usage);
    let cells = buffer(device, &[0xFF; 512 * 4], usage);
    let solid = buffer(device, &[0; 512 * 4], usage);
    let counters = buffer(device, &[0; 64], usage);
    let args = buffer(device, &[0; 112], usage);
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    let mut persistent = watery_gpu::sand::Sand::new(device, [8, 8, 8], 64)?;
    let initial_particles: Vec<_> = initial
        .as_chunks::<8>()
        .0
        .iter()
        .map(|p| watery_core::Particle {
            position: p[..4].try_into().unwrap(),
            velocity: p[4..].try_into().unwrap(),
        })
        .collect();
    persistent.reset(queue, &initial_particles)?;
    persistent.upload_globals(queue, &g)?;
    persistent.upload_solids(queue, &[0; 512])?;
    let mut current = 0;
    for step in 0..4 {
        let next = 1 - current;
        let mut counts = [0u32; 16];
        counts[current] = count as u32;
        counts[8..11].fill(u32::MAX);
        queue.write_buffer(
            &counters,
            0,
            &counts
                .into_iter()
                .flat_map(|v| v.to_le_bytes())
                .collect::<Vec<_>>(),
        );
        // Every call ends/submits a pass, preserving producer/consumer barriers.
        // This correctness harness intentionally does not optimize submissions.
        dispatch(
            device,
            queue,
            root,
            "mpm_clear",
            &[&globals, &grid, &cells],
            &[0; 8],
            2,
        )?;
        dispatch(
            device,
            queue,
            root,
            "args",
            &[&globals, &counters, &args],
            &[current as u32, 2, 0, 0, 0, 0, 0, 0],
            1,
        )?;
        dispatch(
            device,
            queue,
            root,
            "mpm_p2g",
            &[
                &globals,
                &particles[current],
                &states[current],
                &grid,
                &cells,
                &counters,
            ],
            &[current as u32, 0, 0, 0, 0, 0, 0, 0],
            1,
        )?;
        let mass = read(device, queue, &grid)?;
        let total: i64 = mass
            .as_chunks::<16>()
            .0
            .iter()
            .map(|v| i32::from_le_bytes(v[..4].try_into().unwrap()) as i64)
            .sum();
        assert!(
            (total - count as i64 * 1_048_576).abs() <= 27 * count as i64,
            "MPM mass fixed-point rounding, step={step}: {total}"
        );
        dispatch(
            device,
            queue,
            root,
            "mpm_grid",
            &[&globals, &grid, &solid],
            &[0; 8],
            2,
        )?;
        dispatch(
            device,
            queue,
            root,
            "mpm_g2p",
            &[
                &globals,
                &particles[current],
                &particles[next],
                &counters,
                &grid,
                &states[current],
                &states[next],
                &solid,
            ],
            &[current as u32, next as u32, 0, step, 0, 0, 0, 0],
            1,
        )?;
        let counts = read(device, queue, &counters)?;
        assert_eq!(
            u32::from_le_bytes(counts[4 * next..4 * next + 4].try_into().unwrap()),
            count as u32,
            "particle loss at step {step}"
        );
        let actual = decode(&read(device, queue, &particles[next])?);
        assert!(actual[..count * 8].iter().all(|v| v.is_finite()));
        let mut ids = Vec::new();
        for p in actual[..count * 8].as_chunks::<8>().0 {
            let id = p[7] as usize;
            assert!(id < count);
            ids.push(id);
            assert!(
                (p[0] - initial[id * 8]).abs() < 0.001,
                "spurious horizontal momentum"
            );
            assert!((p[2] - initial[id * 8 + 2]).abs() < 0.001);
            if step == 0 {
                let expected_v = -settings.gravity / 120.0;
                assert!(
                    (p[5] - expected_v).abs() < 0.0001,
                    "first-step gravity: {}",
                    p[5]
                );
                assert!((p[1] - (4.0 + expected_v / 120.0)).abs() < 0.0001);
            }
        }
        ids.sort_unstable();
        assert_eq!(
            ids,
            (0..count).collect::<Vec<_>>(),
            "compaction lost/duplicated particle identity"
        );
        let mut encoder = device.create_command_encoder(&Default::default());
        persistent.record_step(&mut encoder);
        queue.submit([encoder.finish()]);
        let retained = decode(&read(device, queue, persistent.particle_buffer())?);
        let metadata = read(device, queue, persistent.counter_buffer())?;
        assert_eq!(
            &metadata[32..60],
            &counts[32..60],
            "per-step metadata must match uncached path"
        );
        let mut a: Vec<_> = actual[..count * 8].as_chunks::<8>().0.iter().collect();
        let mut b: Vec<_> = retained[..count * 8].as_chunks::<8>().0.iter().collect();
        a.sort_by_key(|p| p[7] as usize);
        b.sort_by_key(|p| p[7] as usize);
        for (a, b) in a.iter().zip(b) {
            for (a, b) in a.iter().zip(b) {
                assert!(
                    (a - b).abs() < 0.00001,
                    "cached GPU path changed result at step {step}"
                );
            }
        }
        current = next;
    }
    if let Some(error) = pollster::block_on(scope.pop()) {
        return Err(error.into());
    }
    println!("GPU MPM: 4 original five-pass sand steps, mass/count/identity/finite/gravity PASS");
    Ok(())
}
