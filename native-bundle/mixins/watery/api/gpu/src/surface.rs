//! Original Zhu–Bridson splat field and Surface Nets topology.
//! Full-domain path, interior skip disabled. Gather path is not implemented here.
use crate::{BoundKernel, Dispatch, Kernel};
use watery_core::uniforms::Globals;

pub struct Surface {
    dims: [i32;3], fine: [i32;3], subdivision:i32, particle_capacity:i32,
    pub vertices: wgpu::Buffer, pub quads: wgpu::Buffer,
    pub counters: wgpu::Buffer, pub density: wgpu::Buffer,
    globals: wgpu::Buffer, scratch: wgpu::Buffer,
    clear: BoundKernel, splat: BoundKernel, field: BoundKernel,
    blur: [BoundKernel;3], sheet: [BoundKernel;3], wall: BoundKernel,
    nets_vertices: BoundKernel, nets_quads: BoundKernel, args: BoundKernel,
}
#[derive(Clone, Copy)]
pub struct SurfaceOptions {
    pub kernel: f32, pub radius: f32, pub sheet_smoothing: f32,
    pub wall_reach: u32, pub smooth_sheets: bool,
}
impl Default for SurfaceOptions {
    fn default() -> Self { Self {kernel:2.8,radius:0.8,sheet_smoothing:2.0,wall_reach:0,smooth_sheets:false} }
}
impl Surface {
    pub fn new(device: &wgpu::Device, g: &Globals, particles: &wgpu::Buffer,
        particle_counters: &wgpu::Buffer, solids: &wgpu::Buffer, particle_counter: u32,
        vertex_capacity: u32, quad_capacity: u32, options: SurfaceOptions,
    ) -> Result<Self, &'static str> {
        crate::validation::globals(g, g.matA[0] == 1.0)?;
        crate::validation::limits(&device.limits(), 5)?;
        let cube_count = g.fine[..3].iter().try_fold(1i32, |n, &v| v.checked_add(1).and_then(|v| n.checked_mul(v)))
            .ok_or("surface cube count overflow")?;
        let fine_count = g.fine[..3].iter().try_fold(1i32, |n, &v| n.checked_mul(v))
            .ok_or("surface voxel count overflow")?;
        let dims: [i32;3] = g.dims[..3].try_into().unwrap();
        let fine: [i32;3] = g.fine[..3].try_into().unwrap();
        if dims.iter().any(|&v| v <= 0) || fine.iter().any(|&v| v <= 0)
            || g.fineBoxMax[3] != cube_count || g.caps[0] <= 0
            || !g.surf.iter().chain(&g.waterA).all(|v| v.is_finite())
            || g.surf[0] <= 0.0 || g.waterA[3] < 0.0
            || g.fine[3] <= 0 || (0..3).any(|a| dims[a].checked_mul(g.fine[3]) != Some(fine[a]))
            || g.fineBoxMin[..3] != [0;3] || g.fineBoxMax[..3] != fine
            || g.fineBoxMin[3] != fine_count
            || vertex_capacity == 0 || quad_capacity == 0 || particle_counter > 1
            || !options.kernel.is_finite() || options.kernel <= 0.0
            || !options.radius.is_finite() || options.radius <= 0.0
            || !options.sheet_smoothing.is_finite() || options.sheet_smoothing < 0.0
            || options.wall_reach > 128 { return Err("invalid surface geometry/options"); }
        let n = fine.iter().map(|&v| v as u64).product::<u64>();
        let coarse = dims.iter().map(|&v| v as u64).product::<u64>();
        let limits = device.limits();
        for bytes in [n*16, cube_count as u64*4, coarse*4, vertex_capacity as u64*16, quad_capacity as u64*16] {
            if bytes > limits.max_buffer_size || bytes > limits.max_storage_buffer_binding_size as u64 {
                return Err("surface buffer exceeds device limits");
            }
        }
        if (cube_count as u64).div_ceil(256) > limits.max_compute_workgroups_per_dimension as u64
            || limits.max_compute_invocations_per_workgroup < 256
            || limits.max_compute_workgroup_size_x < 256
            || particles.size() < g.caps[0] as u64*32 || particle_counters.size() < 16
            || solids.size() < coarse*4 { return Err("surface dispatch/input exceeds limits"); }
        let usage = wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::COPY_SRC;
        let alloc = |size| device.create_buffer(&wgpu::BufferDescriptor {label:Some("Watery surface"),size,usage,mapped_at_creation:false});
        let globals = device.create_buffer(&wgpu::BufferDescriptor {label:None,size:Globals::BYTE_SIZE as u64,
            usage:wgpu::BufferUsages::UNIFORM|wgpu::BufferUsages::COPY_DST,mapped_at_creation:false});
        let zb = alloc(n*16); let depth = alloc(coarse*4);
        let density = alloc(n*4); let scratch = alloc(n*4); let accum = alloc(n*4);
        let ids = alloc(fine.iter().map(|v| (*v as u64)+1).product::<u64>()*4); let vertices = alloc(vertex_capacity as u64*16);
        let quads = alloc(quad_capacity as u64*16);
        let counters = device.create_buffer(&wgpu::BufferDescriptor {label:None,size:64,
            usage:usage|wgpu::BufferUsages::INDIRECT,mapped_at_creation:false});
        macro_rules! k { ($name:literal) => { Kernel::new(device,$name,include_str!(concat!("../../data/shaders/",$name,".wgsl"))) }; }
        let clear = k!("fine_clear").bind(device,&[&globals,&zb,&depth],&[0;8]);
        let splat = k!("zb_splat").bind(device,&[&globals,particles,particle_counters,&zb,&depth],
            &[particle_counter,0,0,0,options.kernel.to_bits(),0,0,0]);
        let field = k!("zb_field").bind(device,&[&globals,&zb,&scratch,&depth],
            &[0,0,0,0,options.radius.to_bits(),1f32.to_bits(),3f32.to_bits(),0]);
        let blur_kernel = k!("blur");
        // Vulkan allows aliasing an unused source. wgpu does not: the integer
        // input is kept distinct from both live float buffers in every pass.
        let blur = std::array::from_fn(|axis| {
            let (src,dst) = if axis == 1 { (&accum,&scratch) } else if axis == 0 { (&scratch,&accum) } else { (&scratch,&density) };
            blur_kernel.bind(device,&[&globals,&zb,src,dst],&[axis as u32,0,u32::from(axis==2),0,0,0,0,0])
        });
        let sheet_kernel = k!("sheet_fill");
        let sheet = std::array::from_fn(|axis| sheet_kernel.bind(device,&[&globals,&density,&scratch,&accum],
            &[axis as u32,0,0,0,options.sheet_smoothing.to_bits(),0,0,0]));
        let wall = k!("wall_fill").bind(device,&[&globals,&scratch,&density,solids],&[options.wall_reach,0,0,0,0,0,0,0]);
        let nets_vertices = k!("nets_vertices").bind(device,&[&globals,&density,&ids,&vertices,&counters,solids],&[vertex_capacity,0,0,0,0,0,0,0]);
        let nets_quads = k!("nets_quads").bind(device,&[&globals,&density,&ids,&quads,&counters],&[0,quad_capacity,0,0,0,0,0,0]);
        let args = k!("mesh_args").bind(device,&[&globals,&counters],&[0,quad_capacity,0,0,0,0,0,0]);
        Ok(Self {dims,fine,subdivision:g.fine[3],particle_capacity:g.caps[0],vertices,quads,counters,density,globals,scratch,clear,splat,field,blur,sheet,wall,nets_vertices,nets_quads,args})
    }
    pub fn upload_globals(&self, queue: &wgpu::Queue, g: &Globals) -> Result<(), &'static str> {
        crate::validation::globals(g, g.matA[0] == 1.0)?;
        if g.dims[..3] != self.dims || g.fine[..3] != self.fine
            || g.fine[3]!=self.subdivision || g.caps[0]!=self.particle_capacity
            || g.fineBoxMax[3]!=self.fine.iter().map(|v|v+1).product::<i32>()
            || g.fineBoxMin[..3] != [0;3] || g.fineBoxMax[..3] != self.fine
            || g.fineBoxMin[3] != self.fine.iter().product::<i32>() { return Err("surface domain changed"); }
        let mut bytes = vec![0;Globals::BYTE_SIZE];
        g.write_le(&mut bytes).map_err(|_|"globals size")?;
        queue.write_buffer(&self.globals,0,&bytes); Ok(())
    }
    pub fn record(&self, encoder: &mut wgpu::CommandEncoder, particle_args: &wgpu::Buffer,
        smooth_sheets: bool, wall_fill: bool) {
        let n = self.fine.iter().product::<i32>() as u32;
        let cubes = self.fine.iter().map(|v| (v+1) as u32).product::<u32>();
        encoder.clear_buffer(&self.counters,0,None);
        self.clear.record(encoder,Dispatch::Direct(n.div_ceil(256)));
        self.splat.record(encoder,Dispatch::Indirect(particle_args));
        self.field.record(encoder,Dispatch::Direct(n.div_ceil(256)));
        for pass in &self.blur { pass.record(encoder,Dispatch::Direct(n.div_ceil(256))); }
        if smooth_sheets { for pass in &self.sheet { pass.record(encoder,Dispatch::Direct(n.div_ceil(256))); } }
        if wall_fill {
            encoder.copy_buffer_to_buffer(&self.density,0,&self.scratch,0,n as u64*4);
            self.wall.record(encoder,Dispatch::Direct(n.div_ceil(256)));
        }
        self.nets_vertices.record(encoder,Dispatch::Direct(cubes.div_ceil(256)));
        self.nets_quads.record(encoder,Dispatch::Direct(cubes.div_ceil(256)));
        self.args.record(encoder,Dispatch::Direct(1));
    }
}
