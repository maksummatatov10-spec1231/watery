use watery_core::uniforms::Globals;

pub(crate) fn globals(g: &Globals, sand: bool) -> Result<(), &'static str> {
    if !(0..=32).contains(&g.caps[2]) {
        return Err("entity count outside fixed uniform capacity");
    }
    for entity in g.ent[..g.caps[2] as usize * 3].chunks_exact(3) {
        if (0..3).any(|axis| entity[0][axis] > entity[1][axis]) {
            return Err("reversed entity bounds");
        }
    }
    if !(0..=16).contains(&g.removeInfo[0]) {
        return Err("removal count outside fixed uniform capacity");
    }
    for pair in g.removeBox[..g.removeInfo[0] as usize * 2].chunks_exact(2) {
        if (0..3).any(|axis| {
            !pair[0][axis].is_finite()
                || !pair[1][axis].is_finite()
                || pair[0][axis] > pair[1][axis]
        }) {
            return Err("invalid removal bounds");
        }
    }
    let values = [
        &g.gravityDt,
        &g.simA,
        &g.simB,
        &g.matA,
        &g.matB,
        &g.matC,
        &g.matD,
        &g.matE,
        &g.killInfo,
        &g.camGrid,
        &g.wwA,
        &g.wwB,
        &g.wwC,
        &g.wwD,
    ];
    if values
        .into_iter()
        .flatten()
        .chain(g.ent.iter().flatten())
        .any(|v| !v.is_finite())
    {
        return Err("nonfinite simulation uniform");
    }
    if g.gravityDt[3] <= 0.0 || g.simB[0] <= 0.0 || g.simB[1] <= 0.0 || g.killInfo[1] < 0.0 {
        return Err("invalid timestep, speed, cell size or kill margin");
    }
    if sand {
        if g.matA[0] != 1.0 || g.matB[0] < 0.0 || g.matB[1] <= 0.0 || g.matC[1] <= 0.0 {
            return Err("invalid sand material or constitutive divisors");
        }
    } else if !matches!(g.matA[0], 0.0 | 2.0 | 3.0)
        || g.simA[1] <= 0.0
        || !(0.0..=1.0).contains(&g.simA[0])
    {
        return Err("invalid fluid material, density or FLIP ratio");
    }
    Ok(())
}

pub(crate) fn limits(l: &wgpu::Limits, storage: u32) -> Result<(), &'static str> {
    if l.max_storage_buffers_per_shader_stage < storage
        || l.max_bind_groups < 2
        || l.max_bindings_per_bind_group < storage + 2
        || l.max_uniform_buffers_per_shader_stage < 2
        || l.max_uniform_buffer_binding_size < Globals::BYTE_SIZE as u64
    {
        return Err("device binding limits insufficient for original graph");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fluid() -> Globals {
        let mut g = Globals::zeroed();
        g.gravityDt[3] = 1.0 / 120.0;
        g.simB = [100.0, 1.0 / 6.0, 0.0, 0.0];
        g.simA = [0.99, 8.0, 0.0, 0.0];
        g
    }
    #[test]
    fn rejects_unbounded_entities_and_nonfinite_or_zero_divisors() {
        let original = fluid();
        assert!(globals(&original, false).is_ok());
        for n in [-1, 33, i32::MAX] {
            let mut g = original.clone();
            g.caps[2] = n;
            assert!(globals(&g, false).is_err());
        }
        for v in [0.0, -1.0, f32::NAN, f32::INFINITY] {
            let mut g = original.clone();
            g.simA[1] = v;
            assert!(globals(&g, false).is_err());
            let mut g = original.clone();
            g.gravityDt[3] = v;
            assert!(globals(&g, false).is_err());
        }
        let mut g = original;
        g.matA[0] = 1.0;
        g.matB[1] = 1.0;
        g.matC[1] = 1.0;
        assert!(globals(&g, true).is_ok());
        g.matB[1] = 0.0;
        assert!(globals(&g, true).is_err());
    }
    #[test]
    fn entity_bounds_validate_before_gpu_upload() {
        let mut g = fluid();
        g.caps[2] = 1;
        g.ent[1] = [1.0; 4];
        assert!(globals(&g, false).is_ok());
        g.ent[0][0] = 2.0;
        assert!(globals(&g, false).is_err());
        g.ent[0][0] = 0.0;
        g.ent[2][0] = f32::INFINITY;
        assert!(globals(&g, false).is_err());
    }
    #[test]
    fn removal_bounds_validate_before_gpu_upload() {
        let mut g = fluid();
        for count in [-1, 17, i32::MAX] {
            g.removeInfo[0] = count;
            assert!(globals(&g, false).is_err());
        }
        g.removeInfo[0] = 1;
        g.removeBox[1] = [1.0; 4];
        assert!(globals(&g, false).is_ok());
        g.removeBox[0][0] = 2.0;
        assert!(globals(&g, false).is_err());
        g.removeBox[0][0] = f32::NAN;
        assert!(globals(&g, false).is_err());
    }
    #[test]
    fn restricted_binding_limits_fail_before_pipeline_creation() {
        let mut l = wgpu::Limits::default();
        l.max_storage_buffers_per_shader_stage = 6;
        assert!(limits(&l, 7).is_err());
        l.max_storage_buffers_per_shader_stage = 10;
        assert!(limits(&l, 10).is_ok());
        l.max_bind_groups = 1;
        assert!(limits(&l, 10).is_err());
    }
}
