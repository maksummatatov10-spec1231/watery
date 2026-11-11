struct Particle {
    pos: vec4<f32>,
    vel: vec4<f32>,
}

struct Globals {
    dims: vec4<i32>,
    faces: vec4<i32>,
    caps: vec4<i32>,
    flags: vec4<i32>,
    gravityDt: vec4<f32>,
    simA: vec4<f32>,
    simB: vec4<f32>,
    wwA: vec4<f32>,
    wwB: vec4<f32>,
    wwC: vec4<f32>,
    wwD: vec4<f32>,
    proj: mat4x4<f32>,
    view: mat4x4<f32>,
    invProj: mat4x4<f32>,
    invView: mat4x4<f32>,
    domainOrigin: vec4<f32>,
    screen: vec4<f32>,
    sunDir: vec4<f32>,
    skyColor: vec4<f32>,
    fogColor: vec4<f32>,
    waterA: vec4<f32>,
    absorb: vec4<f32>,
    scatter: vec4<f32>,
    foamA: vec4<f32>,
    ent: array<vec4<f32>, 96>,
    sources: array<vec4<f32>, 64>,
    camGrid: vec4<f32>,
    misc: vec4<f32>,
    fine: vec4<i32>,
    surf: vec4<f32>,
    boxMin: vec4<i32>,
    boxMax: vec4<i32>,
    fineBoxMin: vec4<i32>,
    fineBoxMax: vec4<i32>,
    removeInfo: vec4<i32>,
    removeBox: array<vec4<f32>, 32>,
    killInfo: vec4<f32>,
    shadeA: vec4<f32>,
    shadeB: vec4<f32>,
    matA: vec4<f32>,
    matB: vec4<f32>,
    matC: vec4<f32>,
    matD: vec4<f32>,
    matE: vec4<f32>,
    compat: vec4<f32>,
    shadowNear: mat4x4<f32>,
    shadowMid: mat4x4<f32>,
    shadowFar: mat4x4<f32>,
    compatB: vec4<f32>,
    lightA: vec4<f32>,
    lightB: vec4<f32>,
    lightC: vec4<f32>,
    lightColors: array<vec4<f32>, 8>,
}

struct RegionLight {
    regionLight: array<u32>,
}

struct SandTex {
    sandTex: array<i32>,
}

struct FragmentOutput {
    @location(0) outColor: vec4<f32>,
    @builtin(frag_depth) gl_FragDepth: f32,
}

const FP_SCALE: f32 = 65536f;

@group(0) @binding(0)
var<uniform> G: Globals;
var<private> vUV_1: vec2<f32>;
var<private> vCenter_1: vec3<f32>;
var<private> vRadius_1: f32;
var<private> vSeed_1: u32;
var<private> vWorld_1: vec3<f32>;
var<private> vNormal_1: vec3<f32>;
var<private> vShade_1: f32;
var<private> outColor: vec4<f32>;
@group(0) @binding(3)
var shadowTex_texture: texture_2d<f32>;
@group(2) @binding(3)
var shadowTex_sampler: sampler;
@group(0) @binding(4)
var<storage> global: RegionLight;
@group(0) @binding(5)
var lightmapTex_texture: texture_2d<f32>;
@group(2) @binding(5)
var lightmapTex_sampler: sampler;
@group(0) @binding(6)
var skLightA_texture: texture_2d<f32>;
@group(2) @binding(6)
var skLightA_sampler: sampler;
@group(0) @binding(7)
var skLightB_texture: texture_2d<f32>;
@group(2) @binding(7)
var skLightB_sampler: sampler;
@group(0) @binding(8)
var skLightTint_texture: texture_2d<f32>;
@group(2) @binding(8)
var skLightTint_sampler: sampler;
@group(0) @binding(2)
var<storage> global_1: SandTex;
var<private> gl_FragDepth: f32;

fn isSand() -> bool {
    let _e108: vec4<f32> = G.matA;
    let _e113: vec4<f32> = G.matA;
    return ((_e108.x > 0.5f) && (_e113.x < 1.5f));
}

fn isLava() -> bool {
    let _e108: vec4<f32> = G.matA;
    return (abs((_e108.x - 2f)) < 0.5f);
}

fn isSlime() -> bool {
    let _e108: vec4<f32> = G.matA;
    return (_e108.x > 2.5f);
}

fn cellIndex(c: vec3<i32>) -> i32 {
    var c_1: vec3<i32>;

    c_1 = c;
    let _e110: vec3<i32> = c_1;
    let _e113: vec4<i32> = G.dims;
    let _e115: vec3<i32> = c_1;
    let _e118: vec4<i32> = G.dims;
    let _e120: vec3<i32> = c_1;
    return (_e110.x + (_e113.x * (_e115.y + (_e118.y * _e120.z))));
}

fn inGrid(c_2: vec3<i32>) -> bool {
    var c_3: vec3<i32>;

    c_3 = c_2;
    let _e110: vec3<i32> = c_3;
    let _e114: vec3<i32> = c_3;
    let _e119: vec3<i32> = c_3;
    let _e124: vec3<i32> = c_3;
    let _e127: vec4<i32> = G.dims;
    let _e131: vec3<i32> = c_3;
    let _e134: vec4<i32> = G.dims;
    let _e138: vec3<i32> = c_3;
    let _e141: vec4<i32> = G.dims;
    return ((((((_e110.x >= 0i) && (_e114.y >= 0i)) && (_e119.z >= 0i)) && (_e124.x < _e127.x)) && (_e131.y < _e134.y)) && (_e138.z < _e141.z));
}

fn cellCoord(i: i32) -> vec3<i32> {
    var i_1: i32;

    i_1 = i;
    let _e110: i32 = i_1;
    let _e112: vec4<i32> = G.dims;
    let _e115: i32 = i_1;
    let _e117: vec4<i32> = G.dims;
    let _e121: vec4<i32> = G.dims;
    let _e124: i32 = i_1;
    let _e126: vec4<i32> = G.dims;
    let _e129: vec4<i32> = G.dims;
    return vec3<i32>((_e110 % _e112.x), ((_e115 / _e117.x) % _e121.y), (_e124 / (_e126.x * _e129.y)));
}

fn faceDims(comp: i32) -> vec3<i32> {
    var comp_1: i32;
    var local: i32;
    var local_1: i32;
    var local_2: i32;

    comp_1 = comp;
    let _e111: vec4<i32> = G.dims;
    let _e114: vec4<i32> = G.dims;
    let _e117: vec4<i32> = G.dims;
    let _e120: i32 = comp_1;
    if (_e120 == 0i) {
        local = 1i;
    } else {
        local = 0i;
    }
    let _e126: i32 = local;
    let _e127: i32 = comp_1;
    if (_e127 == 1i) {
        local_1 = 1i;
    } else {
        local_1 = 0i;
    }
    let _e133: i32 = local_1;
    let _e134: i32 = comp_1;
    if (_e134 == 2i) {
        local_2 = 1i;
    } else {
        local_2 = 0i;
    }
    let _e140: i32 = local_2;
    return (vec3<i32>(_e111.x, _e114.y, _e117.z) + vec3<i32>(_e126, _e133, _e140));
}

fn faceBase(comp_2: i32) -> i32 {
    var comp_3: i32;
    var local_3: i32;
    var local_4: i32;

    comp_3 = comp_2;
    let _e110: i32 = comp_3;
    if (_e110 == 0i) {
        local_4 = 0i;
    } else {
        let _e114: i32 = comp_3;
        if (_e114 == 1i) {
            let _e118: vec4<i32> = G.faces;
            local_3 = _e118.x;
        } else {
            let _e121: vec4<i32> = G.faces;
            let _e124: vec4<i32> = G.faces;
            local_3 = (_e121.x + _e124.y);
        }
        let _e128: i32 = local_3;
        local_4 = _e128;
    }
    let _e130: i32 = local_4;
    return _e130;
}

