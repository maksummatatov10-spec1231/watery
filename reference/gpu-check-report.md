# GPU pipeline validation

Adapter: AdapterInfo { name: "Radeon RX 580 Series", vendor: 4098, device: 26591, device_type: DiscreteGpu, device_pci_bus_id: "", driver: "AMD proprietary driver", driver_info: "26.5.2 (AMD proprietary shader compiler)", backend: Vulkan, subgroup_min_size: 64, subgroup_max_size: 64, transient_saves_memory: Some(false), limit_bucket: None }

Pipeline creation and limited simulation regressions, not physics equivalence or performance measurement. Full adapter limits are requested; Horizon's device configuration must still be checked.

PASS args.wgsl

PASS blast.wgsl

PASS blockfill.wgsl

PASS blur.wgsl

PASS cg_apply.wgsl

PASS cg_direction.wgsl

PASS cg_dot.wgsl

PASS cg_init.wgsl

PASS cg_reduce.wgsl

PASS cg_update.wgsl

PASS classify.wgsl

PASS clear_box.wgsl

PASS divergence.wgsl

PASS droplet_cull.wgsl

PASS emit.wgsl

PASS extrapolate.wgsl

PASS faces.wgsl

PASS fine_clear.wgsl

PASS g2p.wgsl

PASS grain_cull.wgsl

PASS inflow.wgsl

PASS merge.wgsl

PASS mesh_args.wgsl

PASS mesh_bin.wgsl

PASS mesh_bin_total.wgsl

PASS mesh_depth.wgsl

PASS mesh_occupancy.wgsl

PASS mg_bottom.wgsl

PASS mg_coarse.wgsl

PASS mg_coarsen.wgsl

PASS mg_flags0.wgsl

PASS mg_prolong.wgsl

PASS mg_restrict.wgsl

PASS mg_smooth.wgsl

PASS mg_solve_small.wgsl

PASS mpm_clear.wgsl

PASS mpm_g2p.wgsl

PASS mpm_grid.wgsl

PASS mpm_p2g.wgsl

PASS nets_quads.wgsl

PASS nets_vertices.wgsl

PASS p2g.wgsl

PASS potential.wgsl

PASS probe.wgsl

PASS project.wgsl

PASS remove.wgsl

PASS sand_friction.wgsl

PASS sand_scale.wgsl

PASS sand_stress.wgsl

PASS scan_add.wgsl

PASS scan_local.wgsl

PASS sheet_fill.wgsl

PASS shift.wgsl

PASS splat.wgsl

PASS viscosity.wgsl

PASS wall_fill.wgsl

PASS ww_update.wgsl

PASS zb_field.wgsl

PASS zb_gather.wgsl

PASS zb_splat.wgsl

Total: 60 passed, 0 failed.

PASS execution: args/removal

PASS execution: MPM sand

PASS execution: FLIP/slime

PASS execution: multilevel FLIP

PASS execution: whitewater

PASS execution: surface

PASS execution: graphics
