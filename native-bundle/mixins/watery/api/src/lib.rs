//! Native Horizon adapter for the Watery 1.2.2 GPU simulation.
//!
//! `/watery diagnostic [water|sand|lava|slime]` creates a small camera-anchored
//! test region; `/watery status`, `/watery pause`, and `/watery clear` manage it.
//! The adapter wires client collision snapshots, material textures, flow sounds,
//! FLIP/MPM stepping, surface reconstruction, and the host world render targets.
//! Buckets, authoritative networking, persistence, UI, and full gameplay parity
//! remain separate work; see `reference/continuation-status.md`.
mod frame;

use horizon_client::mod_api::*;
use std::{
    collections::HashMap,
    sync::{Arc, Mutex, mpsc},
    time::Instant,
};
use watery_core::{
    atlas_tex,
    flow_sounds::{BlockFill, FlowSounds},
    material::Material,
    settings::Settings,
    solid_cache::SolidCache,
    uniforms::Globals,
    Particle,
};

pub fn hooks() -> Box<dyn Hooks> {
    Box::new(Watery::default())
}

/// The diagnostic region in world blocks (per axis).
const BLOCK_DIMS: [i32; 3] = [4, 4, 4];
const CAPACITY: u32 = 32768;
const DT: f32 = 1.0 / 60.0;
/// The section cache stores at most 4³ subcells per block in its u64 bitset.
const CACHE_RES: usize = 4;
const BLOCKFILL_PERIOD: u32 = 20;

#[derive(Default)]
struct Watery {
    state: Arc<Mutex<State>>,
}

struct State {
    camera: Option<NativeCamera>,
    request: Option<Material>,
    runtime: Option<Runtime>,
    paused: bool,
    error: Option<String>,
    generation: u64,
    terrain_pending: bool,
    terrain_dirty: bool,
    terrain: Option<([i32; 3], Vec<u32>)>,
    terrain_frame: u32,
    snapshot: Option<NativeClientChunks>,
    cache: SolidCache,
    /// Exact host collision boxes for the small active region. `SolidCache`
    /// keeps the compact 4³ occupancy too; other material resolutions use the
    /// boxes here so their centre-sampled masks stay exact.
    collision_boxes: HashMap<[i32; 3], Vec<[f64; 6]>>,
    slime_words: Option<Vec<i32>>,
    sand_words: Option<Vec<i32>>,
    textures_dirty: bool,
    sounds: FlowSounds,
    pending_fill: Option<BlockFill>,
}

impl Default for State {
    fn default() -> Self {
        Self {
            camera: None,
            request: None,
            runtime: None,
            paused: false,
            error: None,
            generation: 0,
            terrain_pending: false,
            terrain_dirty: false,
            terrain: None,
            terrain_frame: 0,
            snapshot: None,
            cache: SolidCache::new(CACHE_RES).expect("cache resolution 4 is valid"),
            collision_boxes: HashMap::new(),
            slime_words: None,
            sand_words: None,
            textures_dirty: true,
            sounds: FlowSounds::default(),
            pending_fill: None,
        }
    }
}

struct Runtime {
    fluid: Option<watery_gpu::fluid::Fluid>,
    sand: Option<watery_gpu::sand::Sand>,
    /// Index 0 and 1 hold surface bindings for the matching simulation ping-pong slot.
    surfaces: [watery_gpu::surface::Surface; 2],
    mesh: watery_gpu::render::MeshRenderer,
    grains: Option<watery_gpu::grains::SandRenderer>,
    g: Globals,
    origin: [i32; 3],
    resolution: usize,
    time: f32,
    last_step: Instant,
    accumulator: f64,
    material: Material,
    frame: Option<frame::Frame>,
    fill_buffer: wgpu::Buffer,
    fill_staging: wgpu::Buffer,
    fill_readback: Option<mpsc::Receiver<Result<(), String>>>,
    seed: u32,
    fill_frame: u32,
    settings: Settings,
}

impl Hooks for Watery {
    fn render(&self) -> Option<&dyn RenderHooks> {
        Some(self)
    }