fn faceIndex(comp_4: i32, f: vec3<i32>) -> i32 {
    var comp_5: i32;
    var f_1: vec3<i32>;
    var d: vec3<i32>;

    comp_5 = comp_4;
    f_1 = f;
    let _e112: i32 = comp_5;
    let _e113: vec3<i32> = faceDims(_e112);
    d = _e113;
    let _e115: i32 = comp_5;
    let _e116: i32 = faceBase(_e115);
    let _e117: vec3<i32> = f_1;
    let _e120: vec3<i32> = d;
    let _e122: vec3<i32> = f_1;
    let _e124: vec3<i32> = d;
    let _e126: vec3<i32> = f_1;
    return ((_e116 + _e117.x) + (_e120.x * (_e122.y + (_e124.y * _e126.z))));
}

fn faceOffset(comp_6: i32) -> vec3<f32> {
    var comp_7: i32;
    var local_5: f32;
    var local_6: f32;
    var local_7: f32;

    comp_7 = comp_6;
    let _e110: i32 = comp_7;
    if (_e110 == 0i) {
        local_5 = 0f;
    } else {
        local_5 = 0.5f;
    }
    let _e116: f32 = local_5;
    let _e117: i32 = comp_7;
    if (_e117 == 1i) {
        local_6 = 0f;
    } else {
        local_6 = 0.5f;
    }
    let _e123: f32 = local_6;
    let _e124: i32 = comp_7;
    if (_e124 == 2i) {
        local_7 = 0f;
    } else {
        local_7 = 0.5f;
    }
    let _e130: f32 = local_7;
    return vec3<f32>(_e116, _e123, _e130);
}

fn axisVec(comp_8: i32) -> vec3<i32> {
    var comp_9: i32;
    var local_8: i32;
    var local_9: i32;
    var local_10: i32;

    comp_9 = comp_8;
    let _e110: i32 = comp_9;
    if (_e110 == 0i) {
        local_8 = 1i;
    } else {
        local_8 = 0i;
    }
    let _e116: i32 = local_8;
    let _e117: i32 = comp_9;
    if (_e117 == 1i) {
        local_9 = 1i;
    } else {
        local_9 = 0i;
    }
    let _e123: i32 = local_9;
    let _e124: i32 = comp_9;
    if (_e124 == 2i) {
        local_10 = 1i;
    } else {
        local_10 = 0i;
    }
    let _e130: i32 = local_10;
    return vec3<i32>(_e116, _e123, _e130);
}

fn decodeFace(i_2: i32, comp_10: ptr<function, i32>, f_2: ptr<function, vec3<i32>>) {
    var i_3: i32;
    var d_1: vec3<i32>;

    i_3 = i_2;
    let _e112: i32 = i_3;
    let _e114: vec4<i32> = G.faces;
    if (_e112 < _e114.x) {
        {
            (*comp_10) = 0i;
        }
    } else {
        let _e118: i32 = i_3;
        let _e120: vec4<i32> = G.faces;
        let _e123: vec4<i32> = G.faces;
        if (_e118 < (_e120.x + _e123.y)) {
            {
                (*comp_10) = 1i;
                let _e128: i32 = i_3;
                let _e130: vec4<i32> = G.faces;
                i_3 = (_e128 - _e130.x);
            }
        } else {
            {
                (*comp_10) = 2i;
                let _e134: i32 = i_3;
                let _e136: vec4<i32> = G.faces;
                let _e139: vec4<i32> = G.faces;
                i_3 = (_e134 - (_e136.x + _e139.y));
            }
        }
    }
    let _e143: i32 = (*comp_10);
    let _e144: vec3<i32> = faceDims(_e143);
    d_1 = _e144;
    let _e146: i32 = i_3;
    let _e147: vec3<i32> = d_1;
    let _e150: i32 = i_3;
    let _e151: vec3<i32> = d_1;
    let _e154: vec3<i32> = d_1;
    let _e157: i32 = i_3;
    let _e158: vec3<i32> = d_1;
    let _e160: vec3<i32> = d_1;
    (*f_2) = vec3<i32>((_e146 % _e147.x), ((_e150 / _e151.x) % _e154.y), (_e157 / (_e158.x * _e160.y)));
    return;
}

fn boxDims() -> vec3<i32> {
    let _e109: vec4<i32> = G.boxMax;
    let _e112: vec4<i32> = G.boxMin;
    return (_e109.xyz - _e112.xyz);
}

fn inBox(c_4: vec3<i32>) -> bool {
    var c_5: vec3<i32>;

    c_5 = c_4;
    let _e110: vec3<i32> = c_5;
    let _e112: vec4<i32> = G.boxMin;
    let _e116: vec3<i32> = c_5;
    let _e118: vec4<i32> = G.boxMax;
    return (all((_e110 >= _e112.xyz)) && all((_e116 < _e118.xyz)));
}

fn boxIndex(c_6: vec3<i32>) -> i32 {
    var c_7: vec3<i32>;
    var d_2: vec3<i32>;
    var l: vec3<i32>;

    c_7 = c_6;
    let _e110: vec3<i32> = boxDims();
    d_2 = _e110;
    let _e112: vec3<i32> = c_7;
    let _e114: vec4<i32> = G.boxMin;
    l = (_e112 - _e114.xyz);
    let _e118: vec3<i32> = l;
    let _e120: vec3<i32> = d_2;
    let _e122: vec3<i32> = l;
    let _e124: vec3<i32> = d_2;
    let _e126: vec3<i32> = l;
    return (_e118.x + (_e120.x * (_e122.y + (_e124.y * _e126.z))));
}

fn inInnerBox(x: vec3<f32>) -> bool {
    var x_1: vec3<f32>;

    x_1 = x;
    let _e110: vec3<f32> = x_1;
    let _e112: vec4<i32> = G.boxMin;
    let _e120: vec3<f32> = x_1;
    let _e122: vec4<i32> = G.boxMax;
    return (all((_e110 >= (vec3<f32>(_e112.xyz) + vec3(2f)))) && all((_e120 < (vec3<f32>(_e122.xyz) - vec3(2f)))));
}

fn boxCell(t: i32) -> vec3<i32> {
    var t_1: i32;
    var d_3: vec3<i32>;

    t_1 = t;
    let _e110: vec3<i32> = boxDims();
    d_3 = _e110;
    let _e113: vec4<i32> = G.boxMin;
    let _e115: i32 = t_1;
    let _e116: vec3<i32> = d_3;
    let _e119: i32 = t_1;
    let _e120: vec3<i32> = d_3;
    let _e123: vec3<i32> = d_3;
    let _e126: i32 = t_1;
    let _e127: vec3<i32> = d_3;
    let _e129: vec3<i32> = d_3;
    return (_e113.xyz + vec3<i32>((_e115 % _e116.x), ((_e119 / _e120.x) % _e123.y), (_e126 / (_e127.x * _e129.y))));
}

fn faceInBox(comp_11: i32, f_3: vec3<i32>) -> bool {
    var comp_12: i32;
    var f_4: vec3<i32>;

    comp_12 = comp_11;
    f_4 = f_3;
    let _e112: vec3<i32> = f_4;
    let _e114: vec4<i32> = G.boxMin;
    let _e118: vec3<i32> = f_4;
    let _e120: vec4<i32> = G.boxMax;
    let _e122: i32 = comp_12;
    let _e123: vec3<i32> = axisVec(_e122);
    return (all((_e112 >= _e114.xyz)) && all((_e118 < (_e120.xyz + _e123))));
}

