//! Watery SyncPayload and RemoveAllWaterPayload wire codecs:
//! - SyncPayload: VarInt count, then big-endian `BlockPos` i64 + signed byte amount.
//! - RemoveAllWaterPayload: VarInt `radiusChunks` (clamped to `1..=64` on apply) + material byte.
//!
//! Channel registration and authoritative application belong to the host adapter.
use crate::material::Material;

pub const MAX_ENTRIES: usize = 32768;
pub const SYNC_FLAGS: i32 = 530;

pub const WATER_SYNC_CHANNEL: &str = "watery:water_sync";
pub const SAND_SYNC_CHANNEL: &str = "watery:sand_sync";
pub const LAVA_SYNC_CHANNEL: &str = "watery:lava_sync";
pub const SLIME_SYNC_CHANNEL: &str = "watery:slime_sync";
pub const REMOVE_ALL_CHANNEL: &str = "watery:remove_all_water";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BlockUpdate {
    pub position: i64,
    pub amount: i8,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RemoveAllPayload {
    pub radius_chunks: i32,
    pub material: Material,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DecodeError {
    InvalidCount,
    InvalidMaterial,
    Truncated,
    Trailing,
}

/// Pack `[x, y, z]` into Minecraft's `BlockPos.asLong` 64-bit representation
/// (26-bit signed X in bits 63..38, 26-bit signed Z in bits 37..12, 12-bit signed Y in bits 11..0).
#[inline]
pub fn pack_block_pos([x, y, z]: [i32; 3]) -> i64 {
    (((x as i64) & 0x3ff_ffff) << 38)
        | (((z as i64) & 0x3ff_ffff) << 12)
        | ((y as i64) & 0xfff)
}

/// Unpack Minecraft's `BlockPos.of(long)` 64-bit representation into `[x, y, z]`.
#[inline]
pub fn unpack_block_pos(packed: i64) -> [i32; 3] {
    let x = (packed >> 38) as i32;
    let z = ((packed << 26) >> 38) as i32;
    let y = ((packed << 52) >> 52) as i32;
    [x, y, z]
}

pub fn sync_channel(material: Material) -> &'static str {
    match material {
        Material::Water => WATER_SYNC_CHANNEL,
        Material::Sand => SAND_SYNC_CHANNEL,
        Material::Lava => LAVA_SYNC_CHANNEL,
        Material::Slime => SLIME_SYNC_CHANNEL,
    }
}

pub fn sync_material_from_channel(channel: &str) -> Option<Material> {
    match channel {
        WATER_SYNC_CHANNEL => Some(Material::Water),
        SAND_SYNC_CHANNEL => Some(Material::Sand),
        LAVA_SYNC_CHANNEL => Some(Material::Lava),
        SLIME_SYNC_CHANNEL => Some(Material::Slime),
        _ => None,
    }
}

fn push_varint(out: &mut Vec<u8>, mut value: u32) {
    loop {
        let mut b = (value & 127) as u8;
        value >>= 7;
        if value != 0 {
            b |= 128;
        }
        out.push(b);
        if value == 0 {
            break;
        }
    }
}

fn read_varint(bytes: &[u8]) -> Result<(i32, usize), DecodeError> {
    let mut value = 0u32;
    for i in 0..5 {
        let b = *bytes.get(i).ok_or(DecodeError::Truncated)?;
        if i == 4 && b > 15 {
            return Err(DecodeError::InvalidCount);
        }
        value |= u32::from(b & 127) << (i * 7);
        if b & 128 == 0 {
            return Ok((value as i32, i + 1));
        }
    }
    Err(DecodeError::InvalidCount)
}

pub fn encode(updates: &[BlockUpdate]) -> Result<Vec<u8>, DecodeError> {
    if updates.len() > MAX_ENTRIES {
        return Err(DecodeError::InvalidCount);
    }
    let mut out = Vec::with_capacity(3 + updates.len() * 9);
    push_varint(&mut out, updates.len() as u32);
    for u in updates {
        out.extend(u.position.to_be_bytes());
        out.push(u.amount as u8);
    }
    Ok(out)
}

pub fn decode(bytes: &[u8]) -> Result<Vec<BlockUpdate>, DecodeError> {
    let (raw_count, prefix) = read_varint(bytes)?;
    if raw_count < 0 || raw_count as usize > MAX_ENTRIES {
        return Err(DecodeError::InvalidCount);
    }
    let count = raw_count as usize;
    let size = prefix + count * 9;
    if bytes.len() < size {
        return Err(DecodeError::Truncated);
    }
    if bytes.len() > size {
        return Err(DecodeError::Trailing);
    }
    Ok(bytes[prefix..]
        .as_chunks::<9>()
        .0
        .iter()
        .map(|row| BlockUpdate {
            position: i64::from_be_bytes(row[..8].try_into().unwrap()),
            amount: row[8] as i8,
        })
        .collect())
}

impl RemoveAllPayload {
    /// Clamped chunk radius matching `RemoveAllWaterPayload.apply` (`Math.clamp(radiusChunks, 1, 64)`).
    pub fn clamped_radius(&self) -> i32 {
        self.radius_chunks.clamp(1, 64)
    }

    pub fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(6);
        push_varint(&mut out, self.radius_chunks as u32);
        let mat_byte = match self.material {
            Material::Water => 0u8,
            Material::Sand => 1u8,
            Material::Lava => 2u8,
            Material::Slime => 3u8,
        };
        out.push(mat_byte);
        out
    }

    pub fn decode(bytes: &[u8]) -> Result<Self, DecodeError> {
        let (radius_chunks, prefix) = read_varint(bytes)?;
        let mat_byte = *bytes.get(prefix).ok_or(DecodeError::Truncated)?;
        if bytes.len() > prefix + 1 {
            return Err(DecodeError::Trailing);
        }
        let material = match mat_byte as i8 {
            1 => Material::Sand,
            2 => Material::Lava,
            3 => Material::Slime,
            0 => Material::Water,
            _ => return Err(DecodeError::InvalidMaterial),
        };
        Ok(Self {
            radius_chunks,
            material,
        })
    }
}

