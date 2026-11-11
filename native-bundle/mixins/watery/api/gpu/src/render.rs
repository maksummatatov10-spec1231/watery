//! Original mesh G-buffer and additive thickness passes, host independent.
//! Composition/whitewater use the native frame bridge; this is not a complete game renderer.
use watery_core::uniforms::Globals;

pub struct MeshRenderer {
    front: wgpu::RenderPipeline,
    thickness: wgpu::RenderPipeline,
    globals: wgpu::Buffer,
    view: wgpu::Buffer,
}
pub struct MeshGroups { front: wgpu::BindGroup, thickness: wgpu::BindGroup, samplers: wgpu::BindGroup, empty: wgpu::BindGroup }

pub fn pipeline(device: &wgpu::Device, label: &str, vertex: &str, fragment: &str,
    targets: &[Option<wgpu::ColorTargetState>], depth: Option<wgpu::DepthStencilState>) -> wgpu::RenderPipeline {
    let module = |source: &str| device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some(label), source: wgpu::ShaderSource::Wgsl(source.to_owned().into()),
    });
    let vs = module(vertex); let fs = module(fragment);
    // R32Float scene depth is not filterable on baseline devices. Inferred
    // layouts incorrectly require a filterable texture even for nearest sampling.
    let thickness_layout = (label == "Watery mesh thickness").then(|| {
        let buffer = |binding, ty| wgpu::BindGroupLayoutEntry { binding,
            visibility: wgpu::ShaderStages::VERTEX_FRAGMENT,
            ty: wgpu::BindingType::Buffer {ty,has_dynamic_offset:false,min_binding_size:None},count:None };
        let group0 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {label:None,entries:&[
            buffer(0,wgpu::BufferBindingType::Uniform),
            buffer(1,wgpu::BufferBindingType::Storage {read_only:true}),
            buffer(2,wgpu::BufferBindingType::Storage {read_only:true}),
            wgpu::BindGroupLayoutEntry {binding:4,visibility:wgpu::ShaderStages::FRAGMENT,
                ty:wgpu::BindingType::Texture {sample_type:wgpu::TextureSampleType::Float {filterable:false},view_dimension:wgpu::TextureViewDimension::D2,multisampled:false},count:None},
        ]});
        let group1 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {label:None,entries:&[]});
        let group2 = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {label:None,entries:&[
            wgpu::BindGroupLayoutEntry {binding:4,visibility:wgpu::ShaderStages::FRAGMENT,ty:wgpu::BindingType::Sampler(wgpu::SamplerBindingType::NonFiltering),count:None}
        ]});
        device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {label:None,bind_group_layouts:&[Some(&group0),Some(&group1),Some(&group2)],immediate_size:0})
    });
    device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label:Some(label), layout:thickness_layout.as_ref(),
        vertex:wgpu::VertexState {module:&vs, entry_point:Some("main"), compilation_options:Default::default(), buffers:&[]},
        fragment:Some(wgpu::FragmentState {module:&fs, entry_point:Some("main"), compilation_options:Default::default(), targets}),
        primitive:Default::default(), depth_stencil:depth, multisample:Default::default(), multiview_mask:None,cache:None,
    })
}
pub fn target(format:wgpu::TextureFormat, additive:bool)->Option<wgpu::ColorTargetState> {
    let add=wgpu::BlendComponent {src_factor:wgpu::BlendFactor::One,dst_factor:wgpu::BlendFactor::One,operation:wgpu::BlendOperation::Add};
    Some(wgpu::ColorTargetState {format,blend:additive.then_some(wgpu::BlendState {color:add,alpha:add}),write_mask:wgpu::ColorWrites::ALL})
}
impl MeshRenderer {
    pub fn new(device:&wgpu::Device)->Self {
        let front=pipeline(device,"Watery mesh front",include_str!("../../data/shaders/mesh_vert.wgsl"),include_str!("../../data/shaders/mesh_front_frag.wgsl"),
            &[target(wgpu::TextureFormat::Rgba16Float,false),target(wgpu::TextureFormat::Rgba16Float,false)],
            Some(wgpu::DepthStencilState {format:wgpu::TextureFormat::Depth32Float,depth_write_enabled:Some(true),depth_compare:Some(wgpu::CompareFunction::GreaterEqual),stencil:Default::default(),bias:Default::default()}));
        let thickness=pipeline(device,"Watery mesh thickness",include_str!("../../data/shaders/mesh_vert.wgsl"),include_str!("../../data/shaders/mesh_thickness_frag.wgsl"),
            &[target(wgpu::TextureFormat::R16Float,true)],None);
        let buffer=|size|device.create_buffer(&wgpu::BufferDescriptor {label:None,size,usage:wgpu::BufferUsages::UNIFORM|wgpu::BufferUsages::STORAGE|wgpu::BufferUsages::COPY_DST,mapped_at_creation:false});
        Self {front,thickness,globals:buffer(Globals::BYTE_SIZE as u64),view:buffer(16)}
    }
    /// Scene depth is an R32Float copy of host depth, not Depth32Float: the
    /// original shaders sample a non-comparison floating-point texture.
    pub fn bind(&self,device:&wgpu::Device,vertices:&wgpu::Buffer,quads:&wgpu::Buffer,
        region_light:&wgpu::Buffer, scene_depth:&wgpu::TextureView)->MeshGroups {
        self.bind_with_view(device,vertices,quads,region_light,scene_depth,&self.view)
    }
    pub fn bind_with_view(&self,device:&wgpu::Device,vertices:&wgpu::Buffer,quads:&wgpu::Buffer,
        region_light:&wgpu::Buffer, scene_depth:&wgpu::TextureView, view_state:&wgpu::Buffer)->MeshGroups {
        let bind=|pipeline:&wgpu::RenderPipeline, group, entries:&[wgpu::BindGroupEntry<'_>]| device.create_bind_group(&wgpu::BindGroupDescriptor {label:None,layout:&pipeline.get_bind_group_layout(group),entries});
        fn buffer(binding:u32,b:&wgpu::Buffer)->wgpu::BindGroupEntry<'_> {wgpu::BindGroupEntry {binding,resource:b.as_entire_binding()}}
        let front=bind(&self.front,0,&[buffer(0,&self.globals),buffer(1,vertices),buffer(2,quads),buffer(3,view_state),buffer(4,region_light)]);
        let thickness=bind(&self.thickness,0,&[buffer(0,&self.globals),buffer(1,vertices),buffer(2,quads),wgpu::BindGroupEntry {binding:4,resource:wgpu::BindingResource::TextureView(scene_depth)}]);
        let sampler=device.create_sampler(&wgpu::SamplerDescriptor::default());
        let samplers=bind(&self.thickness,2,&[wgpu::BindGroupEntry {binding:4,resource:wgpu::BindingResource::Sampler(&sampler)}]);
        let empty=bind(&self.thickness,1,&[]);
        MeshGroups {front,thickness,samplers,empty}
    }
    pub fn upload(&self,queue:&wgpu::Queue,g:&Globals,underwater:bool)->Result<(), &'static str> {
        let mut bytes=vec![0;Globals::BYTE_SIZE];g.write_le(&mut bytes).map_err(|_|"globals size")?;
        queue.write_buffer(&self.globals,0,&bytes);
        // ViewState.x is a float, not a boolean word.
        queue.write_buffer(&self.view,0,&(if underwater {1.0f32}else{0.0}).to_le_bytes());
        Ok(())
    }
    pub fn record(&self,encoder:&mut wgpu::CommandEncoder,groups:&MeshGroups,mesh_args:&wgpu::Buffer,
        gbuffer:&wgpu::TextureView,material:&wgpu::TextureView,depth:&wgpu::TextureView,thickness:&wgpu::TextureView) {
        let attachment=|view|Some(wgpu::RenderPassColorAttachment {view,resolve_target:None,depth_slice:None,ops:wgpu::Operations {load:wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),store:wgpu::StoreOp::Store}});
        {
            let mut pass=encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label:Some("Watery front surface"),color_attachments:&[attachment(gbuffer),attachment(material)],
                depth_stencil_attachment:Some(wgpu::RenderPassDepthStencilAttachment {view:depth,depth_ops:Some(wgpu::Operations {load:wgpu::LoadOp::Clear(0.0),store:wgpu::StoreOp::Store}),stencil_ops:None}),..Default::default()
            });
            pass.set_pipeline(&self.front);pass.set_bind_group(0,&groups.front,&[]);pass.draw_indirect(mesh_args,16);
        }
        let mut pass=encoder.begin_render_pass(&wgpu::RenderPassDescriptor {label:Some("Watery thickness"),color_attachments:&[attachment(thickness)],..Default::default()});
        pass.set_pipeline(&self.thickness);pass.set_bind_group(0,&groups.thickness,&[]);pass.set_bind_group(1,&groups.empty,&[]);pass.set_bind_group(2,&groups.samplers,&[]);pass.draw_indirect(mesh_args,16);
    }
}