fn boxFace(t_2: i32, comp_13: ptr<function, i32>, f_5: ptr<function, vec3<i32>>) -> bool {
    var t_3: i32;
    var d_4: vec3<i32>;
    var fd: vec3<i32>;
    var n: i32;

    t_3 = t_2;
    let _e112: vec3<i32> = boxDims();
    d_4 = _e112;
    (*comp_13) = 0i;
    loop {
        let _e115: i32 = (*comp_13);
        if !((_e115 < 3i)) {
            break;
        }
        {
            let _e122: vec3<i32> = d_4;
            let _e123: i32 = (*comp_13);
            let _e124: vec3<i32> = axisVec(_e123);
            fd = (_e122 + _e124);
            let _e127: vec3<i32> = fd;
            let _e129: vec3<i32> = fd;
            let _e132: vec3<i32> = fd;
            n = ((_e127.x * _e129.y) * _e132.z);
            let _e136: i32 = t_3;
            let _e137: i32 = n;
            if (_e136 < _e137) {
                {
                    let _e140: vec4<i32> = G.boxMin;
                    let _e142: i32 = t_3;
                    let _e143: vec3<i32> = fd;
                    let _e146: i32 = t_3;
                    let _e147: vec3<i32> = fd;
                    let _e150: vec3<i32> = fd;
                    let _e153: i32 = t_3;
                    let _e154: vec3<i32> = fd;
                    let _e156: vec3<i32> = fd;
                    (*f_5) = (_e140.xyz + vec3<i32>((_e142 % _e143.x), ((_e146 / _e147.x) % _e150.y), (_e153 / (_e154.x * _e156.y))));
                    return true;
                }
            }
            let _e163: i32 = t_3;
            let _e164: i32 = n;
            t_3 = (_e163 - _e164);
        }
        continuing {
            let _e119: i32 = (*comp_13);
            (*comp_13) = (_e119 + 1i);
        }
    }
    (*f_5) = vec3(0i);
    return false;
}

fn numEntities() -> i32 {
    let _e109: vec4<i32> = G.caps;
    return _e109.z;
}

fn entMin(e: i32) -> vec3<f32> {
    var e_1: i32;

    e_1 = e;
    let _e110: i32 = e_1;
    let _e115: vec4<f32> = G.ent[(_e110 * 3i)];
    return _e115.xyz;
}

fn entMax(e_2: i32) -> vec3<f32> {
    var e_3: i32;

    e_3 = e_2;
    let _e110: i32 = e_3;
    let _e117: vec4<f32> = G.ent[((_e110 * 3i) + 1i)];
    return _e117.xyz;
}

fn entVel(e_4: i32) -> vec3<f32> {
    var e_5: i32;

    e_5 = e_4;
    let _e110: i32 = e_5;
    let _e117: vec4<f32> = G.ent[((_e110 * 3i) + 2i)];
    return _e117.xyz;
}

fn entityAt(p: vec3<f32>) -> i32 {
    var p_1: vec3<f32>;
    var e_6: i32 = 0i;

    p_1 = p;
    loop {
        let _e112: i32 = e_6;
        let _e113: i32 = numEntities();
        if !((_e112 < _e113)) {
            break;
        }
        {
            let _e119: vec3<f32> = p_1;
            let _e120: i32 = e_6;
            let _e121: vec3<f32> = entMin(_e120);
            let _e124: vec3<f32> = p_1;
            let _e125: i32 = e_6;
            let _e126: vec3<f32> = entMax(_e125);
            if (all((_e119 >= _e121)) && all((_e124 <= _e126))) {
                {
                    let _e130: i32 = e_6;
                    return _e130;
                }
            }
        }
        continuing {
            let _e116: i32 = e_6;
            e_6 = (_e116 + 1i);
        }
    }
    return -1i;
}

fn hash(x_2: u32) -> u32 {
    var x_3: u32;

    x_3 = x_2;
    let _e110: u32 = x_3;
    let _e111: u32 = x_3;
    x_3 = (_e110 ^ (_e111 >> 16u));
    let _e116: u32 = x_3;
    x_3 = (_e116 * 2146121005u);
    let _e119: u32 = x_3;
    let _e120: u32 = x_3;
    x_3 = (_e119 ^ (_e120 >> 15u));
    let _e125: u32 = x_3;
    x_3 = (_e125 * 2221713035u);
    let _e128: u32 = x_3;
    let _e129: u32 = x_3;
    x_3 = (_e128 ^ (_e129 >> 16u));
    let _e134: u32 = x_3;
    return _e134;
}

fn rand(state: ptr<function, u32>) -> f32 {
    let _e109: u32 = (*state);
    let _e112: u32 = hash((_e109 + 2654435769u));
    (*state) = _e112;
    let _e113: u32 = (*state);
    return (f32((_e113 >> 8u)) * 0.000000059604645f);
}

fn randInSphere(state_1: ptr<function, u32>) -> vec3<f32> {
    var i_4: i32 = 0i;
    var local_11: u32;
    var local_12: u32;
    var local_13: u32;
    var p_2: vec3<f32>;

    loop {
        let _e111: i32 = i_4;
        if !((_e111 < 8i)) {
            break;
        }
        {
            let _e119: u32 = (*state_1);
            local_11 = _e119;
            let _e121: f32 = rand((&local_11));
            let _e122: u32 = local_11;
            (*state_1) = _e122;
            let _e124: u32 = (*state_1);
            local_12 = _e124;
            let _e126: f32 = rand((&local_12));
            let _e127: u32 = local_12;
            (*state_1) = _e127;
            let _e129: u32 = (*state_1);
            local_13 = _e129;
            let _e131: f32 = rand((&local_13));
            let _e132: u32 = local_13;
            (*state_1) = _e132;
            p_2 = ((vec3<f32>(_e121, _e126, _e131) * 2f) - vec3(1f));
            let _e140: vec3<f32> = p_2;
            let _e141: vec3<f32> = p_2;
            if (dot(_e140, _e141) <= 1f) {
                {
                    let _e145: vec3<f32> = p_2;
                    return _e145;
                }
            }
        }
        continuing {
            let _e115: i32 = i_4;
            i_4 = (_e115 + 1i);
        }
    }
    return vec3(0f);
}

fn clampPhi(v: f32, lo: f32, hi: f32) -> f32 {
    var v_1: f32;
    var lo_1: f32;
    var hi_1: f32;

    v_1 = v;
    lo_1 = lo;
    hi_1 = hi;
    let _e114: f32 = v_1;
    let _e115: f32 = lo_1;
    let _e117: f32 = hi_1;
    let _e118: f32 = lo_1;
    return clamp(((_e114 - _e115) / max((_e117 - _e118), 0.000001f)), 0f, 1f);
}

fn fineIndex(p_3: vec3<i32>) -> i32 {
    var p_4: vec3<i32>;

    p_4 = p_3;
    let _e110: vec3<i32> = p_4;
    let _e113: vec4<i32> = G.fine;
    let _e115: vec3<i32> = p_4;
    let _e118: vec4<i32> = G.fine;
    let _e120: vec3<i32> = p_4;
    return (_e110.x + (_e113.x * (_e115.y + (_e118.y * _e120.z))));
}

fn inFine(p_5: vec3<i32>) -> bool {
    var p_6: vec3<i32>;

    p_6 = p_5;
    let _e110: vec3<i32> = p_6;
    let _e112: vec4<i32> = G.fineBoxMin;
    let _e116: vec3<i32> = p_6;
    let _e118: vec4<i32> = G.fineBoxMax;
    return (all((_e110 >= _e112.xyz)) && all((_e116 < _e118.xyz)));
}