    fn frame(&self, host: &mut dyn Host, _: &mut FrameEvent) {
        if !host.window() {
            return;
        }
        let mut s = self.state.lock().unwrap_or_else(|p| p.into_inner());
        s.camera = host.camera();
        s.terrain_frame = s.terrain_frame.wrapping_add(1);

        // Consume the previous frame's nonblocking GPU blockfill readback.
        let sound_context = s.runtime.as_ref().zip(s.camera.as_ref()).map(|(r, c)| {
            (r.material, c.position, r.settings.clone())
        });
        if let (Some(fill), Some((material, listener, settings))) =
            (s.pending_fill.take(), sound_context)
        {
            s.sounds.on_fill(material, &fill, listener, &settings);
        }
        for ev in s.sounds.tick() {
            let _ = host.play_local_sound(ev.sound, ev.position, ev.volume, ev.pitch, 0);
        }

        // The API's resource-reload notification is not yet in the trait hook
        // catalog; poll the cheap texture metadata periodically instead.
        if s.terrain_frame % 60 == 1 {
            let resources = host.client_resources();
            let mut changed = false;
            if let Some(px) = resources.texture("block/slime_block") {
                if let Ok(words) = atlas_tex::pack_rgba8(px.width, px.height, &px.rgba) {
                    if s.slime_words.as_ref() != Some(&words) {
                        s.slime_words = Some(words);
                        changed = true;
                    }
                }
            }
            if let Some(px) = resources.texture("block/sand") {
                if let Ok(words) = atlas_tex::pack_rgba8(px.width, px.height, &px.rgba) {
                    if s.sand_words.as_ref() != Some(&words) {
                        s.sand_words = Some(words);
                        changed = true;
                    }
                }
            }
            s.textures_dirty |= changed;
        }

        refresh_terrain(host, &self.state, &mut s);

        if let Some(error) = s.error.take() {
            host.log("error", &format!("Watery: {error}"));
        }
    }

    fn client_level_unload(
        &self,
        _: &mut dyn Host,
        _: &mut ClientLevelUnloadEvent<'_>,
    ) {
        let mut s = self.state.lock().unwrap_or_else(|p| p.into_inner());
        let generation = s.generation.wrapping_add(1);
        *s = State {
            generation,
            ..State::default()
        };
    }

    fn commands(&self, _: &mut dyn Host, e: &mut CommandsEvent<'_>) {
        e.commands.push("watery");
    }

    fn command(&self, host: &mut dyn Host, e: &mut CommandEvent<'_>) -> Flow {
        let mut words = e.command.trim_start_matches('/').split_whitespace();
        if words.next() != Some("watery") {
            return Flow::Continue;
        }
        let mut s = self.state.lock().unwrap_or_else(|p| p.into_inner());
        match (words.next(), words.next()) {
            (Some("diagnostic"), material) => {
                s.request = match material {
                    None | Some("water") => Some(Material::Water),
                    Some("sand") => Some(Material::Sand),
                    Some("lava") => Some(Material::Lava),
                    Some("slime") => Some(Material::Slime),
                    _ => None,
                };
                if s.request.is_some() {
                    host.log("info", "Watery: diagnostic region requested");
                } else {
                    host.log("info", "Watery: choose water, sand, lava, or slime");
                }
            }
            (Some("pause"), _) => {
                s.paused = !s.paused;
                host.log(
                    "info",
                    if s.paused {
                        "Watery: paused"
                    } else {
                        "Watery: resumed"
                    },
                );
            }
            (Some("clear"), _) => {
                s.runtime = None;
                s.request = None;
                s.generation = s.generation.wrapping_add(1);
                s.terrain_pending = false;
                s.terrain_dirty = false;
                s.terrain = None;
                s.snapshot = None;
                s.cache.clear();
                s.collision_boxes.clear();
                s.pending_fill = None;
                s.sounds.clear();
                host.log("info", "Watery: cleared");
            }
            (Some("status"), _) => {
                let msg = match &s.runtime {
                    Some(r) => format!(
                        "Watery: {} origin={:?} cells={:?} paused={} sections={} terrain_pending={}",
                        r.material.label(),
                        r.origin,
                        r.g.dims,
                        s.paused,
                        s.cache.len(),
                        s.terrain_pending
                    ),
                    None => "Watery: no active region (use /watery diagnostic <material>)".to_owned(),
                };
                host.log("info", &msg);
            }
            _ => host.log(
                "info",
                "Watery: /watery diagnostic [water|sand|lava|slime]; /watery status; /watery pause; /watery clear",
            ),
        }
        Flow::Cancel
    }
}

