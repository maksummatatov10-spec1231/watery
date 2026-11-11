//! WaterWorld's block projection hysteresis and feedback suppression.
//! Pure logic: the Horizon adapter must apply writes on the authoritative thread.
use std::collections::HashMap;

pub fn target_amount(fullness: f32, previous: u8) -> u8 {
    let candidate = if fullness >= 0.8 { 8 }
        else if fullness >= 0.12 { (fullness * 8.0).round().clamp(1.0, 7.0) as u8 }
        else { 0 };
    if previous > 0 && candidate == 0 && fullness > 0.05 { return previous; }
    if previous == 0 && candidate > 0 && fullness < 0.2 { return 0; }
    if previous > 0 && candidate > 0 && previous < 8 && candidate < 8
        && candidate.abs_diff(previous) <= 1 { return previous; }
    candidate
}

pub fn target_layers(fullness: f32, speed: f32, previous: u8) -> u8 {
    let f = fullness * 8.0;
    if speed > 1.5 && f > previous as f32 { return previous; }
    let candidate = if f < 0.5 { 0 } else { f.round().clamp(1.0, 8.0) as u8 };
    if previous > 0 && candidate == 0 && f > 0.25 { return previous; }
    if previous > 0 && candidate > 0 && (f - previous as f32).abs() < 0.75 { return previous; }
    candidate
}

/// Convert normalized liquid fullness to a vanilla fluid block level.
/// Vanilla level zero is a full source block; `None` means empty.
pub fn water_level(fullness: f32) -> Option<u8> {
    let amount = target_amount(fullness, 0);
    (amount != 0).then_some(8 - amount)
}

/// Convert normalized sand fullness to a vanilla layer count; `None` means empty.
pub fn sand_layers(fullness: f32) -> Option<u8> {
    let layers = target_layers(fullness, 0.0, 0);
    (layers != 0).then_some(layers)
}

#[derive(Default)]
pub struct Echoes { pending: HashMap<i64, (u8, i32)> }
impl Echoes {
    pub fn expect(&mut self, position: i64, amount: u8, frame: i32) {
        self.pending.insert(position, (amount, frame));
    }
    pub fn consume(&mut self, position: i64, amount: u8) -> bool {
        if self.pending.get(&position).is_some_and(|&(v, _)| v == amount) {
            self.pending.remove(&position);
            true
        } else { false }
    }
    pub fn expire(&mut self, frame: i32) {
        self.pending.retain(|_, &mut (_, timestamp)| frame.wrapping_sub(timestamp) <= 200);
    }
    pub fn clear(&mut self) { self.pending.clear(); }
}

/// Vanilla BlockPos's signed 26/12/26-bit coordinate representation.
pub fn pack_position([x,y,z]: [i32;3]) -> Option<i64> {
    if !(-33_554_432..33_554_432).contains(&x)
        || !(-33_554_432..33_554_432).contains(&z)
        || !(-2048..2048).contains(&y) { return None; }
    Some((((x as u64 & 0x3ff_ffff) << 38)
        | ((z as u64 & 0x3ff_ffff) << 12) | (y as u64 & 0xfff)) as i64)
}
pub fn unpack_position(p: i64) -> [i32;3] {
    [(p >> 38) as i32, (p << 52 >> 52) as i32, (p << 26 >> 38) as i32]
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn liquid_thresholds_and_hysteresis() {
        assert_eq!(target_amount(0.8, 0), 8);
        assert_eq!(target_amount(0.199, 0), 0);
        assert_eq!(target_amount(0.2, 0), 2);
        assert_eq!(target_amount(0.051, 5), 5);
        assert_eq!(target_amount(0.05, 5), 0);
        assert_eq!(target_amount(0.5, 3), 3);
        assert_eq!(target_amount(0.5, 2), 4);
    }
    #[test]
    fn sand_speed_and_hysteresis() {
        assert_eq!(target_layers(1.0, 1.501, 3), 3);
        assert_eq!(target_layers(1.0, 1.5, 3), 8);
        assert_eq!(target_layers(0.04, 0.0, 1), 1);
        assert_eq!(target_layers(0.03125, 0.0, 1), 0);
        assert_eq!(target_layers(0.0625, 0.0, 0), 1);
    }
    #[test]
    fn normalized_fullness_maps_to_vanilla_levels() {
        assert_eq!(water_level(1.0), Some(0));
        assert_eq!(water_level(0.5), Some(4));
        assert_eq!(water_level(0.2), Some(6));
        assert_eq!(water_level(0.0), None);

        assert_eq!(sand_layers(1.0), Some(8));
        assert_eq!(sand_layers(0.5), Some(4));
        assert_eq!(sand_layers(0.0), None);
    }
    #[test]
    fn echoes_mismatch_expiration_and_java_wrap() {
        let mut e = Echoes::default();
        e.expect(1, 3, 0);
        assert!(!e.consume(1, 4));
        e.expire(200);
        assert!(e.consume(1, 3));
        assert!(!e.consume(1, 3));
        e.expect(1, 3, i32::MAX-100);
        e.expire(i32::MIN+100);
        assert!(!e.consume(1, 3));
    }
    #[test]
    fn signed_position_edges() {
        for p in [[0;3],[-1;3],[-33_554_432,-2048,33_554_431],[33_554_431,2047,-33_554_432]] {
            assert_eq!(unpack_position(pack_position(p).unwrap()), p);
        }
        assert_eq!(pack_position([0,2048,0]), None);
    }
}