fn packNormal(n_1: vec3<f32>, flag: bool) -> u32 {
    var n_2: vec3<f32>;
    var flag_1: bool;
    var local_14: f32;
    var local_15: f32;
    var local_16: vec2<f32>;
    var e_7: vec2<f32>;
    var q: vec2<u32>;
    var local_17: u32;

    n_2 = n_1;
    flag_1 = flag;
    let _e112: vec3<f32> = n_2;
    let _e113: vec3<f32> = n_2;
    let _e116: vec3<f32> = n_2;
    let _e120: vec3<f32> = n_2;
    n_2 = (_e112 / vec3(((abs(_e113.x) + abs(_e116.y)) + abs(_e120.z))));
    let _e126: vec3<f32> = n_2;
    if (_e126.z >= 0f) {
        let _e130: vec3<f32> = n_2;
        local_16 = _e130.xy;
    } else {
        let _e133: vec3<f32> = n_2;
        let _e138: vec3<f32> = n_2;
        if (_e138.x >= 0f) {
            local_14 = 1f;
        } else {
            local_14 = -1f;
        }
        let _e146: f32 = local_14;
        let _e147: vec3<f32> = n_2;
        if (_e147.y >= 0f) {
            local_15 = 1f;
        } else {
            local_15 = -1f;
        }
        let _e155: f32 = local_15;
        local_16 = ((vec2(1f) - abs(_e133.yx)) * vec2<f32>(_e146, _e155));
    }
    let _e159: vec2<f32> = local_16;
    e_7 = _e159;
    let _e161: vec2<f32> = e_7;
    q = vec2<u32>(((clamp(((_e161 * 0.5f) + vec2(0.5f)), vec2(0f), vec2(1f)) * 32767f) + vec2(0.5f)));
    let _e179: vec2<u32> = q;
    let _e181: vec2<u32> = q;
    let _e187: bool = flag_1;
    if _e187 {
        local_17 = 1073741824u;
    } else {
        local_17 = 0u;
    }
    let _e191: u32 = local_17;
    return ((_e179.x | (_e181.y << 15u)) | _e191);
}

fn unpackNormal(v_2: u32, flag_2: ptr<function, bool>) -> vec3<f32> {
    var v_3: u32;
    var e_8: vec2<f32>;
    var n_3: vec3<f32>;
    var local_18: f32;
    var local_19: f32;

    v_3 = v_2;
    let _e111: u32 = v_3;
    (*flag_2) = ((_e111 & 1073741824u) != 0u);
    let _e116: u32 = v_3;
    let _e120: u32 = v_3;
    e_8 = (((vec2<f32>(f32((_e116 & 32767u)), f32(((_e120 >> 15u) & 32767u))) / vec2(32767f)) * 2f) - vec2(1f));
    let _e137: vec2<f32> = e_8;
    let _e139: vec2<f32> = e_8;
    let _e143: vec2<f32> = e_8;
    n_3 = vec3<f32>(_e137.x, _e137.y, ((1f - abs(_e139.x)) - abs(_e143.y)));
    let _e151: vec3<f32> = n_3;
    if (_e151.z < 0f) {
        {
            let _e155: vec3<f32> = n_3;
            let _e158: vec3<f32> = n_3;
            let _e163: vec3<f32> = n_3;
            if (_e163.x >= 0f) {
                local_18 = 1f;
            } else {
                local_18 = -1f;
            }
            let _e171: f32 = local_18;
            let _e172: vec3<f32> = n_3;
            if (_e172.y >= 0f) {
                local_19 = 1f;
            } else {
                local_19 = -1f;
            }
            let _e180: f32 = local_19;
            let _e182: vec2<f32> = ((vec2(1f) - abs(_e158.yx)) * vec2<f32>(_e171, _e180));
            n_3.x = _e182.x;
            n_3.y = _e182.y;
        }
    }
    let _e187: vec3<f32> = n_3;
    return normalize(_e187);
}

fn sunLit(viewPos: vec3<f32>) -> f32 {
    var viewPos_1: vec3<f32>;
    var relative: vec3<f32>;
    var cascade: i32 = 0i;
    var clip: vec4<f32>;
    var xy: vec2<f32>;
    var uv: vec2<f32>;
    var texel: f32;
    var lit: f32 = 0f;
    var k: i32 = 0i;
    var o: vec2<f32>;
    var local_20: f32;

    viewPos_1 = viewPos;
    let _e121: vec4<f32> = G.compat;
    if (_e121.w < 0.5f) {
        {
            return 1f;
        }
    }
    let _e127: mat4x4<f32> = G.invView;
    let _e137: vec3<f32> = viewPos_1;
    relative = (mat3x3<f32>(_e127[0].xyz, _e127[1].xyz, _e127[2].xyz) * _e137);
    let _e143: mat4x4<f32> = G.shadowNear;
    let _e144: vec3<f32> = relative;
    clip = (_e143 * vec4<f32>(_e144.x, _e144.y, _e144.z, 1f));
    let _e152: vec4<f32> = clip;
    let _e155: vec4<f32> = clip;
    if (max(abs(_e152.x), abs(_e155.y)) >= 0.94f) {
        {
            cascade = 1i;
            let _e163: mat4x4<f32> = G.shadowMid;
            let _e164: vec3<f32> = relative;
            clip = (_e163 * vec4<f32>(_e164.x, _e164.y, _e164.z, 1f));
            let _e171: vec4<f32> = clip;
            let _e174: vec4<f32> = clip;
            if (max(abs(_e171.x), abs(_e174.y)) >= 0.94f) {
                {
                    cascade = 2i;
                    let _e182: mat4x4<f32> = G.shadowFar;
                    let _e183: vec3<f32> = relative;
                    clip = (_e182 * vec4<f32>(_e183.x, _e183.y, _e183.z, 1f));
                    let _e190: vec4<f32> = clip;
                    let _e193: vec4<f32> = clip;
                    if (max(abs(_e190.x), abs(_e193.y)) > 1f) {
                        {
                            return 1f;
                        }
                    }
                }
            }
        }
    }
    let _e200: vec4<f32> = clip;
    xy = _e200.xy;
    let _e203: vec2<f32> = xy;
    let _e211: i32 = cascade;
    let _e215: i32 = cascade;
    uv = ((((_e203 * 0.5f) + vec2(0.5f)) * 0.5f) + (vec2<f32>(f32((_e211 % 2i)), f32((_e215 / 2i))) * 0.5f));
    let _e226: vec2<u32> = textureDimensions(shadowTex_texture, 0i);
    texel = (1f / f32(vec2<i32>(_e226).x));
    loop {
        let _e236: i32 = k;
        if !((_e236 < 4i)) {
            break;
        }
        {
            let _e243: i32 = k;
            let _e247: i32 = k;
            let _e256: f32 = texel;
            o = ((vec2<f32>(f32((_e243 & 1i)), f32((_e247 >> 1u))) - vec2(0.5f)) * _e256);
            let _e259: f32 = lit;
            let _e260: vec2<f32> = uv;
            let _e261: vec2<f32> = o;
            let _e263: vec4<f32> = textureSample(shadowTex_texture, shadowTex_sampler, (_e260 + _e261));
            let _e265: vec4<f32> = clip;
            let _e268: vec4<f32> = G.compatB;
            if (_e263.x >= (_e265.z - _e268.z)) {
                local_20 = 1f;
            } else {
                local_20 = 0f;
            }
            let _e275: f32 = local_20;
            lit = (_e259 + _e275);
        }
        continuing {
            let _e240: i32 = k;
            k = (_e240 + 1i);
        }
    }
    let _e277: f32 = lit;
    return (_e277 * 0.25f);
}

