//! GPU `blockfill` decoding (`WaterRegion$Fill`) and flow sound scheduling
//! (`me.blue.client.water.FlowSounds`).
use crate::{material::Material, projection, settings::Settings, shader_random};

const HEAR_RANGE_SQ: f64 = 24.0 * 24.0;
const SPREAD_TICKS: u32 = 10;

/// Decoded per-block fullness and speed words produced by `blockfill.wgsl`
/// (`word = full | (fast << 8)`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BlockFill {
    pub origin: [i32; 3],
    pub dims: [u32; 3],
    pub words: Vec<u32>,
}

impl BlockFill {
    pub fn new(origin: [i32; 3], dims: [u32; 3], words: Vec<u32>) -> Result<Self, &'static str> {
        let count = (dims[0] as usize)
            .checked_mul(dims[1] as usize)
            .and_then(|n| n.checked_mul(dims[2] as usize))
            .ok_or("blockfill dimensions overflow")?;
        if words.len() != count {
            return Err("blockfill word count mismatch");
        }
        Ok(Self {
            origin,
            dims,
            words,
        })
    }

    #[inline]
    pub fn fullness(&self, index: usize) -> f32 {
        (self.words[index] & 0xff) as f32 * (1.0 / 255.0)
    }

    #[inline]
    pub fn blocks_per_second(&self, index: usize) -> f32 {
        ((self.words[index] >> 8) & 0xff) as f32 * (1.0 / 16.0)
    }

    #[inline]
    pub fn water_level(&self, index: usize) -> Option<u8> {
        projection::water_level(self.fullness(index))
    }

    #[inline]
    pub fn sand_layers(&self, index: usize) -> Option<u8> {
        projection::sand_layers(self.fullness(index))
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct SoundEvent {
    pub sound: &'static str,
    pub position: [f64; 3],
    pub volume: f32,
    pub pitch: f32,
}

#[derive(Clone, Debug)]
struct PendingSound {
    due_tick: u32,
    event: SoundEvent,
}

pub struct FlowSounds {
    pending: Vec<PendingSound>,
    seed: u32,
    tick: u32,
}

impl Default for FlowSounds {
    fn default() -> Self {
        Self::new(0x7761_7472)
    }
}

impl FlowSounds {
    pub fn new(seed: u32) -> Self {
        Self {
            pending: Vec::new(),
            seed,
            tick: 0,
        }
    }

    pub fn clear(&mut self) {
        self.pending.clear();
    }

    /// Evaluate a `BlockFill` readback against the original `FlowSounds.onFill`
    /// thresholds and schedule spread sound events over the next 10 ticks.
    pub fn on_fill(
        &mut self,
        material: Material,
        fill: &BlockFill,
        listener: [f64; 3],
        settings: &Settings,
    ) {
        let enabled = match material {
            Material::Water => settings.flowSounds,
            Material::Lava => settings.lavaFlowSounds,
            Material::Slime => settings.slimeSounds,
            Material::Sand => settings.sandSounds,
        };
        if !enabled || settings.flowSoundVolume <= 0.0 {
            return;
        }
        let min_speed = match material {
            Material::Water => 0.4,
            Material::Lava => 0.35,
            Material::Slime => 0.25,
            Material::Sand => 0.3,
        };
        let fast_speed = match material {
            Material::Water => 4.0,
            Material::Lava => 2.0,
            Material::Slime => 1.5,
            Material::Sand => 2.5,
        };
        let mut candidates: Vec<([f64; 3], f32)> = Vec::new();
        let mut energy = 0.0f32;
        let mut fast_blocks = 0.0f32;
        let mut idx = 0usize;
        for dz in 0..fill.dims[2] as i32 {
            for dy in 0..fill.dims[1] as i32 {
                for dx in 0..fill.dims[0] as i32 {
                    let speed = fill.blocks_per_second(idx);
                    let fullness = fill.fullness(idx);
                    idx += 1;
                    if speed < min_speed || fullness < 0.06 {
                        continue;
                    }
                    let pos = [
                        f64::from(fill.origin[0] + dx) + 0.5,
                        f64::from(fill.origin[1] + dy) + 0.5,
                        f64::from(fill.origin[2] + dz) + 0.5,
                    ];
                    let dist_sq = (pos[0] - listener[0]).powi(2)
                        + (pos[1] - listener[1]).powi(2)
                        + (pos[2] - listener[2]).powi(2);
                    if dist_sq > HEAR_RANGE_SQ {
                        continue;
                    }
                    candidates.push((pos, speed));
                    energy += (speed / 1.5).min(2.0);
                    if speed > fast_speed {
                        fast_blocks += 1.0;
                    }
                }
            }
        }
        if candidates.is_empty() {
            return;
        }
        let gain = match material {
            Material::Water => 0.012,
            Material::Lava => 0.011,
            Material::Slime | Material::Sand => 0.01,
        };
        let max_count = match material {
            Material::Water => 3usize,
            Material::Lava | Material::Sand => 2usize,
            Material::Slime => 2usize,
        };
        let count = ((energy * 0.2).ceil() as usize).clamp(1, max_count.min(candidates.len()));
        let sound = match material {
            Material::Water if fast_blocks >= 2.0 => "minecraft:item.bucket.empty",
            Material::Water => "minecraft:block.water.ambient",
            Material::Lava => "minecraft:block.lava.pop",
            Material::Slime => "minecraft:block.slime_block.step",
            Material::Sand => "minecraft:block.sand.place",
        };
        for _ in 0..count {
            let pick =
                ((shader_random(&mut self.seed) * candidates.len() as f32) as usize).min(candidates.len() - 1);
            let (position, speed) = candidates[pick];
            let delay = (shader_random(&mut self.seed) * SPREAD_TICKS as f32) as u32;
            let volume = ((0.12 + energy * gain) * settings.flowSoundVolume).clamp(0.02, 1.0);
            let pitch = (0.85 + (speed / (fast_speed * 2.0)).min(0.35)
                + (shader_random(&mut self.seed) - 0.5) * 0.15)
                .clamp(0.5, 1.6);
            self.pending.push(PendingSound {
                due_tick: self.tick + delay,
                event: SoundEvent {
                    sound,
                    position,
                    volume,
                    pitch,
                },
            });
        }
    }

    /// Advance one client tick and drain all sounds scheduled for this tick.
    pub fn tick(&mut self) -> Vec<SoundEvent> {
        let now = self.tick;
        self.tick = self.tick.wrapping_add(1);
        let mut ready = Vec::new();
        let mut i = 0;
        while i < self.pending.len() {
            if self.pending[i].due_tick <= now {
                ready.push(self.pending.swap_remove(i).event);
            } else {
                i += 1;
            }
        }
        ready
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn block_fill_unpacks_fullness_speed_and_vanilla_levels() {
        // full = 255 (1.0), fast = 32 (2.0 blocks/sec)
        let fill = BlockFill::new([0, 64, 0], [1, 1, 1], vec![255 | (32 << 8)]).unwrap();
        assert!((fill.fullness(0) - 1.0).abs() < 1e-6);
        assert!((fill.blocks_per_second(0) - 2.0).abs() < 1e-6);
        assert_eq!(fill.water_level(0), Some(0));
        assert_eq!(fill.sand_layers(0), Some(8));
    }

    #[test]
    fn schedules_nearby_flow_sounds_and_filters_distant_or_disabled() {
        let mut sounds = FlowSounds::new(42);
        let mut settings = Settings::default();
        let near = BlockFill::new([0, 64, 0], [1, 1, 1], vec![200 | (40 << 8)]).unwrap();
        // Beyond 24-block hearing range -> ignored
        sounds.on_fill(Material::Water, &near, [100.0, 64.0, 0.0], &settings);
        let mut emitted = Vec::new();
        for _ in 0..12 {
            emitted.extend(sounds.tick());
        }
        assert!(emitted.is_empty());

        // Within range -> emits within 10 ticks
        sounds.on_fill(Material::Water, &near, [1.0, 64.0, 1.0], &settings);
        for _ in 0..12 {
            emitted.extend(sounds.tick());
        }
        assert!(!emitted.is_empty());
        assert!(emitted.iter().all(|e| e.volume > 0.0 && e.sound.starts_with("minecraft:")));

        // Disabled setting -> ignored
        settings.flowSounds = false;
        sounds.on_fill(Material::Water, &near, [1.0, 64.0, 1.0], &settings);
        let mut after_disable = Vec::new();
        for _ in 0..12 {
            after_disable.extend(sounds.tick());
        }
        assert!(after_disable.is_empty());
    }
}
