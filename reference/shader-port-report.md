# Original GLSL → Horizon Naga → WGSL validation

This is offline compilation, not GPU or game verification. Capabilities are unrestricted during validation; target device limits still need checking.

PASS args.comp

PASS blast.comp

PASS blockfill.comp

PASS blur.comp

PASS cg_apply.comp

PASS cg_direction.comp

PASS cg_dot.comp

PASS cg_init.comp

PASS cg_reduce.comp

PASS cg_update.comp

PASS classify.comp

PASS clear_box.comp

PASS composite.frag

PASS divergence.comp

PASS droplet_cull.comp

PASS droplet_front.frag

PASS droplet_thickness.frag

PASS emit.comp

PASS extrapolate.comp

PASS faces.comp

PASS fine_clear.comp

PASS fullscreen.vert

PASS g2p.comp

PASS grain.frag

PASS grain.vert

PASS grain_cull.comp

PASS inflow.comp

PASS merge.comp

PASS mesh.vert

PASS mesh_args.comp

PASS mesh_bin.comp

PASS mesh_bin_total.comp

PASS mesh_depth.comp

PASS mesh_front.frag

PASS mesh_occupancy.comp

PASS mesh_thickness.frag

PASS mg_bottom.comp

PASS mg_coarse.comp

PASS mg_coarsen.comp

PASS mg_flags0.comp

PASS mg_prolong.comp

PASS mg_restrict.comp

PASS mg_smooth.comp

PASS mg_solve_small.comp

PASS mpm_clear.comp

PASS mpm_g2p.comp

PASS mpm_grid.comp

PASS mpm_p2g.comp

PASS nets_quads.comp

PASS nets_vertices.comp

PASS p2g.comp

PASS particle.vert

PASS potential.comp

PASS probe.comp

PASS project.comp

PASS remove.comp

PASS sand_friction.comp

UNUSED sand_mesh.frag: original resource has unresolved bindings and a removed sandLight overload; original SandRenderer uses grain.vert/grain.frag. Not translated.

PASS sand_scale.comp

PASS sand_stress.comp

PASS scan_add.comp

PASS scan_local.comp

PASS sheet_fill.comp

PASS shift.comp

PASS splat.comp

PASS viscosity.comp

PASS wall_fill.comp

PASS whitewater.frag

PASS ww_update.comp

PASS zb_field.comp

PASS zb_gather.comp

PASS zb_splat.comp

PASS particle.vert (DROPLETS, VIEW_BINDING=3)

Total: 72 passed, 0 failed.
