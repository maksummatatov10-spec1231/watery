//! Original FLIP graph for full domains, including optional whitewater.
//! Small domains use the inline solver; larger domains use original PCG passes
//! with multilevel descent to the original 8192-cell inline bottom.
use crate::{BoundKernel, Dispatch, Kernel};
use watery_core::{Particle, uniforms::Globals};

pub struct Fluid {
    particles: [wgpu::Buffer; 2],
    globals: wgpu::Buffer,
    counters: wgpu::Buffer,
    metadata: wgpu::Buffer,
    pressure: wgpu::Buffer,
    divergence_buffer: wgpu::Buffer,
    solids: wgpu::Buffer,
    args: wgpu::Buffer,
    emitters: wgpu::Buffer,
    emit_kernel: Kernel,
    blast_kernel: Kernel,
    inflow_kernel: Kernel,
    blockfill_kernel: Kernel,
    pending_emit: Option<(BoundKernel, u32)>,
    clear: [BoundKernel; 2],
    make_args: [BoundKernel; 2],
    remove: [BoundKernel; 2],
    p2g: [BoundKernel; 2],
    classify: BoundKernel,
    faces: BoundKernel,
    divergence: BoundKernel,
    viscosity_kernel: Kernel,
    viscosity: Vec<BoundKernel>,
    velocity: wgpu::Buffer,
    scratch: wgpu::Buffer,
    flags: wgpu::Buffer,
    solve: Option<BoundKernel>,
    large_solve: Option<crate::large_pressure::LargePressure>,
    project: BoundKernel,
    extrapolate: [BoundKernel; 2],
    g2p: [BoundKernel; 2],
    g2p_kernel: Kernel,
    velocity_old: wgpu::Buffer,
    potential_buffer: wgpu::Buffer,
    cell_count: wgpu::Buffer,
    whitewater: [wgpu::Buffer; 2],
    whitewater_count: [wgpu::Buffer; 2],
    whitewater_update: [BoundKernel; 2],
    whitewater_kernel: Kernel,
    potential: BoundKernel,
    view_state: wgpu::Buffer,
    probe: BoundKernel,
    whitewater_enabled: bool,
    seed: u32,
    device: wgpu::Device,
    current: usize,
    dims: [i32; 3],
    faces_count: u32,
    capacity: u32,
    layers: u32,
}
impl Fluid {
    pub fn new(
        device: &wgpu::Device,
        dims: [i32; 3],
        capacity: u32,
        iterations: u32,
        sweeps: u32,
        layers: u32,
    ) -> Result<Self, &'static str> {
        if dims.iter().any(|&d| d < 5)
            || capacity == 0
            || capacity > i32::MAX as u32
            || iterations == 0
            || sweeps == 0
            || iterations > i32::MAX as u32
            || sweeps > i32::MAX as u32
        {
            return Err("invalid fluid dimensions/capacity/solver iterations");
        }
        let cells = dims
            .iter()
            .try_fold(1u64, |a, &v| a.checked_mul(v as u64))
            .ok_or("cell overflow")?;
        let large = cells > watery_core::settings::Settings::default().solverSmallCells as u64;
        let hierarchy = watery_core::pressure::hierarchy(dims.map(|d| d as u32))?;
        let last = hierarchy.last().ok_or("empty pressure hierarchy")?;
        let multilevel_bytes = (last.offset as u64 + last.cells as u64) * 4;
        let limits = device.limits();
        crate::validation::limits(&limits, 10)?;
        if !device.features().contains(wgpu::Features::SUBGROUP)
            || limits.max_compute_invocations_per_workgroup < 1024
            || limits.max_compute_workgroup_size_x < 1024
        {
            return Err("original solver needs 1024-wide workgroups and subgroups");
        }
        if capacity as u64 * 32 > limits.max_storage_buffer_binding_size as u64
            || capacity as u64 * 32 > limits.max_buffer_size
            || capacity.div_ceil(256) > limits.max_compute_workgroups_per_dimension
        {
            return Err("particle capacity exceeds device limits");
        }
        let faces = dims
            .iter()
            .enumerate()
            .try_fold(0u64, |total, (axis, _)| {
                let count = dims.iter().enumerate().try_fold(1u64, |count, (i, &d)| {
                    count.checked_mul(d as u64 + u64::from(i == axis))
                })?;
                total.checked_add(count)
            })
            .ok_or("face count overflow")?;
        if faces > i32::MAX as u64
            || faces * 8 > limits.max_storage_buffer_binding_size as u64
            || multilevel_bytes > limits.max_storage_buffer_binding_size as u64
            || multilevel_bytes > limits.max_buffer_size
            || faces * 8 > limits.max_buffer_size
            || (cells + faces).div_ceil(256) > limits.max_compute_workgroups_per_dimension as u64
        {
            return Err("fluid grid exceeds device limits");
        }
        let faces_count = faces as u32;
        let storage = wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_SRC
            | wgpu::BufferUsages::COPY_DST;
        let alloc = |size, usage| {
            device.create_buffer(&wgpu::BufferDescriptor {
                label: None,
                size,
                usage,
                mapped_at_creation: false,
            })
        };
        let particles = std::array::from_fn(|_| alloc(capacity as u64 * 32, storage));
        let emitter_bytes = u64::from(capacity.min(8192)) * 64;
        if emitter_bytes > limits.max_storage_buffer_binding_size as u64
            || emitter_bytes > limits.max_buffer_size
        {
            return Err("emitter buffer exceeds device limits");
        }
        let emitters = alloc(emitter_bytes, storage);
        let globals = alloc(
            Globals::BYTE_SIZE as u64,
            wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        );
        let counters = alloc(64, storage);
        let args = alloc(112, storage | wgpu::BufferUsages::INDIRECT);
        let solids = alloc(cells * 4, storage);
        let count = alloc(cells * 4, storage);
        let density = alloc(cells * 4, storage);
        let flags = alloc(cells * 4, storage);
        let accum = alloc(faces_count as u64 * 8, storage);
        let vel = alloc(faces_count as u64 * 4, storage);
        let vel_old = alloc(faces_count as u64 * 4, storage);
        let valid = std::array::from_fn::<_, 2, _>(|_| alloc(faces_count as u64 * 4, storage));
        let divergence_buffer = alloc(cells * 4, storage);
        let pressure = alloc(cells * 4, storage);
        let mg_flags = alloc(multilevel_bytes, storage);
        let b0 = alloc(cells * 4, storage);
        let x0 = alloc(cells * 4, storage);
        let mg_b = alloc(multilevel_bytes, storage);
        let mg_x = alloc(multilevel_bytes, storage);
        let p = alloc(cells * 4, storage);
        let q = alloc(cells * 4, storage);
        // Still bind full resources: shader branches are runtime, not compile-time.
        let potential = alloc(cells * 8, storage);
        let ww_count = std::array::from_fn::<_, 2, _>(|_| alloc(cells * 4, storage));
        let whitewater = std::array::from_fn::<_, 2, _>(|_| alloc(capacity as u64 * 32, storage));
        macro_rules! kernel {
            ($name:literal) => {
                Kernel::new(
                    device,
                    $name,
                    include_str!(concat!("../../generated/shaders/", $name, ".wgsl")),
                )
            };
        }
        let clear_kernel = kernel!("clear_box");
        let clear = std::array::from_fn(|i| {
            clear_kernel.bind(
                device,
                &[&globals, &accum, &count, &density, &ww_count[1 - i]],
                &[0; 8],
            )
        });
        let args_kernel = kernel!("args");
        let make_args = std::array::from_fn(|i| {
            args_kernel.bind(
                device,
                &[&globals, &counters, &args],
                &[i as u32, 2 + i as u32, 0, 0, 0, 0, 0, 0],
            )
        });
        let remove_kernel = kernel!("remove");
        let remove = std::array::from_fn(|i| {
            remove_kernel.bind(
                device,
                &[&globals, &particles[i], &counters],
                &[i as u32, 0, 0, 0, 0, 0, 0, 0],
            )
        });
        let p2g_kernel = kernel!("p2g");
        let p2g = std::array::from_fn(|i| {
            p2g_kernel.bind(
                device,
                &[&globals, &particles[i], &accum, &count, &density, &counters],
                &[i as u32, 0, 0, 0, 0, 0, 0, 0],
            )
        });
        let classify =
            kernel!("classify").bind(device, &[&globals, &solids, &count, &flags], &[0; 8]);
        let faces = kernel!("faces").bind(
            device,
            &[&globals, &accum, &vel, &vel_old, &valid[0], &flags],
            &[0; 8],
        );
        let divergence = kernel!("divergence").bind(
            device,
            &[
                &globals,
                &vel,
                &flags,
                &density,
                &divergence_buffer,
                &pressure,
            ],
            &[0; 8],
        );
        let solve = (!large).then(|| {
            kernel!("mg_solve_small").bind(
                device,
                &[
                    &globals,
                    &mg_flags,
                    &b0,
                    &x0,
                    &mg_b,
                    &mg_x,
                    &flags,
                    &divergence_buffer,
                    &pressure,
                    &p,
                    &q,
                ],
                &[hierarchy.len() as u32, iterations, sweeps, 0, 0, 0, 0, 0],
            )
        });
        let large_solve = if large {
            Some(crate::large_pressure::LargePressure::new(
                device,
                &globals,
                &flags,
                &divergence_buffer,
                &pressure,
                &hierarchy,
                iterations,
                sweeps,
            )?)
        } else {
            None
        };
        let project = kernel!("project").bind(
            device,
            &[&globals, &vel, &flags, &pressure, &valid[0]],
            &[0; 8],
        );
        let extra = kernel!("extrapolate");
        let extrapolate = std::array::from_fn(|i| {
            extra.bind(device, &[&globals, &vel, &valid[i], &valid[1 - i]], &[0; 8])
        });
        let g2p_kernel = kernel!("g2p");
        let g2p = std::array::from_fn(|i| {
            g2p_kernel.bind(
                device,
                &[
                    &globals,
                    &particles[i],
                    &particles[1 - i],
                    &counters,
                    &vel,
                    &vel_old,
                    &flags,
                    &solids,
                    &potential,
                    &whitewater[1 - i],
                    &ww_count[i],
                    &count,
                ],
                &[i as u32, (1 - i) as u32, 0, 0, (3 - i) as u32, 0, 0, 0],
            )
        });
        let potential_pass = kernel!("potential").bind(
            device,
            &[&globals, &vel, &flags, &density, &potential],
            &[0; 8],
        );
        let view_state = alloc(16, storage);
        let probe = kernel!("probe").bind(
            device,
            &[&globals, &density, &flags, &view_state],
            &[0; 8],
        );
        let update = kernel!("ww_update");
        let whitewater_update = std::array::from_fn(|i| {
            update.bind(
                device,
                &[
                    &globals,
                    &whitewater[i],
                    &whitewater[1 - i],
                    &counters,
                    &vel,
                    &count,
                    &solids,
                    &ww_count[1 - i],
                ],
                &[(2 + i) as u32, (3 - i) as u32, 0, 0, 0, 0, 0, 0],
            )
        });
        Ok(Self {
            particles,
            globals,
            counters,
            metadata: crate::metadata_seed(device),
            pressure,
            divergence_buffer,
            solids,
            args,
            emitters,
            emit_kernel: kernel!("emit"),
            blast_kernel: kernel!("blast"),
            inflow_kernel: kernel!("inflow"),
            blockfill_kernel: kernel!("blockfill"),
            pending_emit: None,
            clear,
            make_args,
            remove,
            p2g,
            classify,
            faces,
            divergence,
            viscosity_kernel: kernel!("viscosity"),
            viscosity: Vec::new(),
            velocity: vel,
            scratch: accum,
            flags,
            solve,
            large_solve,
            project,
            extrapolate,
            g2p,
            g2p_kernel,
            velocity_old: vel_old,
            potential_buffer: potential,
            cell_count: count,
            whitewater,
            whitewater_count: ww_count,
            whitewater_update,
            whitewater_kernel: update,
            potential: potential_pass,
            view_state,
            probe,
            whitewater_enabled: false,
            seed: 0,
            device: device.clone(),
            current: 0,
            dims,
            faces_count,
            capacity,
            layers,
        })
    }
    /// Enable whitewater for water regions only. Configure after submitting prior work.
    /// Seed follows WaterRegion's wrapping sequence, one increment per G2P/update.
    pub fn configure_whitewater(&mut self, device: &wgpu::Device, enabled: bool, seed: u32) {
        self.whitewater_enabled = enabled;
        self.seed = seed;
        self.whitewater_update = std::array::from_fn(|i| self.whitewater_kernel.bind(
            device,
            &[&self.globals, &self.whitewater[i], &self.whitewater[1-i],
                &self.counters, &self.velocity, &self.cell_count, &self.solids,
                &self.whitewater_count[1-i]],
            &[(2+i) as u32, (3-i) as u32, 0, seed.wrapping_add(1), 0, 0, 0, 0],
        ));
        self.g2p = std::array::from_fn(|i| {
            self.g2p_kernel.bind(
                device,
                &[
                    &self.globals,
                    &self.particles[i],
                    &self.particles[1 - i],
                    &self.counters,
                    &self.velocity,
                    &self.velocity_old,
                    &self.flags,
                    &self.solids,
                    &self.potential_buffer,
                    &self.whitewater[1 - i],
                    &self.whitewater_count[i],
                    &self.cell_count,
                ],
                &[
                    i as u32,
                    (1 - i) as u32,
                    0,
                    seed,
                    (3 - i) as u32,
                    u32::from(enabled),
                    0,
                    0,
                ],
            )
        });
    }
    /// Restore diagnostic whitewater state after reset, before the next step.
    pub fn reset_whitewater(
        &self,
        queue: &wgpu::Queue,
        particles: &[Particle],
    ) -> Result<(), &'static str> {
        if particles.len() > self.capacity as usize
            || particles.iter().any(|p| {
                p.position.iter().chain(&p.velocity).any(|v| !v.is_finite())
                    || p.position[3] <= 0.0
                    || !matches!(p.velocity[3], 0.0 | 1.0 | 2.0)
            })
        {
            return Err("invalid whitewater population");
        }
        let bytes: Vec<_> = particles
            .iter()
            .flat_map(|p| p.position.into_iter().chain(p.velocity))
            .flat_map(f32::to_le_bytes)
            .collect();
        if !bytes.is_empty() {
            queue.write_buffer(&self.whitewater[self.current], 0, &bytes);
        }
        queue.write_buffer(
            &self.counters,
            (2 + self.current) as u64 * 4,
            &(particles.len() as u32).to_le_bytes(),
        );
        Ok(())
    }
    /// Configure the original slime Jacobi graph outside command recording.
    /// factor is viscosity * resolution^2, exactly pc.b.x in Watery.
    /// None disables viscosity (also used when the original setting is zero).
    pub fn configure_viscosity(
        &mut self,
        device: &wgpu::Device,
        factor: Option<(f32, u32)>,
    ) -> Result<(), &'static str> {
        let Some((factor, iterations)) = factor else {
            self.viscosity.clear();
            return Ok(());
        };
        if !factor.is_finite() || factor <= 0.0 || iterations == 0 || iterations > i32::MAX as u32 {
            return Err("invalid viscosity coefficient/iterations");
        }
        let n = iterations.max(2);
        let passes = (0..n)
            .map(|i| {
                let src = if i == 0 {
                    u32::MAX
                } else {
                    ((i - 1) % 2) * self.faces_count
                };
                let dst = if i == n - 1 {
                    u32::MAX
                } else {
                    (i % 2) * self.faces_count
                };
                self.viscosity_kernel.bind(
                    device,
                    &[&self.globals, &self.velocity, &self.scratch, &self.flags],
                    &[src, dst, 0, 0, factor.to_bits(), 0, 0, 0],
                )
            })
            .collect();
        self.viscosity = passes;
        Ok(())
    }
    pub fn reset(
        &mut self,
        queue: &wgpu::Queue,
        particles: &[Particle],
    ) -> Result<(), &'static str> {
        if particles.len() > self.capacity as usize
            || particles.iter().any(|p| {
                p.position
                    .iter()
                    .chain(p.velocity.iter())
                    .any(|v| !v.is_finite())
            })
        {
            return Err("invalid fluid population");
        }
        let bytes: Vec<_> = particles
            .iter()
            .flat_map(|p| p.position.into_iter().chain(p.velocity))
            .flat_map(f32::to_le_bytes)
            .collect();
        if !bytes.is_empty() {
            queue.write_buffer(&self.particles[0], 0, &bytes);
        }
        let mut counts = [0u8; 64];
        counts[..4].copy_from_slice(&(particles.len() as u32).to_le_bytes());
        queue.write_buffer(&self.counters, 0, &counts);
        queue.write_buffer(&self.pressure, 0, &vec![0; self.pressure.size() as usize]);
        for count in &self.whitewater_count {
            queue.write_buffer(count, 0, &vec![0; count.size() as usize]);
        }
        self.pending_emit = None;
        self.current = 0;
        Ok(())
    }
    /// Queue one original emit dispatch before the next simulation step.
    /// Call only after prior encoded work is submitted; the caller reserves
    /// capacity using the last readback population plus pending attempts.
    pub fn queue_emit(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        batch: &watery_core::emitter::Batch,
        seed: u32,
    ) -> Result<(), &'static str> {
        if self.pending_emit.is_some()
            || batch.accepted() == 0
            || batch.attempts() == 0
            || batch.attempts() > self.capacity
            || batch.bytes().len() as u64 > self.emitters.size()
            || batch.attempts().div_ceil(256) > device.limits().max_compute_workgroups_per_dimension
        {
            return Err("invalid or already pending emitter batch");
        }
        queue.write_buffer(&self.emitters, 0, batch.bytes());
        let i = self.current;
        let bound = self.emit_kernel.bind(
            device,
            &[
                &self.globals,
                &self.emitters,
                &self.particles[i],
                &self.counters,
                &self.solids,
            ],
            &[
                i as u32,
                batch.accepted() as u32,
                batch.attempts(),
                seed,
                0,
                0,
                0,
                0,
            ],
        );
        self.pending_emit = Some((bound, batch.attempts().div_ceil(256)));
        Ok(())
    }
    /// Apply the original blast in grid units to the current live population.
    /// Record in event order before record_step; no CPU readback or submission.
    pub fn record_blast(
        &self,
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        center: [f32; 3],
        radius: f32,
        strength: f32,
        lift: f32,
        scatter: f32,
        seed: u32,
    ) -> Result<(), &'static str> {
        if center
            .into_iter()
            .chain([radius, strength, lift, scatter])
            .any(|v| !v.is_finite())
            || radius <= 0.0
            || strength < 0.0
            || scatter < 0.0
        {
            return Err("invalid blast parameters");
        }
        let pc = [
            self.current as u32,
            seed,
            0,
            0,
            center[0].to_bits(),
            center[1].to_bits(),
            center[2].to_bits(),
            radius.to_bits(),
            strength.to_bits(),
            lift.to_bits(),
            scatter.to_bits(),
            0,
        ];
        let bound = self.blast_kernel.bind(
            device,
            &[&self.globals, &self.particles[self.current], &self.counters],
            &pc,
        );
        bound.record(encoder, Dispatch::Direct(self.capacity.div_ceil(256)));
        Ok(())
    }
    pub fn upload_globals(&self, queue: &wgpu::Queue, g: &Globals) -> Result<(), &'static str> {
        let [x, y, z] = self.dims;
        if g.dims != [x, y, z, x * y * z]
            || g.boxMin != [0, 0, 0, x * y * z]
            || g.boxMax[..3] != self.dims
            || g.faces
                != [
                    (x + 1) * y * z,
                    x * (y + 1) * z,
                    x * y * (z + 1),
                    self.faces_count as i32,
                ]
            || g.caps[0] != self.capacity as i32
            || g.caps[1] <= 0
            || g.caps[1] > self.capacity as i32
            || (self.whitewater_enabled && (g.matA[0] != 0.0 || g.caps[1] != self.capacity as i32))
        {
            return Err("fluid uniforms mismatch");
        }
        // Viscosity must never leak from a previously configured slime region.
        if g.matA[0] != 3.0 && !self.viscosity.is_empty() {
            return Err("viscosity configured for non-slime material");
        }
        crate::validation::globals(g, false)?;
        let mut bytes = [0u8; Globals::BYTE_SIZE];
        g.write_le(&mut bytes).map_err(|_| "uniform size")?;
        queue.write_buffer(&self.globals, 0, &bytes);
        Ok(())
    }
    pub fn upload_solids(&self, queue: &wgpu::Queue, solids: &[u32]) -> Result<(), &'static str> {
        if solids.len() as u64 * 4 != self.solids.size() {
            return Err("solid field size mismatch");
        }
        queue.write_buffer(
            &self.solids,
            0,
            &solids
                .iter()
                .flat_map(|v| v.to_le_bytes())
                .collect::<Vec<_>>(),
        );
        Ok(())
    }
    /// Preserve record order and submit before uploading changed uniforms.
    /// Discarding recorded commands invalidates the ping-pong state.
    pub fn record_step(&mut self, encoder: &mut wgpu::CommandEncoder) {
        if self.whitewater_enabled {
            let device = self.device.clone();
            self.configure_whitewater(&device, true, self.seed);
            self.seed = self.seed.wrapping_add(2);
        }
        let i = self.current;
        let cells = self.dims.iter().product::<i32>() as u32;
        encoder.clear_buffer(&self.counters, ((1 - i) * 4) as u64, Some(4));
        encoder.clear_buffer(&self.counters, ((3 - i) * 4) as u64, Some(4));
        if !self.whitewater_enabled {
            encoder.clear_buffer(&self.counters, ((2 + i) * 4) as u64, Some(4));
        }
        encoder.clear_buffer(&self.counters, 24, Some(4));
        encoder.copy_buffer_to_buffer(&self.metadata, 0, &self.counters, 32, 32);
        if let Some((emit, groups)) = self.pending_emit.take() {
            emit.record(encoder, Dispatch::Direct(groups));
        }
        self.clear[i].record(
            encoder,
            Dispatch::Direct((cells + self.faces_count).div_ceil(256)),
        );
        self.make_args[i].record(encoder, Dispatch::Direct(1));
        self.remove[i].record(encoder, Dispatch::Indirect(&self.args));
        self.p2g[i].record(encoder, Dispatch::Indirect(&self.args));
        self.classify
            .record(encoder, Dispatch::Direct(cells.div_ceil(256)));
        self.faces
            .record(encoder, Dispatch::Direct(self.faces_count.div_ceil(256)));
        for pass in &self.viscosity {
            pass.record(encoder, Dispatch::Direct(self.faces_count.div_ceil(256)));
        }
        self.divergence
            .record(encoder, Dispatch::Direct(cells.div_ceil(256)));
        if let Some(solve) = &self.solve {
            solve.record(encoder, Dispatch::Direct(1));
        }
        if let Some(solve) = &self.large_solve {
            solve.record(encoder);
        }
        self.project
            .record(encoder, Dispatch::Direct(self.faces_count.div_ceil(256)));
        for layer in 0..self.layers {
            self.extrapolate[layer as usize % 2]
                .record(encoder, Dispatch::Direct(self.faces_count.div_ceil(256)));
        }
        if self.whitewater_enabled {
            self.potential
                .record(encoder, Dispatch::Direct(cells.div_ceil(256)));
        }
        self.g2p[i].record(encoder, Dispatch::Indirect(&self.args));
        if self.whitewater_enabled {
            self.whitewater_update[i].record(encoder, Dispatch::IndirectAt(&self.args, 16));
        }
        self.current = 1 - i;
        // Refresh indirect draw/compute arguments and camera submersion state for rendering.
        self.make_args[self.current].record(encoder, Dispatch::Direct(1));
        encoder.clear_buffer(&self.view_state, 0, None);
        self.probe.record(encoder, Dispatch::Direct(1));
    }
    /// Refresh `args` for the active ping-pong slot without advancing simulation.
    pub fn record_args(&self, encoder: &mut wgpu::CommandEncoder) {
        self.make_args[self.current].record(encoder, Dispatch::Direct(1));
    }
    /// Spawn fluid particles from infinite source blocks (`G.sources[0..source_count]`).
    /// Must run after a step has populated `cell_count` (or from zeroed `cell_count`).
    pub fn record_inflow(
        &self,
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        source_count: u32,
        resolution: u32,
        seed: u32,
    ) -> Result<(), &'static str> {
        if source_count > 64 || !matches!(resolution, 1 | 2 | 4) {
            return Err("invalid inflow source count or grid resolution");
        }
        if source_count == 0 {
            return Ok(());
        }
        let threads = source_count
            .checked_mul(resolution.pow(3))
            .ok_or("inflow dispatch overflow")?;
        let groups = threads.div_ceil(64);
        if groups > device.limits().max_compute_workgroups_per_dimension {
            return Err("inflow dispatch exceeds device limits");
        }
        let bound = self.inflow_kernel.bind(
            device,
            &[
                &self.globals,
                &self.particles[self.current],
                &self.counters,
                &self.cell_count,
                &self.solids,
            ],
            &[self.current as u32, seed, 0, 0, 0, 0, 0, 0],
        );
        bound.record(encoder, Dispatch::Direct(groups));
        Ok(())
    }
    /// Compute packed per-block `full | (fast << 8)` values over `[block_origin .. +block_dims]`.
    pub fn record_block_fill(
        &self,
        device: &wgpu::Device,
        encoder: &mut wgpu::CommandEncoder,
        block_origin: [i32; 3],
        block_dims: [u32; 3],
        out_fill: &wgpu::Buffer,
    ) -> Result<(), &'static str> {
        if block_dims.contains(&0) {
            return Err("blockfill dimensions must be non-zero");
        }
        let total = block_dims
            .iter()
            .try_fold(1u64, |a, &d| a.checked_mul(d as u64))
            .ok_or("blockfill count overflow")?;
        if total > i32::MAX as u64 || out_fill.size() < total * 4 {
            return Err("blockfill output buffer too small or count overflow");
        }
        let groups = (total as u32).div_ceil(64);
        if groups > device.limits().max_compute_workgroups_per_dimension {
            return Err("blockfill dispatch exceeds device limits");
        }
        let bound = self.blockfill_kernel.bind(
            device,
            &[
                &self.globals,
                &self.cell_count,
                &self.flags,
                out_fill,
                &self.velocity,
            ],
            &[
                block_origin[0] as u32,
                block_origin[1] as u32,
                block_origin[2] as u32,
                0,
                block_dims[0],
                block_dims[1],
                block_dims[2],
                0,
            ],
        );
        bound.record(encoder, Dispatch::Direct(groups));
        Ok(())
    }
    pub fn args_buffer(&self) -> &wgpu::Buffer {
        &self.args
    }
    pub fn view_state_buffer(&self) -> &wgpu::Buffer {
        &self.view_state
    }
    pub fn solid_buffer(&self) -> &wgpu::Buffer {
        &self.solids
    }
    pub fn whitewater_buffer(&self) -> &wgpu::Buffer {
        &self.whitewater[self.current]
    }
    pub fn whitewater_counter(&self) -> usize {
        2 + self.current
    }
    pub fn particle_buffer(&self) -> &wgpu::Buffer {
        &self.particles[self.current]
    }
    /// Diagnostic readback only; normal simulation never maps pressure on CPU.
    pub fn pressure_buffer(&self) -> &wgpu::Buffer {
        &self.pressure
    }
    pub fn divergence_buffer(&self) -> &wgpu::Buffer {
        &self.divergence_buffer
    }
    pub fn flags_buffer(&self) -> &wgpu::Buffer {
        &self.flags
    }
    pub fn counter_buffer(&self) -> &wgpu::Buffer {
        &self.counters
    }
    pub fn current_counter(&self) -> usize {
        self.current
    }
}