impl RenderHooks for Watery {
    fn render_needs(&self, e: &mut RenderNeedsEvent<'_>) {
        e.needs.world_depth = true;
    }

    fn world_drawn(&self, e: &mut WorldDrawnEvent<'_, '_>) {
        let mut s = self.state.lock().unwrap_or_else(|p| p.into_inner());
        let Some(camera) = s.camera.clone() else {
            return;
        };
        let w = &mut e.world;

        if let Some(material) = s.request.take() {
            match Runtime::new(w, &camera, material) {
                Ok(runtime) => {
                    s.generation = s.generation.wrapping_add(1);
                    s.runtime = Some(runtime);
                    s.terrain_pending = false;
                    s.terrain_dirty = true;
                    s.terrain = None;
                    s.snapshot = None;
                    s.cache.clear();
                    s.collision_boxes.clear();
                    s.pending_fill = None;
                    s.sounds.clear();
                }
                Err(err) => s.error = Some(err.to_owned()),
            }
        }

        if let Some((origin, mask)) = s.terrain.take() {
            if let Some(runtime) = &s.runtime {
                if runtime.origin == origin {
                    let upload = if let Some(fluid) = &runtime.fluid {
                        fluid.upload_solids(w.queue, &mask)
                    } else if let Some(sand) = &runtime.sand {
                        sand.upload_solids(w.queue, &mask)
                    } else {
                        Err("no active simulation")
                    };
                    if let Err(err) = upload {
                        s.error = Some(err.to_owned());
                    }
                }
            }
        }

        let frame_needs_textures = s.runtime.as_ref().is_some_and(|runtime| {
            runtime
                .frame
                .as_ref()
                .is_none_or(|frame| !frame.matches(w))
        });
        s.textures_dirty |= frame_needs_textures;

        let paused = s.paused;
        let record_result = s
            .runtime
            .as_mut()
            .map(|runtime| runtime.record(w, &camera, paused));
        match record_result {
            Some(Ok(Some(fill))) => s.pending_fill = Some(fill),
            Some(Ok(None)) | None => {}
            Some(Err(err)) => {
                s.error = Some(err.to_owned());
                s.runtime = None;
            }
        }

        if s.textures_dirty {
            let slime = s.slime_words.clone();
            let sand = s.sand_words.clone();
            let mut applied = false;
            if let Some(runtime) = &mut s.runtime {
                if let Some(frame) = &mut runtime.frame {
                    frame.set_material_textures(
                        w.device,
                        w.queue,
                        slime.as_deref(),
                        sand.as_deref(),
                    );
                    applied = true;
                }
            }
            if applied {
                s.textures_dirty = false;
            }
        }
    }
}

