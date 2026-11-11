//! Watery's WaterRegion.Emitter lattice and 64-byte GPU record.
//! The caller keeps pending emitters in order; a batch stops at the first
//! emitter that would exceed the original capacity or 8192-record ring.
#[derive(Clone, Copy, Debug)]
pub struct Emitter {
    pub min: [f64; 3],
    pub max: [f64; 3],
    pub velocity: [f32; 3],
}

#[derive(Debug, PartialEq, Eq)]
pub struct Batch {
    bytes: Vec<u8>,
    accepted: usize,
    attempts: u32,
}

impl Batch {
    pub fn bytes(&self) -> &[u8] {
        &self.bytes
    }
    pub fn accepted(&self) -> usize {
        self.accepted
    }
    pub fn attempts(&self) -> u32 {
        self.attempts
    }
}

impl Emitter {
    pub fn lattice(&self, resolution: u32) -> Result<[u32; 3], &'static str> {
        if resolution == 0
            || self
                .min
                .iter()
                .chain(self.max.iter())
                .any(|v| !v.is_finite())
        {
            return Err("invalid emitter bounds or resolution");
        }
        let mut result = [0; 3];
        for (axis, out) in result.iter_mut().enumerate() {
            let width = self.max[axis] - self.min[axis];
            let scaled = width * resolution as f64 * 2.0;
            if !scaled.is_finite() || scaled < 0.0 || scaled > i32::MAX as f64 {
                return Err("emitter lattice overflow or reversed bounds");
            }
            // Java Math.round for nonnegative double values.
            *out = (scaled + 0.5).floor().max(1.0) as u32;
        }
        Ok(result)
    }
}

/// `occupied` is the last known population plus emit attempts since readback.
/// It must be maintained by the owner of the region; do not infer it from a
/// GPU counter without synchronizing, or subsequent batches may oversubscribe.
pub fn pack_batch(
    pending: &[Emitter],
    resolution: u32,
    origin: [i32; 3],
    occupied: u32,
    capacity: u32,
) -> Result<Batch, &'static str> {
    if occupied > capacity || capacity > i32::MAX as u32 {
        return Err("invalid population reservation");
    }
    let mut bytes = Vec::new();
    let mut attempts = 0u32;
    let mut accepted = 0;
    for e in pending {
        if accepted == 8192 {
            break;
        }
        if e.velocity.iter().any(|v| !v.is_finite()) {
            return Err("nonfinite emitter velocity");
        }
        let lattice = e.lattice(resolution)?;
        let count = lattice
            .iter()
            .try_fold(1u32, |n, &d| n.checked_mul(d))
            .ok_or("emitter particle count overflow")?;
        if count > capacity - occupied - attempts {
            break;
        }
        let mut row = [0u8; 64];
        for axis in 0..3 {
            for (offset, point) in [(0, e.min[axis]), (16, e.max[axis])] {
                let value = ((point - origin[axis] as f64) * resolution as f64) as f32;
                if !value.is_finite() {
                    return Err("emitter grid coordinate overflow");
                }
                row[offset + axis * 4..offset + axis * 4 + 4].copy_from_slice(&value.to_le_bytes());
            }
            let speed = e.velocity[axis] * resolution as f32;
            if !speed.is_finite() {
                return Err("emitter grid velocity overflow");
            }
            row[32 + axis * 4..36 + axis * 4].copy_from_slice(&speed.to_le_bytes());
            row[52 + axis * 4..56 + axis * 4]
                .copy_from_slice(&(lattice[axis] as i32).to_le_bytes());
        }
        row[48..52].copy_from_slice(&(attempts as i32).to_le_bytes());
        bytes.extend_from_slice(&row);
        attempts += count;
        accepted += 1;
    }
    Ok(Batch {
        bytes,
        accepted,
        attempts,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn original_lattice_rounding_and_layout() {
        let e = Emitter {
            min: [1.0, 2.0, 3.0],
            max: [1.125, 2.25, 3.0],
            velocity: [1.0, -2.0, 0.5],
        };
        assert_eq!(e.lattice(4).unwrap(), [1, 2, 1]);
        let b = pack_batch(&[e, e], 4, [1, 0, 0], 3, 10).unwrap();
        assert_eq!((b.accepted, b.attempts, b.bytes.len()), (2, 4, 128));
        assert_eq!(&b.bytes[48..52], &0i32.to_le_bytes());
        assert_eq!(&b.bytes[112..116], &2i32.to_le_bytes());
        assert_eq!(&b.bytes[52..64], &[1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0]);
        assert_eq!(f32::from_le_bytes(b.bytes[0..4].try_into().unwrap()), 0.0);
        assert_eq!(f32::from_le_bytes(b.bytes[32..36].try_into().unwrap()), 4.0);
        assert_eq!(pack_batch(&[e, e], 4, [0; 3], 6, 9).unwrap().accepted, 1);
    }
    #[test]
    fn rejects_invalid_or_unrepresentable_inputs() {
        let e = Emitter {
            min: [0.0; 3],
            max: [f64::INFINITY, 1.0, 1.0],
            velocity: [0.0; 3],
        };
        assert!(pack_batch(&[e], 4, [0; 3], 0, 100).is_err());
        let e = Emitter {
            min: [1.0; 3],
            max: [0.0; 3],
            velocity: [0.0; 3],
        };
        assert!(e.lattice(4).is_err());
        assert!(pack_batch(&[], 4, [0; 3], 11, 10).is_err());
    }
}
