//! Packed block texture buffers shared by `composite.frag` (`slimeTex`) and
//! `sand_shade.glsl` (`sandTex`): `[width, height, average_rgb, 0, texels...]`.

pub const MAX_TEXTURE_SIDE: u32 = 1024;

/// Pack top-down RGBA8 pixels into the integer SSBO layout expected by
/// `composite.frag` and `sand_shade.glsl`.
///
/// Animated vertical strips (`height > width && height % width == 0`) are
/// cropped to their first `width × width` frame so `texelsPerBlock = width`
/// tiles square block faces without vertical stretching.
pub fn pack_rgba8(width: u32, height: u32, rgba: &[u8]) -> Result<Vec<i32>, &'static str> {
    if width == 0 || height == 0 || width > MAX_TEXTURE_SIDE || height > MAX_TEXTURE_SIDE * 64 {
        return Err("invalid block texture dimensions");
    }
    let expected = (width as usize)
        .checked_mul(height as usize)
        .and_then(|px| px.checked_mul(4))
        .ok_or("texture byte size overflow")?;
    if rgba.len() != expected {
        return Err("RGBA byte length does not match dimensions");
    }
    let frame_h = if height > width && height.is_multiple_of(width) {
        width
    } else {
        height
    };
    let count = (width * frame_h) as usize;
    let mut out = Vec::with_capacity(4 + count);
    out.extend([width as i32, frame_h as i32, 0, 0]);

    let (mut wr, mut wg, mut wb, mut wa) = (0u64, 0u64, 0u64, 0u64);
    let (mut sr, mut sg, mut sb) = (0u64, 0u64, 0u64);
    for px in rgba[..count * 4].as_chunks::<4>().0 {
        let (r, g, b, a) = (px[0] as u64, px[1] as u64, px[2] as u64, px[3] as u64);
        wr += r * a;
        wg += g * a;
        wb += b * a;
        wa += a;
        sr += r;
        sg += g;
        sb += b;
        out.push((((px[0] as i32) << 16) | ((px[1] as i32) << 8) | (px[2] as i32)) & 0x00ff_ffff);
    }
    let (ar, ag, ab) = match std::num::NonZeroU64::new(wa) {
        Some(alpha_weight) => {
            let weight = alpha_weight.get();
            (
                (wr + weight / 2) / weight,
                (wg + weight / 2) / weight,
                (wb + weight / 2) / weight,
            )
        }
        None => {
            let n = count as u64;
            ((sr + n / 2) / n, (sg + n / 2) / n, (sb + n / 2) / n)
        }
    };
    out[2] = (((ar as i32) << 16) | ((ag as i32) << 8) | (ab as i32)) & 0x00ff_ffff;
    Ok(out)
}

pub fn to_le_bytes(words: &[i32]) -> Vec<u8> {
    words.iter().flat_map(|w| w.to_le_bytes()).collect()
}

/// Fallback 16×16 slime block palette when resource pack pixels are not yet loaded.
pub fn default_slime_tex() -> Vec<i32> {
    let mut rgba = Vec::with_capacity(16 * 16 * 4);
    for y in 0..16u32 {
        for x in 0..16u32 {
            let core = (3..13).contains(&x) && (3..13).contains(&y);
            let h = crate::shader_hash(x.wrapping_mul(37) ^ y.wrapping_mul(101) ^ 0x51a3);
            let jitter = ((h & 0x0f) as i32) - 8;
            let (r, g, b) = if core {
                (108 + jitter / 2, 196 + jitter, 88 + jitter / 2)
            } else {
                (126 + jitter / 2, 212 + jitter, 102 + jitter / 2)
            };
            rgba.extend([
                r.clamp(0, 255) as u8,
                g.clamp(0, 255) as u8,
                b.clamp(0, 255) as u8,
                220u8,
            ]);
        }
    }
    pack_rgba8(16, 16, &rgba).expect("16x16 fallback slime texture")
}

/// Fallback 16×16 sand block palette when resource pack pixels are not yet loaded.
pub fn default_sand_tex() -> Vec<i32> {
    let mut rgba = Vec::with_capacity(16 * 16 * 4);
    for y in 0..16u32 {
        for x in 0..16u32 {
            let h = crate::shader_hash(x.wrapping_mul(73) ^ y.wrapping_mul(197) ^ 0x9a2d);
            let jitter = ((h & 0x1f) as i32) - 15;
            rgba.extend([
                (219 + jitter / 2).clamp(0, 255) as u8,
                (207 + jitter / 2).clamp(0, 255) as u8,
                (163 + jitter / 2).clamp(0, 255) as u8,
                255u8,
            ]);
        }
    }
    pack_rgba8(16, 16, &rgba).expect("16x16 fallback sand texture")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn packs_header_average_and_crops_animated_strip() {
        let mut strip = vec![0u8; 2 * 4 * 4];
        // Frame 0: solid green (0x20, 0xc0, 0x40); Frame 1: solid red (should be cropped).
        for px in strip[..2 * 2 * 4].as_chunks_mut::<4>().0 {
            px.copy_from_slice(&[0x20, 0xc0, 0x40, 0xff]);
        }
        for px in strip[2 * 2 * 4..].as_chunks_mut::<4>().0 {
            px.copy_from_slice(&[0xff, 0x00, 0x00, 0xff]);
        }
        let packed = pack_rgba8(2, 4, &strip).unwrap();
        assert_eq!(packed.len(), 4 + 4);
        assert_eq!(&packed[..4], &[2, 2, 0x20c040, 0]);
        assert!(packed[4..].iter().all(|&c| c == 0x20c040));
    }

    #[test]
    fn fully_transparent_texture_uses_unweighted_rgb_average() {
        let packed = pack_rgba8(2, 1, &[200, 20, 40, 0, 10, 80, 120, 0]).unwrap();
        assert_eq!(packed[2], 0x69_32_50);
    }

    #[test]
    fn rejects_invalid_dimensions_and_byte_counts() {
        assert!(pack_rgba8(0, 16, &[]).is_err());
        assert!(pack_rgba8(16, 0, &[]).is_err());
        assert!(pack_rgba8(2, 2, &[0u8; 12]).is_err());
    }

    #[test]
    fn default_slime_and_sand_textures_are_valid_and_non_black() {
        for tex in [default_slime_tex(), default_sand_tex()] {
            assert_eq!(tex.len(), 4 + 256);
            assert_eq!(tex[0], 16);
            assert_eq!(tex[1], 16);
            assert!(tex[2] > 0);
            assert_eq!(to_le_bytes(&tex).len(), 260 * 4);
        }
    }
}