/// Refresh the collision cache for the diagnostic domain, then prepare an
/// exact simulation-resolution solid mask. World access stays on the host
/// thread; only pure box voxelization is sent to the worker pool.
fn refresh_terrain(host: &mut dyn Host, state_arc: &Arc<Mutex<State>>, state: &mut State) {
    let Some((origin, resolution)) = state
        .runtime
        .as_ref()
        .map(|runtime| (runtime.origin, runtime.resolution))
    else {
        return;
    };
    let block_dims = BLOCK_DIMS.map(|d| d as usize);
    let from = [origin[0].div_euclid(16), origin[2].div_euclid(16)];
    let to = [
        (origin[0] + BLOCK_DIMS[0] - 1).div_euclid(16),
        (origin[2] + BLOCK_DIMS[2] - 1).div_euclid(16),
    ];

    if let Some(snapshot) = &state.snapshot {
        for [cx, cz] in host.client_chunks_changed(snapshot) {
            state.cache.invalidate_chunk(cx, cz);
            state.collision_boxes.retain(|pos, _| {
                pos[0].div_euclid(16) != cx || pos[2].div_euclid(16) != cz
            });
            state.terrain_dirty = true;
        }
    }

    let snapshot = match host.client_chunks(from, to) {
        Ok(snapshot) => snapshot,
        Err(err) => {
            state.snapshot = None;
            state.terrain_dirty = true;
            if state.error.is_none() {
                state.error = Some(err);
            }
            return;
        }
    };

    for section in state.cache.missing_sections(origin, block_dims) {
        state.cache.insert_empty_section(section);
    }
    for z in 0..BLOCK_DIMS[2] {
        for y in 0..BLOCK_DIMS[1] {
            for x in 0..BLOCK_DIMS[0] {
                let pos = [origin[0] + x, origin[1] + y, origin[2] + z];
                if state.collision_boxes.contains_key(&pos) {
                    continue;
                }
                let loaded = snapshot.loaded([
                    pos[0].div_euclid(16),
                    pos[2].div_euclid(16),
                ]);
                let boxes = if loaded {
                    host.block_collision(pos)
                } else {
                    vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]]
                };
                let compact: Vec<[f32; 6]> = boxes
                    .iter()
                    .map(|b| std::array::from_fn(|i| b[i] as f32))
                    .collect();
                if let Err(err) = state.cache.update_block(pos, &compact) {
                    state.error = Some(err.to_owned());
                    continue;
                }
                state.collision_boxes.insert(pos, boxes);
                state.terrain_dirty = true;
            }
        }
    }
    state.snapshot = Some(snapshot);

    if !state.terrain_dirty || state.terrain_pending {
        return;
    }
    if resolution == CACHE_RES {
        match state.cache.extract_region(origin, block_dims, true) {
            Ok(mask) => {
                state.terrain = Some((origin, mask));
                state.terrain_dirty = false;
            }
            Err(err) => state.error = Some(err.to_owned()),
        }
        return;
    }

    let mut boxes = Vec::with_capacity(
        (BLOCK_DIMS[0] * BLOCK_DIMS[1] * BLOCK_DIMS[2]) as usize,
    );
    for z in 0..BLOCK_DIMS[2] {
        for y in 0..BLOCK_DIMS[1] {
            for x in 0..BLOCK_DIMS[0] {
                let pos = [origin[0] + x, origin[1] + y, origin[2] + z];
                boxes.push(
                    state
                        .collision_boxes
                        .get(&pos)
                        .cloned()
                        .unwrap_or_else(|| vec![[0.0, 0.0, 0.0, 1.0, 1.0, 1.0]]),
                );
            }
        }
    }
    let state_arc = Arc::clone(state_arc);
    let generation = state.generation;
    state.terrain_pending = true;
    state.terrain_dirty = false;
    host.spawn_task_with(
        move || watery_core::terrain::voxelize(block_dims, resolution, &boxes),
        move |_, result| {
            let mut state = state_arc.lock().unwrap_or_else(|p| p.into_inner());
            if state.generation != generation {
                return;
            }
            state.terrain_pending = false;
            if state.terrain_dirty {
                return;
            }
            match result {
                Ok(mask) => state.terrain = Some((origin, mask)),
                Err(err) => state.error = Some(err.to_owned()),
            }
        },
    );
}

impl Runtime {
    fn new(
        w: &WorldDrawn<'_>,
        camera: &NativeCamera,
        material: Material,
    ) -> Result<Self, &'static str> {
        let device = w.device;
        let queue = w.queue;
        let settings = Settings::default();
        let resolution = match material {
            Material::Water => settings.resolution,
            Material::Sand => settings.sandResolution,
            Material::Lava => settings.lavaResolution,
            Material::Slime => settings.slimeResolution,
        } as usize;
        if resolution == 0 {
            return Err("invalid material resolution");
        }
        let cells = BLOCK_DIMS.map(|d| d * resolution as i32);
        let mut g = watery_core::region::globals(
            &settings,
            material,
            cells,
            CAPACITY,
            DT,
            0.0,
        )?;
        let origin: [i32; 3] = std::array::from_fn(|i| {
            (camera.position[i].floor() as i64)
                .saturating_sub(2)
                .clamp(i32::MIN as i64, (i32::MAX - (BLOCK_DIMS[i] - 1)) as i64)
                as i32
        });

