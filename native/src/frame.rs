//! Frame bridge: convert sampleable reversed-Z depth to `R32Float` (and
//! seed `Depth32Float` for granular passes), retain a non-aliasing scene color
//! copy, render fluid meshes + whitewater + composition or MPM sand grains.
use horizon_client::mod_api::WorldDrawn;
use watery_core::{atlas_tex, uniforms::Globals};
use watery_gpu::{
    composite::Composite,
    fluid::Fluid,
    grains::SandRenderer,
    render::MeshRenderer,
    sand::Sand,
    surface::Surface,
    whitewater::{WhitewaterParams, WhitewaterRenderer},
};

pub struct Frame {
    size: [u32; 2],
    format: wgpu::TextureFormat,
    scene: wgpu::Texture,
    scene_view: wgpu::TextureView,
    scene_depth: wgpu::TextureView,
    gbuffer: wgpu::TextureView,
    material: wgpu::TextureView,
    depth: wgpu::TextureView,
    thickness: wgpu::TextureView,
    foam: wgpu::TextureView,
    blank: wgpu::TextureView,
    lightmap: wgpu::TextureView,
    region_light: wgpu::Buffer,
    slime: wgpu::Buffer,
    sand_tex: wgpu::Buffer,
    depth_copy: wgpu::RenderPipeline,
    depth_seed: wgpu::RenderPipeline,
    whitewater: WhitewaterRenderer,
    composite: Composite,
}

impl Frame {
    pub fn new(w: &WorldDrawn<'_>, cells: u32) -> Self {
        Self::new_raw(w.device, w.queue, w.size, w.color_format, cells)
    }

