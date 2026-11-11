//! Original full-domain PCG graph with multilevel descent to inline bottom.
use crate::{BoundKernel, Dispatch, Kernel};

pub(crate) struct LargePressure {
    setup: Vec<(BoundKernel, u32)>,
    cycle: Vec<CycleStep>,
    dot: BoundKernel,
    reduce: [BoundKernel; 3],
    direction: [BoundKernel; 3],
    apply: BoundKernel,
    update: [BoundKernel; 2],
    groups: u32,
    iterations: u32,
}
enum CycleStep {
    Run(BoundKernel, u32),
    Copy(wgpu::Buffer, wgpu::Buffer),
}
impl LargePressure {
    pub fn new(
        device: &wgpu::Device,
        globals: &wgpu::Buffer,
        flags: &wgpu::Buffer,
        divergence: &wgpu::Buffer,
        pressure: &wgpu::Buffer,
        levels: &[watery_core::pressure::Level],
        iterations: u32,
        sweeps: u32,
    ) -> Result<Self, &'static str> {
        let bottom = levels
            .iter()
            .position(|l| l.cells <= 8192)
            .ok_or("pressure hierarchy has no inline bottom")?;
        if bottom == 0 {
            return Err("large pressure requires multilevel descent");
        }
        let cells = levels[0].cells;
        let groups = cells.div_ceil(256);
        let last = levels.last().ok_or("empty hierarchy")?;
        let bytes = u64::from(last.offset + last.cells) * 4;
        let limits = device.limits();
        if bytes > limits.max_buffer_size
            || bytes > limits.max_storage_buffer_binding_size as u64
            || groups > limits.max_compute_workgroups_per_dimension
        {
            return Err("large pressure exceeds device limits");
        }
        let alloc = |size| {
            device.create_buffer(&wgpu::BufferDescriptor {
                label: Some("Watery PCG workspace"),
                size,
                usage: wgpu::BufferUsages::STORAGE
                    | wgpu::BufferUsages::COPY_SRC
                    | wgpu::BufferUsages::COPY_DST,
                mapped_at_creation: false,
            })
        };
        let mg_flags = alloc(bytes);
        let mg_b = alloc(bytes);
        let mg_x = alloc(bytes);
        let r = alloc(u64::from(cells) * 4);
        let z = alloc(u64::from(cells) * 4);
        let p = alloc(u64::from(cells) * 4);
        let q = alloc(u64::from(cells) * 4);
        // Direct one-dimensional dispatch writes exactly one partial per group.
        let partial = alloc(u64::from(groups) * 4);
        let scalars = alloc(16);
        macro_rules! k {
            ($name:literal) => {
                Kernel::new(
                    device,
                    $name,
                    include_str!(concat!("../../generated/shaders/", $name, ".wgsl")),
                )
            };
        }
        let pc = |a: usize, b: usize, parity: u32, init: u32| {
            let mut words = [0u32; 16];
            words[..3].copy_from_slice(&levels[a].dims);
            words[3] = levels[a].offset;
            words[4..7].copy_from_slice(&levels[b].dims);
            words[7] = levels[b].offset;
            words[8..12].copy_from_slice(&[parity, init, a as u32, b as u32]);
            words
        };
        let mut setup = vec![(
            k!("mg_flags0").bind(device, &[globals, flags, &mg_flags], &[0; 8]),
            groups,
        )];
        let coarsen = k!("mg_coarsen");
        for l in 0..levels.len() - 1 {
            setup.push((
                coarsen.bind(device, &[globals, &mg_flags], &pc(l, l + 1, 0, 0)),
                levels[l + 1].cells.div_ceil(256),
            ));
        }
        setup.push((
            k!("cg_init").bind(
                device,
                &[globals, &mg_flags, divergence, pressure, &r],
                &pc(0, 0, 0, 0),
            ),
            groups,
        ));
        let smooth = k!("mg_smooth");
        let mut cycle = Vec::new();
        // Snapshots keep the original packed indices without binding the same
        // allocation as both read-only and writable storage in one wgpu pass.
        let read_b = alloc(bytes);
        let read_x = alloc(bytes);
        for l in 0..bottom {
            let (b, x) = if l == 0 { (&r, &z) } else { (&mg_b, &mg_x) };
            let n = levels[l].cells.div_ceil(256);
            cycle.push(CycleStep::Run(
                smooth.bind(
                    device,
                    &[globals, &mg_flags, b, x],
                    &pc(l, l, 0, u32::from(l == 0)),
                ),
                n,
            ));
            cycle.push(CycleStep::Run(
                smooth.bind(device, &[globals, &mg_flags, b, x], &pc(l, l, 1, 0)),
                n,
            ));
            let (source_b, source_x) = if l == 0 {
                (b, x)
            } else {
                cycle.push(CycleStep::Copy(mg_b.clone(), read_b.clone()));
                cycle.push(CycleStep::Copy(mg_x.clone(), read_x.clone()));
                (&read_b, &read_x)
            };
            cycle.push(CycleStep::Run(
                k!("mg_restrict").bind(
                    device,
                    &[globals, &mg_flags, source_b, source_x, &mg_b, &mg_x],
                    &pc(l, l + 1, 0, 0),
                ),
                levels[l + 1].cells.div_ceil(256),
            ));
        }
        cycle.push(CycleStep::Run(
            k!("mg_bottom").bind(
                device,
                &[globals, &mg_flags, &r, &z, &mg_b, &mg_x],
                &[bottom as u32, levels.len() as u32, sweeps, 0, 0, 0, 0, 0],
            ),
            1,
        ));
        for l in (0..bottom).rev() {
            let (b, x) = if l == 0 { (&r, &z) } else { (&mg_b, &mg_x) };
            let coarse = if l == 0 {
                &mg_x
            } else {
                cycle.push(CycleStep::Copy(mg_x.clone(), read_x.clone()));
                &read_x
            };
            let n = levels[l].cells.div_ceil(256);
            cycle.push(CycleStep::Run(
                k!("mg_prolong").bind(
                    device,
                    &[globals, &mg_flags, x, coarse],
                    &pc(l, l + 1, 0, 0),
                ),
                n,
            ));
            cycle.push(CycleStep::Run(
                smooth.bind(device, &[globals, &mg_flags, b, x], &pc(l, l, 1, 0)),
                n,
            ));
            cycle.push(CycleStep::Run(
                smooth.bind(device, &[globals, &mg_flags, b, x], &pc(l, l, 0, 0)),
                n,
            ));
        }
        let dot = k!("cg_dot").bind(device, &[globals, &r, &z, &partial], &[0; 8]);
        let reduce_kernel = k!("cg_reduce");
        let reduce = std::array::from_fn(|i| {
            reduce_kernel.bind(
                device,
                &[globals, &partial, &scalars],
                &[groups, i as u32, 0, 0, 0, 0, 0, 0],
            )
        });
        let direction_kernel = k!("cg_direction");
        let direction = [
            direction_kernel.bind(
                device,
                &[globals, &scalars, &z, &p],
                &[1, 0, 0, 0, 0, 0, 0, 0],
            ),
            direction_kernel.bind(
                device,
                &[globals, &scalars, &z, &p],
                &[0, 1, 0, 0, 0, 0, 0, 0],
            ),
            direction_kernel.bind(
                device,
                &[globals, &scalars, &z, &p],
                &[0, 0, 1, 0, 0, 0, 0, 0],
            ),
        ];
        let apply = k!("cg_apply").bind(
            device,
            &[globals, &mg_flags, &p, &q, &partial],
            &pc(0, 0, 0, 0),
        );
        let update_kernel = k!("cg_update");
        let update = std::array::from_fn(|i| {
            update_kernel.bind(
                device,
                &[globals, &scalars, &p, &q, pressure, &r],
                &[i as u32, 2, 0, 0, 0, 0, 0, 0],
            )
        });
        Ok(Self {
            setup,
            cycle,
            dot,
            reduce,
            direction,
            apply,
            update,
            groups,
            iterations,
        })
    }
    pub fn record(&self, encoder: &mut wgpu::CommandEncoder) {
        for (k, n) in &self.setup {
            k.record(encoder, Dispatch::Direct(*n));
        }
        self.cycle(encoder);
        self.dot.record(encoder, Dispatch::Direct(self.groups));
        self.reduce[0].record(encoder, Dispatch::Direct(1));
        self.direction[0].record(encoder, Dispatch::Direct(self.groups));
        let mut slot = 0;
        for i in 0..self.iterations {
            self.apply.record(encoder, Dispatch::Direct(self.groups));
            self.reduce[2].record(encoder, Dispatch::Direct(1));
            self.update[slot].record(encoder, Dispatch::Direct(self.groups));
            if i + 1 < self.iterations {
                self.cycle(encoder);
                self.dot.record(encoder, Dispatch::Direct(self.groups));
                let next = 1 - slot;
                self.reduce[next].record(encoder, Dispatch::Direct(1));
                self.direction[if next == 1 { 1 } else { 2 }]
                    .record(encoder, Dispatch::Direct(self.groups));
                slot = next;
            }
        }
    }
    fn cycle(&self, encoder: &mut wgpu::CommandEncoder) {
        for step in &self.cycle {
            match step {
                CycleStep::Run(k, n) => k.record(encoder, Dispatch::Direct(*n)),
                CycleStep::Copy(src, dst) => {
                    encoder.copy_buffer_to_buffer(src, 0, dst, 0, src.size())
                }
            }
        }
    }
}