/// Same loaded-chunk and 512-block spherical bound as `SyncPayload.apply`.
/// Authorization (singleplayer owner or operator) must precede this check.
pub fn in_sync_range(position: [i32; 3], player: [i32; 3], loaded: bool) -> bool {
    loaded
        && position
            .into_iter()
            .zip(player)
            .map(|(a, b)| (f64::from(a) - f64::from(b)).powi(2))
            .sum::<f64>()
            <= 262144.0
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn exact_wire_fixture_signed_long_and_amount() {
        let fixture = [
            2, 0, 0, 0, 0, 0, 0, 0, 1, 8, 255, 255, 255, 255, 255, 255, 255, 255, 255,
        ];
        let expected = [
            BlockUpdate {
                position: 1,
                amount: 8,
            },
            BlockUpdate {
                position: -1,
                amount: -1,
            },
        ];
        assert_eq!(decode(&fixture).unwrap(), expected);
        assert_eq!(encode(&expected).unwrap(), fixture);
    }
    #[test]
    fn maximum_and_malformed_counts() {
        let max = vec![
            BlockUpdate {
                position: 0,
                amount: 0
            };
            MAX_ENTRIES
        ];
        let bytes = encode(&max).unwrap();
        assert_eq!(&bytes[..3], &[128, 128, 2]);
        assert_eq!(decode(&bytes).unwrap(), max);
        assert_eq!(decode(&[129, 128, 2]), Err(DecodeError::InvalidCount));
        assert_eq!(
            decode(&[255, 255, 255, 255, 15]),
            Err(DecodeError::InvalidCount)
        );
        assert_eq!(decode(&[128; 5]), Err(DecodeError::InvalidCount));
        assert_eq!(decode(&[1]), Err(DecodeError::Truncated));
        assert_eq!(decode(&[0, 0]), Err(DecodeError::Trailing));
        for n in 0..19 {
            assert!(decode(&[2; 19][..n]).is_err());
        }
    }
    #[test]
    fn radius_loaded_and_extreme_coordinates() {
        assert!(in_sync_range([512, 0, 0], [0; 3], true));
        assert!(!in_sync_range([512, 1, 0], [0; 3], true));
        assert!(!in_sync_range([0; 3], [0; 3], false));
        assert!(!in_sync_range([i32::MAX; 3], [i32::MIN; 3], true));
    }
    #[test]
    fn block_pos_pack_roundtrip_and_remove_all_codec() {
        for pos in [
            [0, 0, 0],
            [12345, -64, -54321],
            [-30_000_000, 319, 29_999_999],
            [-1, -1, -1],
        ] {
            assert_eq!(unpack_block_pos(pack_block_pos(pos)), pos);
        }
        for mat in [
            Material::Water,
            Material::Sand,
            Material::Lava,
            Material::Slime,
        ] {
            let p = RemoveAllPayload {
                radius_chunks: 120,
                material: mat,
            };
            let decoded = RemoveAllPayload::decode(&p.encode()).unwrap();
            assert_eq!(decoded, p);
            assert_eq!(decoded.clamped_radius(), 64);
            assert_eq!(sync_material_from_channel(sync_channel(mat)), Some(mat));
        }
        assert_eq!(
            RemoveAllPayload::decode(&[8, 9]),
            Err(DecodeError::InvalidMaterial)
        );
    }
}