fn regionLightAt(sim: vec3<f32>) -> vec2<f32> {
    var sim_1: vec3<f32>;
    var res: i32;
    var n_4: vec3<i32>;
    var p_7: vec3<f32>;
    var b: vec3<i32>;
    var f_6: vec3<f32>;
    var sum: vec2<f32> = vec2(0f);
    var weight: f32 = 0f;
    var brightest: vec2<f32> = vec2(0f);
    var k_1: i32 = 0i;
    var o_1: vec3<i32>;
    var c_8: vec3<i32>;
    var v_4: u32;
    var level: vec2<f32>;
    var w3_: vec3<f32>;
    var w: f32;
    var local_21: vec2<f32>;

    sim_1 = sim;
    let _e123: vec4<f32> = G.camGrid;
    res = max(i32((_e123.w + 0.5f)), 1i);
    let _e132: vec4<i32> = G.dims;
    let _e134: i32 = res;
    n_4 = max((_e132.xyz / vec3(_e134)), vec3(1i));
    let _e141: vec3<f32> = sim_1;
    let _e142: i32 = res;
    p_7 = ((_e141 / vec3(f32(_e142))) - vec3(0.5f));
    let _e150: vec3<f32> = p_7;
    b = vec3<i32>(floor(_e150));
    let _e154: vec3<f32> = p_7;
    let _e155: vec3<i32> = b;
    f_6 = (_e154 - vec3<f32>(_e155));
    loop {
        let _e169: i32 = k_1;
        if !((_e169 < 8i)) {
            break;
        }
        {
            let _e176: i32 = k_1;
            let _e179: i32 = k_1;
            let _e185: i32 = k_1;
            o_1 = vec3<i32>((_e176 & 1i), ((_e179 >> 1u) & 1i), (_e185 >> 2u));
            let _e191: vec3<i32> = b;
            let _e192: vec3<i32> = o_1;
            let _e196: vec3<i32> = n_4;
            c_8 = clamp((_e191 + _e192), vec3(0i), (_e196 - vec3(1i)));
            let _e202: vec3<i32> = c_8;
            let _e204: vec3<i32> = n_4;
            let _e206: vec3<i32> = c_8;
            let _e208: vec3<i32> = n_4;
            let _e210: vec3<i32> = c_8;
            let _e217: u32 = global.regionLight[(_e202.x + (_e204.x * (_e206.y + (_e208.y * _e210.z))))];
            v_4 = _e217;
            let _e219: u32 = v_4;
            let _e223: u32 = v_4;
            level = (vec2<f32>(f32((_e219 & 15u)), f32(((_e223 >> 4u) & 15u))) / vec2(15f));
            let _e235: vec2<f32> = brightest;
            let _e236: vec2<f32> = level;
            brightest = max(_e235, _e236);
            let _e238: u32 = v_4;
            if ((_e238 & 256u) != 0u) {
                {
                    continue;
                }
            }
            let _e244: vec3<f32> = f_6;
            let _e247: vec3<f32> = f_6;
            let _e248: vec3<i32> = o_1;
            w3_ = mix((vec3(1f) - _e244), _e247, vec3<f32>(_e248));
            let _e252: vec3<f32> = w3_;
            let _e254: vec3<f32> = w3_;
            let _e257: vec3<f32> = w3_;
            w = ((_e252.x * _e254.y) * _e257.z);
            let _e261: vec2<f32> = sum;
            let _e262: vec2<f32> = level;
            let _e263: f32 = w;
            sum = (_e261 + (_e262 * _e263));
            let _e266: f32 = weight;
            let _e267: f32 = w;
            weight = (_e266 + _e267);
        }
        continuing {
            let _e173: i32 = k_1;
            k_1 = (_e173 + 1i);
        }
    }
    let _e269: f32 = weight;
    if (_e269 > 0.0001f) {
        let _e272: vec2<f32> = sum;
        let _e273: f32 = weight;
        local_21 = (_e272 / vec2(_e273));
    } else {
        let _e276: vec2<f32> = brightest;
        local_21 = _e276;
    }
    let _e278: vec2<f32> = local_21;
    return _e278;
}

fn relToSim(rel: vec3<f32>) -> vec3<f32> {
    var rel_1: vec3<f32>;

    rel_1 = rel;
    let _e122: vec3<f32> = rel_1;
    let _e124: vec4<f32> = G.domainOrigin;
    let _e128: vec4<f32> = G.domainOrigin;
    return ((_e122 - _e124.xyz) / vec3(_e128.w));
}

fn vanillaLight(bs: vec2<f32>) -> vec3<f32> {
    var bs_1: vec2<f32>;

    bs_1 = bs;
    let _e130: vec2<f32> = bs_1;
    let _e144: vec4<f32> = textureSample(lightmapTex_texture, lightmapTex_sampler, (((clamp(_e130, vec2(0f), vec2(1f)) * 15f) + vec2(0.5f)) / vec2(16f)));
    return _e144.xyz;
}

fn blockCurve(level_1: f32) -> f32 {
    var level_2: f32;

    level_2 = level_1;
    let _e130: f32 = level_2;
    let _e135: f32 = level_2;
    return ((pow(_e130, 3f) * 0.9f) + (pow(_e135, 8f) * 0.6f));
}

fn shaderSkyAmbient(nWorld: vec3<f32>) -> vec3<f32> {
    var nWorld_1: vec3<f32>;
    var sky: vec3<f32>;
    var luma: f32;

    nWorld_1 = nWorld;
    let _e131: vec4<f32> = G.fogColor;
    let _e136: vec4<f32> = G.skyColor;
    let _e140: vec3<f32> = nWorld_1;
    sky = mix((_e131.xyz * 0.75f), (_e136.xyz * 1.1f), vec3(((_e140.y * 0.5f) + 0.5f)));
    let _e149: vec3<f32> = sky;
    luma = dot(_e149, vec3<f32>(0.2126f, 0.7152f, 0.0722f));
    let _e156: f32 = luma;
    let _e158: vec3<f32> = sky;
    return mix(vec3(_e156), _e158, vec3(0.45f));
}

fn inColorVolume(rel_2: vec3<f32>) -> bool {
    var rel_3: vec3<f32>;
    var range: i32;
    var local_22: vec3<f32>;
    var size: vec3<f32>;

    rel_3 = rel_2;
    let _e131: vec4<f32> = G.lightA;
    range = i32(_e131.w);
    let _e136: vec4<f32> = G.lightC;
    let _e140: i32 = range;
    if ((_e136.z < 0.5f) || (_e140 <= 0i)) {
        {
            return false;
        }
    }
    let _e145: vec3<f32> = rel_3;
    let _e147: vec4<f32> = G.lightA;
    local_22 = (_e145 - _e147.xyz);
    let _e151: i32 = range;
    let _e153: i32 = range;
    let _e157: i32 = range;
    size = vec3<f32>(f32(_e151), f32((_e153 / 2i)), f32(_e157));
    let _e161: vec3<f32> = local_22;
    let _e166: vec3<f32> = local_22;
    let _e167: vec3<f32> = size;
    return (all((_e161 >= vec3(0.5f))) && all((_e166 <= (_e167 - vec3(0.5f)))));
}