        // One source block at the top-centre of the region for fluid materials.
        if material.is_fluid_sim() {
            g.sources[0] = [
                (cells[0] / 2) as f32,
                (cells[1] * 3 / 4) as f32,
                (cells[2] / 2) as f32,
                1.0,
            ];
            g.flags[1] = 1;
        }

        // Start with a one-cell solid floor; the client collision snapshot
        // replaces this as soon as its worker/cache result is ready.
        let mut solids = vec![0u32; cells.iter().product::<i32>() as usize];
        for z in 0..cells[2] as usize {
            for x in 0..cells[0] as usize {
                solids[x + cells[0] as usize * cells[1] as usize * z] = 1;
            }
        }

        // A compact initial particle volume at half-cell spacing.
        let per_axis = cells.map(|d| (d / 2) as usize);
        let start = cells.map(|d| d as f32 * 0.25);
        let mut particles = Vec::new();
        for z in 0..per_axis[2] {
            for y in 0..per_axis[1] {
                for x in 0..per_axis[0] {
                    particles.push(Particle {
                        position: [
                            start[0] + x as f32 * 0.5,
                            start[1] + y as f32 * 0.5,
                            start[2] + z as f32 * 0.5,
                            0.0,
                        ],
                        velocity: [0.0; 4],
                    });
                }
            }
        }
        if particles.len() > CAPACITY as usize {
            return Err("initial particle volume exceeds capacity");
        }

        let options = watery_gpu::surface::SurfaceOptions {
            kernel: settings.surfaceKernel,
            radius: settings.surfaceRadius,
            sheet_smoothing: settings.sheetSmoothing,
            wall_reach: settings.wallFillReach as u32,
            smooth_sheets: settings.sheetFill,
        };

        let (mut fluid, mut sand, grains) = if material.is_granular() {
            let mut sand = watery_gpu::sand::Sand::new(device, cells, CAPACITY)?;
            sand.upload_globals(queue, &g)?;
            sand.upload_solids(queue, &solids)?;
            sand.reset(queue, &particles)?;
            let grains =
                watery_gpu::grains::SandRenderer::new(device, CAPACITY, w.color_format)?;
            (None, Some(sand), Some(grains))
        } else {
            let mut fluid = watery_gpu::fluid::Fluid::new(
                device,
                cells,
                CAPACITY,
                settings.cgIterations as u32,
                settings.mgCoarseSweeps as u32,
                settings.extrapolationLayers as u32,
            )?;
            fluid.configure_whitewater(device, material.uses_whitewater() && settings.whitewater, 0);
            if material == Material::Slime {
                fluid.configure_viscosity(
                    device,
                    Some((
                        settings.slimeViscosity * g.camGrid[3] * g.camGrid[3],
                        settings.slimeViscosityIterations as u32,
                    )),
                )?;
            }
            fluid.upload_globals(queue, &g)?;
            fluid.upload_solids(queue, &solids)?;
            fluid.reset(queue, &particles)?;
            (Some(fluid), None, None)
        };

        let (particles0, counters, solids) = if let Some(fluid) = &fluid {
            (fluid.particle_buffer(), fluid.counter_buffer(), fluid.solid_buffer())
        } else {
            let sand = sand.as_ref().expect("sand runtime allocated");
            (sand.particle_buffer(), sand.counter_buffer(), sand.solid_buffer())
        };
        let surface0 = watery_gpu::surface::Surface::new(
            device,
            &g,
            particles0,
            counters,
            solids,
            0,
            65536,
            196608,
            options,
        )?;
        {
            let mut encoder = device.create_command_encoder(&Default::default());
            if let Some(fluid) = &mut fluid {
                fluid.record_step(&mut encoder);
            } else if let Some(sand) = &mut sand {
                sand.record_step(&mut encoder);
            }
            queue.submit([encoder.finish()]);
        }
        let (particles1, counters, solids) = if let Some(fluid) = &fluid {
            (fluid.particle_buffer(), fluid.counter_buffer(), fluid.solid_buffer())
        } else {
            let sand = sand.as_ref().expect("sand runtime allocated");
            (sand.particle_buffer(), sand.counter_buffer(), sand.solid_buffer())
        };
        let surface1 = watery_gpu::surface::Surface::new(
            device,
            &g,
            particles1,
            counters,
            solids,
            1,
            65536,
            196608,
            options,
        )?;

