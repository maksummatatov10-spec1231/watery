//! Partial Watery port: reference-compatible primitives, NOT a playable Horizon mod.
pub mod atlas_tex;
pub mod emitter;
pub mod flow_sounds;
pub mod grid;
pub mod material;
pub mod network;
pub mod parallel;
pub mod pressure;
pub mod projection;
pub mod region;
pub mod settings;
pub mod solid_cache;
pub mod terrain;
pub mod uniforms;

/// Hash from Watery 1.2.2 common.glsl. Wrapping arithmetic is intentional.
pub fn shader_hash(mut x: u32) -> u32 {
    x ^= x >> 16;
    x = x.wrapping_mul(0x7feb_352d);
    x ^= x >> 15;
    x = x.wrapping_mul(0x846c_a68b);
    x ^ (x >> 16)
}

/// Same 24-bit random fraction and state transition as common.glsl.
pub fn shader_random(state: &mut u32) -> f32 {
    *state = shader_hash(state.wrapping_add(0x9e37_79b9));
    (*state >> 8) as f32 * (1.0 / 16_777_216.0)
}

#[repr(C, align(16))]
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Particle {
    pub position: [f32; 4],
    pub velocity: [f32; 4],
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn particle_matches_storage_buffer_layout() {
        assert_eq!(std::mem::size_of::<Particle>(), 32);
        assert_eq!(std::mem::align_of::<Particle>(), 16);
        assert_eq!(std::mem::offset_of!(Particle, velocity), 16);
    }
    #[test]
    fn hash_vectors() {
        assert_eq!(shader_hash(0), 0);
        assert_eq!(shader_hash(1), 0x6889_90c0);
    }
    #[test]
    fn random_is_finite_and_bounded() {
        let mut state = 0;
        for _ in 0..10000 {
            assert!((0.0..1.0).contains(&shader_random(&mut state)));
        }
    }
}