fn colorLightUv(slice: i32, xz: vec2<f32>) -> vec2<f32> {
    var slice_1: i32;
    var xz_1: vec2<f32>;
    var range_1: i32;
    var columns: i32;
    var local_23: vec2<f32>;
    var corner: vec2<f32>;

    slice_1 = slice;
    xz_1 = xz;
    let _e133: vec4<f32> = G.lightA;
    range_1 = i32(_e133.w);
    let _e138: vec4<f32> = G.lightB;
    columns = max(i32(_e138.w), 1i);
    let _e144: vec2<f32> = xz_1;
    let _e147: vec2<f32> = (_e144 - vec2(0.5f));
    let _e148: i32 = range_1;
    let _e150: vec2<f32> = vec2(f32(_e148));
    local_23 = (_e147 - (floor((_e147 / _e150)) * _e150));
    let _e156: i32 = slice_1;
    let _e157: i32 = columns;
    let _e160: i32 = slice_1;
    let _e161: i32 = columns;
    let _e165: i32 = range_1;
    corner = (vec2<f32>(f32((_e156 % _e157)), f32((_e160 / _e161))) * f32((_e165 + 2i)));
    let _e171: vec2<f32> = corner;
    let _e175: vec2<f32> = local_23;
    let _e178: vec4<f32> = G.lightC;
    return (((_e171 + vec2(1.5f)) + _e175) / _e178.xy);
}

fn colorLightAt(rel_4: vec3<f32>, typed: ptr<function, f32>) -> vec3<f32> {
    var rel_5: vec3<f32>;
    var range_2: i32;
    var height: i32;
    var world: vec3<f32>;
    var y: f32;
    var y0_: i32;
    var y1_: i32;
    var fy: f32;
    var uv0_: vec2<f32>;
    var uv1_: vec2<f32>;
    var t_4: vec4<f32>;
    var local_24: vec3<f32>;
    var size_1: vec3<f32>;
    var edge: vec3<f32>;
    var scale: f32;
    var a: vec4<f32>;
    var b_1: vec4<f32>;
    var m: vec4<f32>;
    var light: vec3<f32>;

    rel_5 = rel_4;
    (*typed) = 0f;
    let _e133: vec4<f32> = G.lightA;
    range_2 = i32(_e133.w);
    let _e137: i32 = range_2;
    height = (_e137 / 2i);
    let _e141: vec3<f32> = rel_5;
    let _e143: vec4<f32> = G.lightB;
    world = (_e141 + _e143.xyz);
    let _e147: vec3<f32> = world;
    let _e150: f32 = (_e147.y - 0.5f);
    let _e151: i32 = height;
    let _e152: f32 = f32(_e151);
    y = (_e150 - (floor((_e150 / _e152)) * _e152));
    let _e158: f32 = y;
    y0_ = i32(floor(_e158));
    let _e162: i32 = y0_;
    let _e165: i32 = height;
    y1_ = ((_e162 + 1i) % _e165);
    let _e168: f32 = y;
    let _e169: f32 = y;
    fy = (_e168 - floor(_e169));
    let _e173: i32 = y0_;
    let _e174: vec3<f32> = world;
    let _e176: vec2<f32> = colorLightUv(_e173, _e174.xz);
    uv0_ = _e176;
    let _e178: i32 = y1_;
    let _e179: vec3<f32> = world;
    let _e181: vec2<f32> = colorLightUv(_e178, _e179.xz);
    uv1_ = _e181;
    let _e183: vec2<f32> = uv0_;
    let _e185: vec4<f32> = textureSampleLevel(skLightTint_texture, skLightTint_sampler, _e183, 0f);
    let _e186: vec2<f32> = uv1_;
    let _e188: vec4<f32> = textureSampleLevel(skLightTint_texture, skLightTint_sampler, _e186, 0f);
    let _e189: f32 = fy;
    t_4 = mix(_e185, _e188, vec4(_e189));
    let _e193: vec4<f32> = t_4;
    if (_e193.w < 0.001f) {
        {
            return vec3(0f);
        }
    }
    let _e199: vec3<f32> = rel_5;
    let _e201: vec4<f32> = G.lightA;
    local_24 = (_e199 - _e201.xyz);
    let _e205: i32 = range_2;
    let _e207: i32 = height;
    let _e209: i32 = range_2;
    size_1 = vec3<f32>(f32(_e205), f32(_e207), f32(_e209));
    let _e213: vec3<f32> = local_24;
    let _e214: vec3<f32> = size_1;
    let _e215: vec3<f32> = local_24;
    edge = min(_e213, (_e214 - _e215));
    let _e219: vec3<f32> = edge;
    let _e221: vec3<f32> = edge;
    let _e223: vec3<f32> = edge;
    let _e234: vec4<f32> = t_4;
    scale = (clamp(((min(_e219.x, min(_e221.y, _e223.z)) / 6f) - 0.1f), 0f, 1f) / _e234.w);
    let _e238: vec2<f32> = uv0_;
    let _e240: vec4<f32> = textureSampleLevel(skLightA_texture, skLightA_sampler, _e238, 0f);
    let _e241: vec2<f32> = uv1_;
    let _e243: vec4<f32> = textureSampleLevel(skLightA_texture, skLightA_sampler, _e241, 0f);
    let _e244: f32 = fy;
    let _e247: f32 = scale;
    a = (mix(_e240, _e243, vec4(_e244)) * _e247);
    let _e250: vec2<f32> = uv0_;
    let _e252: vec4<f32> = textureSampleLevel(skLightB_texture, skLightB_sampler, _e250, 0f);
    let _e253: vec2<f32> = uv1_;
    let _e255: vec4<f32> = textureSampleLevel(skLightB_texture, skLightB_sampler, _e253, 0f);
    let _e256: f32 = fy;
    let _e259: f32 = scale;
    b_1 = (mix(_e252, _e255, vec4(_e256)) * _e259);
    let _e262: vec4<f32> = a;
    let _e263: vec4<f32> = b_1;
    m = max(_e262, _e263);
    let _e266: vec4<f32> = m;
    let _e268: vec4<f32> = m;
    let _e271: vec4<f32> = m;
    let _e273: vec4<f32> = m;
    (*typed) = max(max(_e266.x, _e268.y), max(_e271.z, _e273.w));
    let _e277: vec4<f32> = a;
    let _e282: vec4<f32> = G.lightColors[0];
    let _e285: vec4<f32> = a;
    let _e290: vec4<f32> = G.lightColors[1];
    let _e294: vec4<f32> = a;
    let _e299: vec4<f32> = G.lightColors[2];
    let _e303: vec4<f32> = a;
    let _e308: vec4<f32> = G.lightColors[3];
    let _e312: vec4<f32> = b_1;
    let _e317: vec4<f32> = G.lightColors[4];
    let _e321: vec4<f32> = b_1;
    let _e326: vec4<f32> = G.lightColors[5];
    let _e330: vec4<f32> = b_1;
    let _e335: vec4<f32> = G.lightColors[6];
    let _e339: vec4<f32> = b_1;
    let _e344: vec4<f32> = G.lightColors[7];
    light = ((((((((_e277.x * _e282.xyz) + (_e285.y * _e290.xyz)) + (_e294.z * _e299.xyz)) + (_e303.w * _e308.xyz)) + (_e312.x * _e317.xyz)) + (_e321.y * _e326.xyz)) + (_e330.z * _e335.xyz)) + (_e339.w * _e344.xyz));
    let _e349: vec3<f32> = light;
    let _e350: vec4<f32> = t_4;
    let _e353: vec4<f32> = t_4;
    return ((_e349 * _e350.xyz) / vec3(_e353.w));
}