        let fill_bytes = (BLOCK_DIMS.iter().product::<i32>() as u64) * 4;
        let fill_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Watery blockfill"),
            size: fill_bytes,
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        let fill_staging = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Watery blockfill readback"),
            size: fill_bytes,
            usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });

        Ok(Self {
            fluid,
            sand,
            surfaces: [surface0, surface1],
            mesh: watery_gpu::render::MeshRenderer::new(device),
            grains,
            g,
            origin,
            resolution,
            time: 0.0,
            last_step: Instant::now(),
            accumulator: 0.0,
            material,
            frame: None,
            fill_buffer,
            fill_staging,
            fill_readback: None,
            seed: 0,
            fill_frame: 0,
            settings,
        })
    }

    fn current_surface(&self) -> &watery_gpu::surface::Surface {
        let index = if let Some(fluid) = &self.fluid {
            fluid.current_counter()
        } else {
            self.sand
                .as_ref()
                .expect("sand runtime allocated")
                .current_counter()
        };
        &self.surfaces[index]
    }

    fn args_buffer(&self) -> &wgpu::Buffer {
        if let Some(fluid) = &self.fluid {
            fluid.args_buffer()
        } else {
            self.sand
                .as_ref()
                .expect("sand runtime allocated")
                .args_buffer()
        }
    }

    fn record(
        &mut self,
        w: &mut WorldDrawn<'_>,
        camera: &NativeCamera,
        paused: bool,
    ) -> Result<Option<BlockFill>, &'static str> {
        let mut camera = camera.clone();
        camera.position = w.camera.to_array();
        let resolution = self.g.camGrid[3];
        self.g.domainOrigin = [
            (self.origin[0] as f64 - camera.position[0]) as f32,
            (self.origin[1] as f64 - camera.position[1]) as f32,
            (self.origin[2] as f64 - camera.position[2]) as f32,
            1.0 / resolution,
        ];
        let camera_grid: [f32; 3] = std::array::from_fn(|axis| {
            ((camera.position[axis] - self.origin[axis] as f64) * resolution as f64) as f32
        });
        self.g.camGrid[..3].copy_from_slice(&camera_grid);
        self.g.misc[1..].copy_from_slice(&camera.position.map(|v| v as f32));

        let view = glam::Mat4::from_cols_array(&camera.view);
        let view_projection = glam::Mat4::from_cols_array(&w.jittered.to_cols_array());
        let projection = view_projection * view.inverse();
        self.g.view = view.to_cols_array_2d();
        self.g.invView = view.inverse().to_cols_array_2d();
        self.g.proj = projection.to_cols_array_2d();
        self.g.invProj = projection.inverse().to_cols_array_2d();
        let width = w.size[0].max(1) as f32;
        let height = w.size[1].max(1) as f32;
        self.g.screen = [width, height, width.recip(), height.recip()];

        let now = Instant::now();
        let elapsed = now.saturating_duration_since(self.last_step).as_secs_f64();
        self.last_step = now;
        if paused {
            self.accumulator = 0.0;
        } else {
            self.accumulator = (self.accumulator + elapsed).min(0.25);
            let step_dt = self.g.gravityDt[3] as f64;
            let max_steps = self.settings.maxStepsPerFrame.max(1) as u32;
            let steps = ((self.accumulator / step_dt).floor() as u32).min(max_steps);
            for _ in 0..steps {
                self.accumulator -= step_dt;
                self.time += self.g.gravityDt[3];
                self.g.simB[2] = self.time;
                if let Some(fluid) = &mut self.fluid {
                    fluid.upload_globals(w.queue, &self.g)?;
                    let mut encoder = w.device.create_command_encoder(&Default::default());
                    fluid.record_step(&mut encoder);
                    w.queue.submit([encoder.finish()]);
                } else if let Some(sand) = &mut self.sand {
                    sand.upload_globals(w.queue, &self.g)?;
                    let mut encoder = w.device.create_command_encoder(&Default::default());
                    sand.record_step(&mut encoder);
                    w.queue.submit([encoder.finish()]);
                }
            }

            // Source particles are generated after the step has populated the
            // cell counts; refresh indirect draw arguments in the same submit.
            if let Some(fluid) = &mut self.fluid {
                fluid.upload_globals(w.queue, &self.g)?;
                self.seed = self.seed.wrapping_add(1);
                let mut encoder = w.device.create_command_encoder(&Default::default());
                fluid.record_inflow(w.device, &mut encoder, 1, 4, self.seed)?;
                fluid.record_args(&mut encoder);
                w.queue.submit([encoder.finish()]);
            }
        }

        // Refresh/copy a ready map asynchronously. Never wait for the GPU on
        // the render thread; the next frame consumes the mapped bytes.
        let mut completed_fill = None;
        if let Some(receiver) = self.fill_readback.take() {
            match receiver.try_recv() {
                Ok(Ok(())) => {
                    let bytes = self
                        .fill_staging
                        .get_mapped_range(..)
                        .map_err(|_| "blockfill mapped range")?
                        .to_vec();
                    self.fill_staging.unmap();
                    let words = bytes
                        .chunks_exact(4)
                        .map(|chunk| u32::from_le_bytes(chunk.try_into().unwrap()))
                        .collect();
                    completed_fill = Some(BlockFill::new(
                        self.origin,
                        BLOCK_DIMS.map(|d| d as u32),
                        words,
                    )?);
                }
                Ok(Err(_)) => return Err("blockfill readback mapping failed"),
                Err(mpsc::TryRecvError::Empty) => self.fill_readback = Some(receiver),
                Err(mpsc::TryRecvError::Disconnected) => {
                    return Err("blockfill readback callback disconnected");
                }
            }
        }

        let args = self.args_buffer();
        let surface = self.current_surface();
        surface.upload_globals(w.queue, &self.g)?;
        surface.record(
            w.encoder,
            args,
            self.settings.sheetFill,
            self.settings.wallFill,
        );

        if !self.frame.as_ref().is_some_and(|frame| frame.matches(w)) {
            self.frame = Some(frame::Frame::new(w, self.g.dims[3] as u32));
        }
        let surface = self.current_surface();
        let frame = self.frame.as_ref().expect("frame was allocated");
        if let Some(fluid) = &self.fluid {
            let whitewater = if self.material.uses_whitewater() && self.settings.whitewater {
                Some(watery_gpu::whitewater::WhitewaterParams::default())
            } else {
                None
            };
            frame.record_fluid(
                w,
                &self.mesh,
                surface,
                fluid,
                &self.g,
                self.material.sync_id(),
                whitewater,
            )?;
        } else if let (Some(sand), Some(grains)) = (&self.sand, &self.grains) {
            frame.record_sand(
                w,
                grains,
                sand,
                surface,
                &self.g,
                self.settings.sandGrainsPerParticle as u32,
            )?;
        }

        self.fill_frame = self.fill_frame.wrapping_add(1);
        if !paused
            && self.fill_readback.is_none()
            && self.fill_frame % BLOCKFILL_PERIOD == 0
        {
            let mut encoder = w.device.create_command_encoder(&Default::default());
            if let Some(fluid) = &self.fluid {
                fluid.record_block_fill(
                    w.device,
                    &mut encoder,
                    [0; 3],
                    BLOCK_DIMS.map(|d| d as u32),
                    &self.fill_buffer,
                )?;
            } else if let Some(sand) = &self.sand {
                sand.record_block_fill(
                    w.device,
                    &mut encoder,
                    [0; 3],
                    BLOCK_DIMS.map(|d| d as u32),
                    &self.fill_buffer,
                )?;
            }
            encoder.copy_buffer_to_buffer(
                &self.fill_buffer,
                0,
                &self.fill_staging,
                0,
                self.fill_buffer.size(),
            );
            w.queue.submit([encoder.finish()]);
            let (sender, receiver) = mpsc::channel();
            self.fill_staging.map_async(wgpu::MapMode::Read, .., move |result| {
                let _ = sender.send(result.map_err(|_| "map failed".to_owned()));
            });
            self.fill_readback = Some(receiver);
        }
        Ok(completed_fill)
    }
}