    pub fn new_raw(
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        size: [u32; 2],
        color_format: wgpu::TextureFormat,
        cells: u32,
    ) -> Self {
        let texture = |format, usage| {
            device.create_texture(&wgpu::TextureDescriptor {
                label: Some("Watery frame"),
                size: wgpu::Extent3d {
                    width: size[0],
                    height: size[1],
                    depth_or_array_layers: 1,
                },
                mip_level_count: 1,
                sample_count: 1,
                dimension: wgpu::TextureDimension::D2,
                format,
                usage,
                view_formats: &[],
            })
        };
        let rt = wgpu::TextureUsages::RENDER_ATTACHMENT | wgpu::TextureUsages::TEXTURE_BINDING;
        let scene = texture(color_format, rt | wgpu::TextureUsages::COPY_DST);
        let scene_view = scene.create_view(&Default::default());
        let view = |format| texture(format, rt).create_view(&Default::default());
        let source = r#"
@group(0) @binding(0) var src: texture_depth_2d;
struct Vertex { @builtin(position) position: vec4f, @location(0) uv: vec2f }
struct SeedOut { @location(0) r32_depth: f32, @builtin(frag_depth) hw_depth: f32 }
@vertex fn vs(@builtin(vertex_index) i: u32) -> Vertex {
    let p = vec2f(f32((i << 1u) & 2u), f32(i & 2u));
    return Vertex(vec4f(p * vec2f(2.0, -2.0) + vec2f(-1.0, 1.0), 0.0, 1.0), p);
}
fn sample_depth(uv: vec2f) -> f32 {
    let dims = textureDimensions(src);
    let p = clamp(vec2i(uv * vec2f(dims)), vec2i(0), vec2i(dims) - 1);
    return textureLoad(src, p, 0);
}
@fragment fn fs_r32(v: Vertex) -> @location(0) f32 {
    return sample_depth(v.uv);
}
@fragment fn fs_seed(v: Vertex) -> SeedOut {
    let d = sample_depth(v.uv);
    return SeedOut(d, d);
}
"#;
        let module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Watery host depth conversion"),
            source: wgpu::ShaderSource::Wgsl(source.into()),
        });
        let depth_copy = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Watery depth conversion"),
            layout: None,
            vertex: wgpu::VertexState {
                module: &module,
                entry_point: Some("vs"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &module,
                entry_point: Some("fs_r32"),
                compilation_options: Default::default(),
                targets: &[watery_gpu::render::target(wgpu::TextureFormat::R32Float, false)],
            }),
            primitive: Default::default(),
            depth_stencil: None,
            multisample: Default::default(),
            multiview_mask: None,
            cache: None,
        });
        let depth_seed = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("Watery depth seed"),
            layout: None,
            vertex: wgpu::VertexState {
                module: &module,
                entry_point: Some("vs"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &module,
                entry_point: Some("fs_seed"),
                compilation_options: Default::default(),
                targets: &[watery_gpu::render::target(wgpu::TextureFormat::R32Float, false)],
            }),
            primitive: Default::default(),
            depth_stencil: Some(wgpu::DepthStencilState {
                format: wgpu::TextureFormat::Depth32Float,
                depth_write_enabled: Some(true),
                depth_compare: Some(wgpu::CompareFunction::Always),
                stencil: Default::default(),
                bias: Default::default(),
            }),
            multisample: Default::default(),
            multiview_mask: None,
            cache: None,
        });
        let mk_buf = |bytes: &[u8]| {
            let b = device.create_buffer(&wgpu::BufferDescriptor {
                label: Some("Watery frame buffer"),
                size: bytes.len().max(16) as u64,
                usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
                mapped_at_creation: false,
            });
            if !bytes.is_empty() {
                queue.write_buffer(&b, 0, bytes);
            }
            b
        };
        // Full sky illumination default until block-light sampling is wired.
        let light_bytes: Vec<u8> = vec![0xf0u32; cells as usize]
            .into_iter()
            .flat_map(u32::to_le_bytes)
            .collect();
        let region_light = mk_buf(&light_bytes);
        let slime = mk_buf(&atlas_tex::to_le_bytes(&atlas_tex::default_slime_tex()));
        let sand_tex = mk_buf(&atlas_tex::to_le_bytes(&atlas_tex::default_sand_tex()));

        Self {
            size,
            format: color_format,
            scene,
            scene_view,
            scene_depth: view(wgpu::TextureFormat::R32Float),
            gbuffer: view(wgpu::TextureFormat::Rgba16Float),
            material: view(wgpu::TextureFormat::Rgba16Float),
            depth: view(wgpu::TextureFormat::Depth32Float),
            thickness: view(wgpu::TextureFormat::R16Float),
            foam: view(wgpu::TextureFormat::Rgba16Float),
            blank: view(wgpu::TextureFormat::Rgba16Float),
            lightmap: view(wgpu::TextureFormat::Rgba16Float),
            region_light,
            slime,
            sand_tex,
            depth_copy,
            depth_seed,
            whitewater: WhitewaterRenderer::new(device),
            composite: Composite::new(device, color_format),
        }
    }

    pub fn matches(&self, w: &WorldDrawn<'_>) -> bool {
        self.size == w.size && self.format == w.color_format
    }

    pub fn set_material_textures(
        &mut self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        slime_words: Option<&[i32]>,
        sand_words: Option<&[i32]>,
    ) {
        let replace = |target: &mut wgpu::Buffer, words: &[i32]| {
            let bytes = atlas_tex::to_le_bytes(words);
            if target.size() != bytes.len() as u64 {
                *target = device.create_buffer(&wgpu::BufferDescriptor {
                    label: Some("Watery material texture"),
                    size: bytes.len() as u64,
                    usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
                    mapped_at_creation: false,
                });
            }
            queue.write_buffer(target, 0, &bytes);
        };
        if let Some(words) = slime_words {
            replace(&mut self.slime, words);
        }
        if let Some(words) = sand_words {
            replace(&mut self.sand_tex, words);
        }
    }

    pub fn record_fluid(
        &self,
        w: &mut WorldDrawn<'_>,
        mesh: &MeshRenderer,
        surface: &Surface,
        fluid: &Fluid,
        g: &Globals,
        material: u8,
        whitewater_params: Option<WhitewaterParams>,
    ) -> Result<(), &'static str> {
        self.record_fluid_raw(
            w.device,
            w.queue,
            w.encoder,
            w.color,
            w.color_view,
            w.depth,
            mesh,
            surface,
            fluid,
            g,
            material,
            whitewater_params,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn record_fluid_raw(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        encoder: &mut wgpu::CommandEncoder,
        color: &wgpu::Texture,
        color_view: &wgpu::TextureView,
        host_depth: &wgpu::TextureView,
        mesh: &MeshRenderer,
        surface: &Surface,
        fluid: &Fluid,
        g: &Globals,
        material: u8,
        whitewater_params: Option<WhitewaterParams>,
    ) -> Result<(), &'static str> {
        encoder.copy_texture_to_texture(
            color.as_image_copy(),
            self.scene.as_image_copy(),
            wgpu::Extent3d {
                width: self.size[0],
                height: self.size[1],
                depth_or_array_layers: 1,
            },
        );
        let depth_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &self.depth_copy.get_bind_group_layout(0),
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(host_depth),
            }],
        });
        let attachment = |view, clear| {
            Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                depth_slice: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(clear),
                    store: wgpu::StoreOp::Store,
                },
            })
        };
        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Watery scene depth"),
                color_attachments: &[attachment(&self.scene_depth, wgpu::Color::TRANSPARENT)],
                ..Default::default()
            });
            pass.set_pipeline(&self.depth_copy);
            pass.set_bind_group(0, &depth_group, &[]);
            pass.draw(0..3, 0..1);
        }
        {
            let _pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Watery auxiliary targets"),
                color_attachments: &[
                    attachment(&self.blank, wgpu::Color::TRANSPARENT),
                    attachment(&self.foam, wgpu::Color::TRANSPARENT),
                    attachment(&self.lightmap, wgpu::Color::WHITE),
                ],
                ..Default::default()
            });
        }
        let view_buf = fluid.view_state_buffer();
        mesh.upload(queue, g, false)?;
        let mesh_groups = mesh.bind_with_view(
            device,
            &surface.vertices,
            &surface.quads,
            &self.region_light,
            &self.scene_depth,
            view_buf,
        );
        mesh.record(
            encoder,
            &mesh_groups,
            &surface.counters,
            &self.gbuffer,
            &self.material,
            &self.depth,
            &self.thickness,
        );

        if let Some(params) = whitewater_params {
            self.whitewater.upload(queue, g, false, params)?;
            let ww_groups = self.whitewater.bind_with_view(
                device,
                fluid.whitewater_buffer(),
                &self.scene_depth,
                &self.gbuffer,
                view_buf,
            );
            self.whitewater
                .record(encoder, &ww_groups, fluid.args_buffer(), &self.foam, true);
        }

        self.composite.upload(queue, g, false, material)?;
        let comp_groups = self.composite.bind_with_view(
            device,
            [
                &self.gbuffer,
                &self.thickness,
                &self.scene_view,
                &self.scene_depth,
                &self.foam,
                &self.material,
                &self.blank,
                &self.lightmap,
                &self.blank,
                &self.blank,
                &self.blank,
            ],
            &self.slime,
            view_buf,
        );
        self.composite
            .record(encoder, &comp_groups, color_view, &self.depth);
        Ok(())
    }

    pub fn record_sand(
        &self,
        w: &mut WorldDrawn<'_>,
        grains: &SandRenderer,
        sand: &Sand,
        surface: &Surface,
        g: &Globals,
        child_grains: u32,
    ) -> Result<(), &'static str> {
        let depth_group = w.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: None,
            layout: &self.depth_seed.get_bind_group_layout(0),
            entries: &[wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(w.depth),
            }],
        });
        let attachment = |view, clear| {
            Some(wgpu::RenderPassColorAttachment {
                view,
                resolve_target: None,
                depth_slice: None,
                ops: wgpu::Operations {
                    load: wgpu::LoadOp::Clear(clear),
                    store: wgpu::StoreOp::Store,
                },
            })
        };
        {
            let mut pass = w.encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Watery sand depth seed"),
                color_attachments: &[attachment(&self.scene_depth, wgpu::Color::TRANSPARENT)],
                depth_stencil_attachment: Some(wgpu::RenderPassDepthStencilAttachment {
                    view: &self.depth,
                    depth_ops: Some(wgpu::Operations {
                        load: wgpu::LoadOp::Clear(0.0),
                        store: wgpu::StoreOp::Store,
                    }),
                    stencil_ops: None,
                }),
                ..Default::default()
            });
            pass.set_pipeline(&self.depth_seed);
            pass.set_bind_group(0, &depth_group, &[]);
            pass.draw(0..3, 0..1);
        }
        {
            let _pass = w.encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("Watery sand auxiliary targets"),
                color_attachments: &[
                    attachment(&self.blank, wgpu::Color::TRANSPARENT),
                    attachment(&self.lightmap, wgpu::Color::WHITE),
                ],
                ..Default::default()
            });
        }
        grains.upload(w.queue, g, child_grains)?;
        let groups = grains.bind(
            w.device,
            &self.sand_tex,
            &self.region_light,
            [
                &self.blank,
                &self.lightmap,
                &self.blank,
                &self.blank,
                &self.blank,
            ],
        );
        grains.record(
            w.device,
            w.encoder,
            sand,
            &surface.density,
            &groups,
            w.color_view,
            &self.depth,
        );
        Ok(())
    }
}