fn shaderBlockLight(rel_6: vec3<f32>, nWorld_2: vec3<f32>, level_3: f32) -> vec3<f32> {
    var rel_7: vec3<f32>;
    var nWorld_3: vec3<f32>;
    var level_4: f32;
    var torch: vec3<f32> = vec3<f32>(1.4f, 0.84000003f, 0.42000002f);
    var vanilla: vec3<f32>;
    var at: vec3<f32>;
    var typed_1: f32;
    var colored: vec3<f32>;
    var local_25: vec3<f32>;
    var shaped: vec3<f32>;
    var rest: vec3<f32>;

    rel_7 = rel_6;
    nWorld_3 = nWorld_2;
    level_4 = level_3;
    let _e145: vec3<f32> = torch;
    let _e146: f32 = level_4;
    let _e147: f32 = blockCurve(_e146);
    vanilla = (_e145 * _e147);
    let _e150: vec3<f32> = rel_7;
    let _e151: vec3<f32> = nWorld_3;
    at = (_e150 + (_e151 * 0.5f));
    let _e156: vec3<f32> = at;
    let _e157: bool = inColorVolume(_e156);
    if !(_e157) {
        {
            let _e159: vec3<f32> = vanilla;
            return _e159;
        }
    }
    let _e161: vec3<f32> = at;
    let _e164: vec3<f32> = colorLightAt(_e161, (&typed_1));
    colored = _e164;
    let _e166: f32 = typed_1;
    if (_e166 > 0.0001f) {
        let _e169: vec3<f32> = colored;
        let _e170: f32 = typed_1;
        let _e173: f32 = typed_1;
        let _e176: f32 = blockCurve(min(_e173, 1f));
        local_25 = (((_e169 / vec3(_e170)) * _e176) * 1.4f);
    } else {
        local_25 = vec3(0f);
    }
    let _e183: vec3<f32> = local_25;
    shaped = _e183;
    let _e185: vec3<f32> = torch;
    let _e186: f32 = level_4;
    let _e187: f32 = blockCurve(_e186);
    let _e188: f32 = typed_1;
    let _e195: f32 = blockCurve(min((_e188 + 0.06666667f), 1f));
    rest = (_e185 * max((_e187 - _e195), 0f));
    let _e201: vec3<f32> = shaped;
    let _e202: vec3<f32> = rest;
    return (_e201 + _e202);
}

fn shaderSurfaceLight(rel_8: vec3<f32>, viewPos_2: vec3<f32>, nWorld_4: vec3<f32>, bs_2: vec2<f32>) -> vec3<f32> {
    var rel_9: vec3<f32>;
    var viewPos_3: vec3<f32>;
    var nWorld_5: vec3<f32>;
    var bs_3: vec2<f32>;
    var toSun: vec3<f32>;
    var day: f32;
    var direct: f32;
    var sunColor: vec3<f32>;

    rel_9 = rel_8;
    viewPos_3 = viewPos_2;
    nWorld_5 = nWorld_4;
    bs_3 = bs_2;
    let _e137: mat4x4<f32> = G.invView;
    let _e148: vec4<f32> = G.sunDir;
    toSun = normalize((mat3x3<f32>(_e137[0].xyz, _e137[1].xyz, _e137[2].xyz) * _e148.xyz));
    let _e154: vec4<f32> = G.skyColor;
    day = clamp((_e154.w / 0.85f), 0.2f, 1f);
    let _e162: vec3<f32> = nWorld_5;
    let _e163: vec3<f32> = toSun;
    let _e168: vec4<f32> = G.sunDir;
    let _e171: vec3<f32> = viewPos_3;
    let _e172: f32 = sunLit(_e171);
    let _e176: vec2<f32> = bs_3;
    direct = (((max(dot(_e162, _e163), 0f) * _e168.w) * _e172) * smoothstep(0.5f, 0.95f, _e176.y));
    let _e191: vec3<f32> = toSun;
    sunColor = mix(vec3<f32>(1f, 0.46f, 0.18f), vec3<f32>(1f, 0.95f, 0.88f), vec3(smoothstep(0f, 0.42f, max(_e191.y, 0f))));
    let _e200: vec4<f32> = G.compatB;
    let _e202: f32 = direct;
    let _e204: vec3<f32> = sunColor;
    let _e207: vec4<f32> = G.compatB;
    let _e209: f32 = day;
    let _e211: vec3<f32> = nWorld_5;
    let _e212: vec3<f32> = shaderSkyAmbient(_e211);
    let _e214: vec2<f32> = bs_3;
    let _e217: vec2<f32> = bs_3;
    let _e221: vec3<f32> = rel_9;
    let _e222: vec3<f32> = nWorld_5;
    let _e223: vec2<f32> = bs_3;
    let _e225: vec3<f32> = shaderBlockLight(_e221, _e222, _e223.x);
    return (((((_e200.x * _e202) * _e204) + ((((_e207.y * _e209) * _e212) * _e214.y) * _e217.y)) + _e225) + vec3<f32>(0.01f, 0.012f, 0.018f));
}

fn unpackRgb(argb: i32) -> vec3<f32> {
    var argb_1: i32;

    argb_1 = argb;
    let _e132: i32 = argb_1;
    let _e138: i32 = argb_1;
    let _e144: i32 = argb_1;
    return (vec3<f32>(f32(((_e132 >> 16u) & 255i)), f32(((_e138 >> 8u) & 255i)), f32((_e144 & 255i))) / vec3(255f));
}

fn sandAverage() -> vec3<f32> {
    let _e132: i32 = global_1.sandTex[2];
    let _e133: vec3<f32> = unpackRgb(_e132);
    return _e133;
}

fn sandTexel(t_5: vec2<i32>) -> vec3<f32> {
    var t_6: vec2<i32>;
    var size_2: vec2<i32>;

    t_6 = t_5;
    let _e134: i32 = global_1.sandTex[0];
    let _e137: i32 = global_1.sandTex[1];
    size_2 = vec2<i32>(_e134, _e137);
    let _e140: vec2<i32> = t_6;
    let _e141: vec2<i32> = size_2;
    let _e143: vec2<i32> = size_2;
    let _e145: vec2<i32> = size_2;
    t_6 = (((_e140 % _e141) + _e143) % _e145);
    let _e148: vec2<i32> = t_6;
    let _e151: vec2<i32> = t_6;
    let _e153: vec2<i32> = size_2;
    let _e158: i32 = global_1.sandTex[((4i + _e148.x) + (_e151.y * _e153.x))];
    let _e159: vec3<f32> = unpackRgb(_e158);
    return _e159;
}

fn planarTexel(uv_1: vec2<f32>, texelsPerBlock: f32) -> vec3<f32> {
    var uv_2: vec2<f32>;
    var texelsPerBlock_1: f32;

    uv_2 = uv_1;
    texelsPerBlock_1 = texelsPerBlock;
    let _e134: vec2<f32> = uv_2;
    let _e135: f32 = texelsPerBlock_1;
    let _e139: vec3<f32> = sandTexel(vec2<i32>(floor((_e134 * _e135))));
    return _e139;
}

