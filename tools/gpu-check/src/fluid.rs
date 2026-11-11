//! Small-domain FLIP gravity, persistence and identity regression.
use crate::execution::read;
use watery_core::{Particle, uniforms::Globals};
pub fn run(device: &wgpu::Device, queue: &wgpu::Queue) -> Result<(), Box<dyn std::error::Error>> {
    let settings = watery_core::settings::Settings::default();
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    let mut fluid = watery_gpu::fluid::Fluid::new(
        device,
        [8, 8, 8],
        64,
        settings.cgIterations as u32,
        settings.mgCoarseSweeps as u32,
        settings.extrapolationLayers as u32,
    )?;
    let mut g = Globals::zeroed();
    g.dims = [8, 8, 8, 512];
    g.faces = [576, 576, 576, 1728];
    g.caps = [64, 1, 0, 0];
    g.boxMin = [0, 0, 0, 512];
    g.boxMax = [8, 8, 8, 0];
    g.gravityDt = [0.0, -settings.gravity, 0.0, 1.0 / 120.0];
    g.simA = [settings.flipRatio, 8.0, 1.0, 1.0];
    g.simB = [100.0, 1.0 / 6.0, 0.0, 0.0];
    g.matB = [0.0, 100.0, 0.0, 1.0];
    g.killInfo = [-100.0, 10.0, 0.0, 0.0];
    g.camGrid[3] = 6.0;
    fluid.upload_globals(queue, &g)?;
    fluid.upload_solids(queue, &[0; 512])?;
    let particles: Vec<_> = (0..8)
        .map(|i| Particle {
            position: [
                3.25 + (i % 2) as f32 * 0.5,
                3.25 + ((i / 2) % 2) as f32 * 0.5,
                3.25 + (i / 4) as f32 * 0.5,
                0.0,
            ],
            velocity: [0.0; 4],
        })
        .collect();
    fluid.reset(queue, &particles)?;
    if let Some(e) = pollster::block_on(scope.pop()) {
        return Err(e.into());
    }
    for step in 0..4 {
        let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
        let mut encoder = device.create_command_encoder(&Default::default());
        fluid.record_step(&mut encoder);
        queue.submit([encoder.finish()]);
        let counters = read(device, queue, fluid.counter_buffer())?;
        if let Some(e) = pollster::block_on(scope.pop()) {
            return Err(e.into());
        }
        let i = fluid.current_counter() * 4;
        assert_eq!(
            u32::from_le_bytes(counters[i..i + 4].try_into().unwrap()),
            8,
            "FLIP particle count step={step}"
        );
        let bytes = read(device, queue, fluid.particle_buffer())?;
        let values: Vec<f32> = bytes[..8 * 32]
            .as_chunks::<4>()
            .0
            .iter()
            .map(|b| f32::from_le_bytes(*b))
            .collect();
        assert!(
            values.iter().all(|v| v.is_finite()),
            "FLIP nonfinite step={step}"
        );
        let avg_y = values.as_chunks::<8>().0.iter().map(|p| p[1]).sum::<f32>() / 8.0;
        assert!(
            avg_y < 3.5,
            "gravity did not move population at step={step}"
        );
        if step == 0 {
            let avg_v = values.as_chunks::<8>().0.iter().map(|p| p[5]).sum::<f32>() / 8.0;
            assert!(
                (avg_v + settings.gravity / 120.0).abs() < 0.005,
                "FLIP gravity first step {avg_v}"
            );
        }
    }
    // A nonempty reset must match a fresh instance even after pressure history.
    let mut fresh = watery_gpu::fluid::Fluid::new(
        device,
        [8, 8, 8],
        64,
        settings.cgIterations as u32,
        settings.mgCoarseSweeps as u32,
        settings.extrapolationLayers as u32,
    )?;
    fresh.upload_globals(queue, &g)?;
    fresh.upload_solids(queue, &[0; 512])?;
    fresh.reset(queue, &particles)?;
    fluid.reset(queue, &particles)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fresh.record_step(&mut encoder);
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let decode = |bytes: Vec<u8>| {
        let mut rows: Vec<[f32; 8]> = bytes[..256]
            .as_chunks::<32>()
            .0
            .iter()
            .map(|b| {
                std::array::from_fn(|i| f32::from_le_bytes(b[i * 4..i * 4 + 4].try_into().unwrap()))
            })
            .collect();
        rows.sort_by(|a, b| {
            a[0].total_cmp(&b[0])
                .then(a[2].total_cmp(&b[2]))
                .then(a[1].total_cmp(&b[1]))
        });
        rows
    };
    let a = decode(read(device, queue, fluid.particle_buffer())?);
    let b = decode(read(device, queue, fresh.particle_buffer())?);
    for (a, b) in a.iter().flatten().zip(b.iter().flatten()) {
        assert!((a - b).abs() < 0.00001, "reset retains simulation history");
    }
    fluid.reset(queue, &[])?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let counters = read(device, queue, fluid.counter_buffer())?;
    let i = fluid.current_counter() * 4;
    assert_eq!(
        &counters[i..i + 4],
        &[0; 4],
        "reset must not revive old particles"
    );
    // The original emitter shader appends to the current ping-pong population
    // before P2G; verify a nonempty batch actually enters the simulation.
    fluid.reset(queue, &particles)?;
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    let batch = watery_core::emitter::pack_batch(
        &[watery_core::emitter::Emitter {
            min: [3.0, 3.0, 3.0],
            max: [4.0, 4.0, 4.0],
            velocity: [1.0, 0.0, 0.0],
        }],
        1,
        [0; 3],
        8,
        64,
    )?;
    assert_eq!(batch.attempts(), 8);
    fluid.queue_emit(device, queue, &batch, 12345)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let counters = read(device, queue, fluid.counter_buffer())?;
    let i = fluid.current_counter() * 4;
    assert_eq!(u32::from_le_bytes(counters[i..i + 4].try_into()?), 16);
    let born = read(device, queue, fluid.particle_buffer())?;
    // GPU compaction does not preserve append order: inspect all live rows.
    for row in born[..16 * 32].as_chunks::<32>().0 {
        let values: [f32; 8] =
            std::array::from_fn(|j| f32::from_le_bytes(row[j * 4..j * 4 + 4].try_into().unwrap()));
        assert!(values.iter().all(|v| v.is_finite()));
        assert!(
            (2.0..5.0).contains(&values[0]),
            "particle left source bounds"
        );
    }
    // No replay on the next step and no duplicate pending upload.
    fluid.queue_emit(device, queue, &batch, 12346)?;
    assert!(fluid.queue_emit(device, queue, &batch, 12347).is_err());
    fluid.reset(queue, &particles)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let counters = read(device, queue, fluid.counter_buffer())?;
    let i = fluid.current_counter() * 4;
    assert_eq!(
        u32::from_le_bytes(counters[i..i + 4].try_into()?),
        8,
        "reset retained pending emission"
    );
    if let Some(e) = pollster::block_on(scope.pop()) {
        return Err(e.into());
    }
    // Removal tags particles; P2G skips them and G2P compacts the live set.
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    fluid.reset(queue, &particles)?;
    g.removeInfo[0] = 1;
    g.removeBox[0] = [0.0, 0.0, 0.0, 0.0];
    g.removeBox[1] = [8.0, 8.0, 8.0, 0.0];
    fluid.upload_globals(queue, &g)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let counters = read(device, queue, fluid.counter_buffer())?;
    let i = fluid.current_counter() * 4;
    assert_eq!(
        u32::from_le_bytes(counters[i..i + 4].try_into()?),
        0,
        "removal tags must be compacted by the complete fluid graph"
    );
    g.removeInfo[0] = 0;
    fluid.upload_globals(queue, &g)?;
    if let Some(e) = pollster::block_on(scope.pop()) {
        return Err(e.into());
    }
    // Blast: no simulation yet, so the original shader must preserve positions,
    // affect only the in-radius particle, and keep count and padding intact.
    let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
    let blast_parts = [
        Particle {
            position: [3.0, 3.0, 3.0, 0.0],
            velocity: [0.0; 4],
        },
        Particle {
            position: [6.0, 6.0, 6.0, 0.0],
            velocity: [0.0; 4],
        },
    ];
    fluid.reset(queue, &blast_parts)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    assert!(
        fluid
            .record_blast(device, &mut encoder, [3.0; 3], 0.0, 4.0, 0.0, 0.0, 42)
            .is_err()
    );
    fluid.record_blast(device, &mut encoder, [3.0; 3], 1.0, 4.0, 0.0, 0.0, 42)?;
    queue.submit([encoder.finish()]);
    let bytes = read(device, queue, fluid.particle_buffer())?;
    let v: Vec<f32> = bytes[..64]
        .as_chunks::<4>()
        .0
        .iter()
        .map(|b| f32::from_le_bytes(*b))
        .collect();
    assert_eq!(&v[..4], &blast_parts[0].position);
    assert_eq!(v[4], 0.0);
    assert!(
        (2.8..=4.0).contains(&v[5]),
        "blast center must kick upwards with original falloff RNG"
    );
    assert_eq!(v[6], 0.0);
    assert_eq!(&v[8..12], &blast_parts[1].position);
    assert_eq!(&v[12..16], &[0.0; 4]);
    fluid.reset(queue, &blast_parts)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_blast(device, &mut encoder, [3.0; 3], 1.0, 4.0, 0.0, 0.0, 42)?;
    queue.submit([encoder.finish()]);
    let repeat = read(device, queue, fluid.particle_buffer())?;
    assert_eq!(
        &repeat[..64],
        &bytes[..64],
        "same blast seed must reproduce velocities"
    );
    // Partial removal keeps the upper-exclusive boundary particle alive.
    fluid.reset(queue, &blast_parts)?;
    g.removeInfo[0] = 1;
    g.removeBox[0] = [2.0, 2.0, 2.0, 0.0];
    g.removeBox[1] = [6.0, 7.0, 7.0, 0.0];
    fluid.upload_globals(queue, &g)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let counters = read(device, queue, fluid.counter_buffer())?;
    let i = fluid.current_counter() * 4;
    assert_eq!(
        u32::from_le_bytes(counters[i..i + 4].try_into()?),
        1,
        "partial removal changed exclusive boundary"
    );
    g.removeInfo[0] = 0;
    fluid.upload_globals(queue, &g)?;
    // Entity collision: the full graph ejects an enclosed particle from the
    // moving collider using original g2p rules, with no CPU replacement.
    fluid.reset(queue, &blast_parts[..1])?;
    g.caps[2] = 1;
    g.ent[0] = [2.5, 2.5, 2.5, 0.0];
    g.ent[1] = [4.0, 4.0, 4.0, 0.0];
    g.ent[2] = [1.0, 0.0, 0.0, 0.0];
    fluid.upload_globals(queue, &g)?;
    let mut encoder = device.create_command_encoder(&Default::default());
    fluid.record_step(&mut encoder);
    queue.submit([encoder.finish()]);
    let counters = read(device, queue, fluid.counter_buffer())?;
    let i = fluid.current_counter() * 4;
    assert_eq!(u32::from_le_bytes(counters[i..i + 4].try_into()?), 1);
    let bytes = read(device, queue, fluid.particle_buffer())?;
    let p: [f32; 3] =
        std::array::from_fn(|a| f32::from_le_bytes(bytes[a * 4..a * 4 + 4].try_into().unwrap()));
    assert!(p.iter().all(|v| v.is_finite()));
    assert!(
        (0..3).any(|a| p[a] < g.ent[0][a] || p[a] > g.ent[1][a]),
        "particle remained inside entity"
    );
    g.caps[2] = 0;
    fluid.upload_globals(queue, &g)?;
    if let Some(e) = pollster::block_on(scope.pop()) {
        return Err(e.into());
    }
    // Execute the original slime graph with zero/nonzero viscosity; a
    // localized impulse must diffuse instead of creating extra particles.
    g.matA[0] = 3.0;
    g.simA[0] = settings.slimeFlipRatio;
    g.matC = [
        settings.slimeRestSpeed,
        settings.slimeRestTime,
        settings.slimeWakeSpeed,
        0.0,
    ];
    g.gravityDt[1] = 0.0;
    let mut impulse = particles.clone();
    impulse[0].velocity[0] = 2.0;
    let mut speeds = Vec::new();
    for coefficient in [0.0, settings.slimeViscosity] {
        fluid.configure_viscosity(
            device,
            if coefficient == 0.0 {
                None
            } else {
                Some((
                    coefficient * (settings.slimeResolution * settings.slimeResolution) as f32,
                    settings.slimeViscosityIterations as u32,
                ))
            },
        )?;
        fluid.upload_globals(queue, &g)?;
        fluid.reset(queue, &impulse)?;
        let scope = device.push_error_scope(wgpu::ErrorFilter::Validation);
        let mut encoder = device.create_command_encoder(&Default::default());
        fluid.record_step(&mut encoder);
        queue.submit([encoder.finish()]);
        let bytes = read(device, queue, fluid.particle_buffer())?;
        if let Some(e) = pollster::block_on(scope.pop()) {
            return Err(e.into());
        }
        let rows = decode(bytes);
        assert!(rows.iter().flatten().all(|v| v.is_finite()));
        speeds.push(
            rows.iter()
                .map(|p| p[4] * p[4] + p[5] * p[5] + p[6] * p[6])
                .sum::<f32>(),
        );
        let count = read(device, queue, fluid.counter_buffer())?;
        let offset = fluid.current_counter() * 4;
        assert_eq!(&count[offset..offset + 4], &8u32.to_le_bytes());
    }
    assert!(
        speeds[1] < speeds[0],
        "viscosity failed to dissipate localized impulse: {speeds:?}"
    );
    fluid.configure_viscosity(device, None)?;
    println!(
        "GPU FLIP: gravity/reset, emit/remove, blast seed/radius, moving entity, slime viscosity PASS"
    );
    Ok(())
}
