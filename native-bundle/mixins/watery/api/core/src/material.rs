/// IDs match Material.class and common.glsl in the supplied Watery JAR.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Material {
    Water = 0,
    Sand = 1,
    Lava = 2,
    Slime = 3,
}
impl Material {
    pub const ALL: [Self; 4] = [Self::Water, Self::Sand, Self::Lava, Self::Slime];
    pub const fn shader_id(self) -> f32 {
        self as u8 as f32
    }
    pub const fn sync_id(self) -> u8 {
        self as u8
    }
    pub const fn is_granular(self) -> bool {
        matches!(self, Self::Sand)
    }
    pub const fn is_fluid_sim(self) -> bool {
        !self.is_granular()
    }
    pub const fn uses_whitewater(self) -> bool {
        matches!(self, Self::Water)
    }
    pub const fn label(self) -> &'static str {
        match self {
            Self::Water => "water",
            Self::Sand => "sand",
            Self::Lava => "lava",
            Self::Slime => "slime",
        }
    }
    pub const fn from_sync_id(id: u8) -> Option<Self> {
        match id {
            0 => Some(Self::Water),
            1 => Some(Self::Sand),
            2 => Some(Self::Lava),
            3 => Some(Self::Slime),
            _ => None,
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn material_contract() {
        for (id, material) in Material::ALL.into_iter().enumerate() {
            assert_eq!(material.sync_id(), id as u8);
            assert_eq!(Material::from_sync_id(id as u8), Some(material));
            assert_eq!(material.shader_id(), id as f32);
            assert_eq!(material.is_fluid_sim(), material != Material::Sand);
            assert_eq!(material.uses_whitewater(), material == Material::Water);
        }
        assert_eq!(Material::from_sync_id(255), None);
    }
}