fn sandAlbedo(world_1: vec3<f32>, nWorld_6: vec3<f32>, footprint: f32) -> vec3<f32> {
    var world_2: vec3<f32>;
    var nWorld_7: vec3<f32>;
    var footprint_1: f32;
    var tpb: f32;
    var w_1: vec3<f32>;
    var c_9: vec3<f32>;
    var texel_1: f32;
    var detail: f32;

    world_2 = world_1;
    nWorld_7 = nWorld_6;
    footprint_1 = footprint;
    let _e138: i32 = global_1.sandTex[0];
    tpb = f32(_e138);
    let _e141: vec3<f32> = nWorld_7;
    w_1 = pow(abs(_e141), vec3(8f));
    let _e147: vec3<f32> = w_1;
    let _e148: vec3<f32> = w_1;
    let _e150: vec3<f32> = w_1;
    let _e153: vec3<f32> = w_1;
    w_1 = (_e147 / vec3(((_e148.x + _e150.y) + _e153.z)));
    let _e158: vec3<f32> = w_1;
    let _e160: vec3<f32> = world_2;
    let _e162: vec3<f32> = world_2;
    let _e165: f32 = tpb;
    let _e166: vec3<f32> = planarTexel(vec2<f32>(_e160.x, _e162.z), _e165);
    let _e168: vec3<f32> = w_1;
    let _e170: vec3<f32> = world_2;
    let _e172: vec3<f32> = world_2;
    let _e176: f32 = tpb;
    let _e177: vec3<f32> = planarTexel(vec2<f32>(_e170.z, -(_e172.y)), _e176);
    let _e180: vec3<f32> = w_1;
    let _e182: vec3<f32> = world_2;
    let _e184: vec3<f32> = world_2;
    let _e188: f32 = tpb;
    let _e189: vec3<f32> = planarTexel(vec2<f32>(_e182.x, -(_e184.y)), _e188);
    c_9 = (((_e158.y * _e166) + (_e168.x * _e177)) + (_e180.z * _e189));
    let _e194: f32 = tpb;
    texel_1 = (1f / _e194);
    let _e200: f32 = footprint_1;
    let _e201: f32 = texel_1;
    detail = (1f - smoothstep(0.5f, 1.5f, (_e200 / _e201)));
    let _e206: vec3<f32> = sandAverage();
    let _e207: vec3<f32> = c_9;
    let _e208: f32 = detail;
    return mix(_e206, _e207, vec3(_e208));
}

fn sandLight(nWorld_8: vec3<f32>, albedo: vec3<f32>, ao: f32, viewPos_4: vec3<f32>, bs_4: vec2<f32>) -> vec3<f32> {
    var nWorld_9: vec3<f32>;
    var albedo_1: vec3<f32>;
    var ao_1: f32;
    var viewPos_5: vec3<f32>;
    var bs_5: vec2<f32>;
    var n2_: vec3<f32>;
    var local_26: f32;
    var face: f32;
    var lightN: vec3<f32>;

    nWorld_9 = nWorld_8;
    albedo_1 = albedo;
    ao_1 = ao;
    viewPos_5 = viewPos_4;
    bs_5 = bs_4;
    let _e140: vec3<f32> = nWorld_9;
    let _e141: vec3<f32> = nWorld_9;
    n2_ = (_e140 * _e141);
    let _e144: vec3<f32> = n2_;
    let _e148: vec3<f32> = n2_;
    let _e153: vec3<f32> = n2_;
    let _e155: vec3<f32> = nWorld_9;
    if (_e155.y > 0f) {
        local_26 = 1f;
    } else {
        local_26 = 0.5f;
    }
    let _e162: f32 = local_26;
    face = (((_e144.x * 0.6f) + (_e148.z * 0.8f)) + (_e153.y * _e162));
    let _e167: vec4<f32> = G.compat;
    if (_e167.y <= 1f) {
        {
            let _e171: vec3<f32> = albedo_1;
            let _e172: f32 = face;
            let _e174: vec2<f32> = bs_5;
            let _e175: vec3<f32> = vanillaLight(_e174);
            let _e177: f32 = ao_1;
            let _e180: vec4<f32> = G.matD;
            return min(((((_e171 * _e172) * _e175) * _e177) * _e180.y), vec3(1f));
        }
    }
    let _e186: vec3<f32> = nWorld_9;
    lightN = normalize((_e186 + vec3<f32>(0f, 1f, 0f)));
    let _e194: vec3<f32> = albedo_1;
    let _e195: f32 = ao_1;
    let _e198: vec4<f32> = G.matD;
    let _e202: mat4x4<f32> = G.invView;
    let _e212: vec3<f32> = viewPos_5;
    let _e214: vec3<f32> = viewPos_5;
    let _e215: vec3<f32> = lightN;
    let _e216: vec2<f32> = bs_5;
    let _e217: vec3<f32> = shaderSurfaceLight((mat3x3<f32>(_e202[0].xyz, _e202[1].xyz, _e202[2].xyz) * _e212), _e214, _e215, _e216);
    return (((_e194 * _e195) * _e198.y) * _e217);
}

fn main_1() {
    var r2_: f32;
    var pos: vec3<f32>;
    var clip_1: vec4<f32>;
    var s: u32;
    var nWorld_10: vec3<f32>;
    var albedo_2: vec3<f32>;
    var bs_6: vec2<f32>;

    let _e130: vec2<f32> = vUV_1;
    let _e131: vec2<f32> = vUV_1;
    r2_ = dot(_e130, _e131);
    let _e134: f32 = r2_;
    if (_e134 > 1f) {
        {
            discard;
        }
    }
    let _e137: vec3<f32> = vCenter_1;
    let _e138: vec2<f32> = vUV_1;
    let _e140: f32 = r2_;
    let _e146: f32 = vRadius_1;
    pos = (_e137 + (vec3<f32>(_e138.x, _e138.y, sqrt((1f - _e140))) * _e146));
    let _e151: mat4x4<f32> = G.proj;
    let _e152: vec3<f32> = pos;
    clip_1 = (_e151 * vec4<f32>(_e152.x, _e152.y, _e152.z, 1f));
    let _e161: vec4<f32> = clip_1;
    let _e163: vec4<f32> = clip_1;
    gl_FragDepth = (_e161.z / _e163.w);
    let _e166: u32 = vSeed_1;
    s = _e166;
    let _e169: mat4x4<f32> = G.invView;
    let _e179: vec3<f32> = vNormal_1;
    nWorld_10 = normalize((mat3x3<f32>(_e169[0].xyz, _e169[1].xyz, _e169[2].xyz) * _e179));
    let _e183: vec3<f32> = vWorld_1;
    let _e184: vec3<f32> = nWorld_10;
    let _e186: vec3<f32> = sandAlbedo(_e183, _e184, 0f);
    let _e191: f32 = rand((&s));
    albedo_2 = (_e186 * (0.92f + (0.2f * _e191)));
    let _e197: mat4x4<f32> = G.invView;
    let _e207: vec3<f32> = pos;
    let _e214: vec3<f32> = relToSim(((mat3x3<f32>(_e197[0].xyz, _e197[1].xyz, _e197[2].xyz) * _e207) + vec3<f32>(0f, 0.5f, 0f)));
    let _e215: vec2<f32> = regionLightAt(_e214);
    bs_6 = _e215;
    let _e217: vec3<f32> = nWorld_10;
    let _e218: vec3<f32> = albedo_2;
    let _e219: f32 = vShade_1;
    let _e220: vec3<f32> = pos;
    let _e221: vec2<f32> = bs_6;
    let _e222: vec3<f32> = sandLight(_e217, _e218, _e219, _e220, _e221);
    outColor = vec4<f32>(_e222.x, _e222.y, _e222.z, 1f);
    return;
}

@fragment
fn main(@location(0) vUV: vec2<f32>, @location(1) vCenter: vec3<f32>, @location(2) vRadius: f32, @location(3) @interpolate(flat) vSeed: u32, @location(4) @interpolate(flat) vWorld: vec3<f32>, @location(5) @interpolate(flat) vNormal: vec3<f32>, @location(6) @interpolate(flat) vShade: f32) -> FragmentOutput {
    vUV_1 = vUV;
    vCenter_1 = vCenter;
    vRadius_1 = vRadius;
    vSeed_1 = vSeed;
    vWorld_1 = vWorld;
    vNormal_1 = vNormal;
    vShade_1 = vShade;
    main_1();
    let _e164: vec4<f32> = outColor;
    let _e166: f32 = gl_FragDepth;
    return FragmentOutput(_e164, _e166);
}
