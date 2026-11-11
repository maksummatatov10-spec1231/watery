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

struct ViewState {
    viewState: vec4<f32>,
}

struct SlimeTex {
    slimeTex: array<i32>,
}

struct Push {
    filterMat: f32,
}

struct FragmentOutput {
    @location(0) outColor: vec4<f32>,
    @builtin(frag_depth) gl_FragDepth: f32,
}

const FP_SCALE: f32 = 65536f;
const PI: f32 = 3.1415927f;
const RIPPLE_DIR: array<vec2<f32>, 5> = array<vec2<f32>, 5>(vec2<f32>(0.94f, 0.34f), vec2<f32>(-0.42f, 0.91f), vec2<f32>(0.71f, -0.7f), vec2<f32>(-0.86f, -0.51f), vec2<f32>(0.21f, 0.98f));
const RIPPLE_FREQ: array<f32, 5> = array<f32, 5>(1f, 1.93f, 3.57f, 6.41f, 11.7f);
const RIPPLE_WEIGHT: array<f32, 5> = array<f32, 5>(0.357f, 0.25f, 0.179f, 0.125f, 0.089f);
const ETA: f32 = 1.333f;

@group(0) @binding(0)
var<uniform> G: Globals;
@group(0) @binding(1)
var gbuffer_texture: texture_2d<f32>;
@group(2) @binding(1)
var gbuffer_sampler: sampler;
@group(0) @binding(2)
var thicknessTex_texture: texture_2d<f32>;
@group(2) @binding(2)
var thicknessTex_sampler: sampler;
@group(0) @binding(3)
var sceneColor_texture: texture_2d<f32>;
@group(2) @binding(3)
var sceneColor_sampler: sampler;
@group(0) @binding(4)
var sceneDepth_texture: texture_2d<f32>;
@group(2) @binding(4)
var sceneDepth_sampler: sampler;
@group(0) @binding(5)
var foamTex_texture: texture_2d<f32>;
@group(2) @binding(5)
var foamTex_sampler: sampler;
@group(0) @binding(6)
var materialTex_texture: texture_2d<f32>;
@group(2) @binding(6)
var materialTex_sampler: sampler;
@group(0) @binding(7)
var<storage> global: ViewState;
@group(0) @binding(8)
var shadowTex_texture: texture_2d<f32>;
@group(2) @binding(8)
var shadowTex_sampler: sampler;
@group(0) @binding(9)
var<storage> global_1: SlimeTex;
@group(0) @binding(10)
var lightmapTex_texture: texture_2d<f32>;
@group(2) @binding(10)
var lightmapTex_sampler: sampler;
@group(0) @binding(11)
var skLightA_texture: texture_2d<f32>;
@group(2) @binding(11)
var skLightA_sampler: sampler;
@group(0) @binding(12)
var skLightB_texture: texture_2d<f32>;
@group(2) @binding(12)
var skLightB_sampler: sampler;
@group(0) @binding(13)
var skLightTint_texture: texture_2d<f32>;
@group(2) @binding(13)
var skLightTint_sampler: sampler;
@group(1) @binding(0)
var<uniform> pc: Push;
var<private> outColor: vec4<f32>;
var<private> gl_FragCoord_1: vec4<f32>;
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
    let _e127: vec4<f32> = G.compat;
    if (_e127.w < 0.5f) {
        {
            return 1f;
        }
    }
    let _e133: mat4x4<f32> = G.invView;
    let _e143: vec3<f32> = viewPos_1;
    relative = (mat3x3<f32>(_e133[0].xyz, _e133[1].xyz, _e133[2].xyz) * _e143);
    let _e149: mat4x4<f32> = G.shadowNear;
    let _e150: vec3<f32> = relative;
    clip = (_e149 * vec4<f32>(_e150.x, _e150.y, _e150.z, 1f));
    let _e158: vec4<f32> = clip;
    let _e161: vec4<f32> = clip;
    if (max(abs(_e158.x), abs(_e161.y)) >= 0.94f) {
        {
            cascade = 1i;
            let _e169: mat4x4<f32> = G.shadowMid;
            let _e170: vec3<f32> = relative;
            clip = (_e169 * vec4<f32>(_e170.x, _e170.y, _e170.z, 1f));
            let _e177: vec4<f32> = clip;
            let _e180: vec4<f32> = clip;
            if (max(abs(_e177.x), abs(_e180.y)) >= 0.94f) {
                {
                    cascade = 2i;
                    let _e188: mat4x4<f32> = G.shadowFar;
                    let _e189: vec3<f32> = relative;
                    clip = (_e188 * vec4<f32>(_e189.x, _e189.y, _e189.z, 1f));
                    let _e196: vec4<f32> = clip;
                    let _e199: vec4<f32> = clip;
                    if (max(abs(_e196.x), abs(_e199.y)) > 1f) {
                        {
                            return 1f;
                        }
                    }
                }
            }
        }
    }
    let _e206: vec4<f32> = clip;
    xy = _e206.xy;
    let _e209: vec2<f32> = xy;
    let _e217: i32 = cascade;
    let _e221: i32 = cascade;
    uv = ((((_e209 * 0.5f) + vec2(0.5f)) * 0.5f) + (vec2<f32>(f32((_e217 % 2i)), f32((_e221 / 2i))) * 0.5f));
    let _e232: vec2<u32> = textureDimensions(shadowTex_texture, 0i);
    texel = (1f / f32(vec2<i32>(_e232).x));
    loop {
        let _e242: i32 = k;
        if !((_e242 < 4i)) {
            break;
        }
        {
            let _e249: i32 = k;
            let _e253: i32 = k;
            let _e262: f32 = texel;
            o = ((vec2<f32>(f32((_e249 & 1i)), f32((_e253 >> 1u))) - vec2(0.5f)) * _e262);
            let _e265: f32 = lit;
            let _e266: vec2<f32> = uv;
            let _e267: vec2<f32> = o;
            let _e269: vec4<f32> = textureSample(shadowTex_texture, shadowTex_sampler, (_e266 + _e267));
            let _e271: vec4<f32> = clip;
            let _e274: vec4<f32> = G.compatB;
            if (_e269.x >= (_e271.z - _e274.z)) {
                local_20 = 1f;
            } else {
                local_20 = 0f;
            }
            let _e281: f32 = local_20;
            lit = (_e265 + _e281);
        }
        continuing {
            let _e246: i32 = k;
            k = (_e246 + 1i);
        }
    }
    let _e283: f32 = lit;
    return (_e283 * 0.25f);
}

fn vanillaLight(bs: vec2<f32>) -> vec3<f32> {
    var bs_1: vec2<f32>;

    bs_1 = bs;
    let _e136: vec2<f32> = bs_1;
    let _e150: vec4<f32> = textureSample(lightmapTex_texture, lightmapTex_sampler, (((clamp(_e136, vec2(0f), vec2(1f)) * 15f) + vec2(0.5f)) / vec2(16f)));
    return _e150.xyz;
}

fn blockCurve(level: f32) -> f32 {
    var level_1: f32;

    level_1 = level;
    let _e136: f32 = level_1;
    let _e141: f32 = level_1;
    return ((pow(_e136, 3f) * 0.9f) + (pow(_e141, 8f) * 0.6f));
}

fn shaderSkyAmbient(nWorld: vec3<f32>) -> vec3<f32> {
    var nWorld_1: vec3<f32>;
    var sky: vec3<f32>;
    var luma: f32;

    nWorld_1 = nWorld;
    let _e137: vec4<f32> = G.fogColor;
    let _e142: vec4<f32> = G.skyColor;
    let _e146: vec3<f32> = nWorld_1;
    sky = mix((_e137.xyz * 0.75f), (_e142.xyz * 1.1f), vec3(((_e146.y * 0.5f) + 0.5f)));
    let _e155: vec3<f32> = sky;
    luma = dot(_e155, vec3<f32>(0.2126f, 0.7152f, 0.0722f));
    let _e162: f32 = luma;
    let _e164: vec3<f32> = sky;
    return mix(vec3(_e162), _e164, vec3(0.45f));
}

fn inColorVolume(rel: vec3<f32>) -> bool {
    var rel_1: vec3<f32>;
    var range: i32;
    var local_21: vec3<f32>;
    var size: vec3<f32>;

    rel_1 = rel;
    let _e137: vec4<f32> = G.lightA;
    range = i32(_e137.w);
    let _e142: vec4<f32> = G.lightC;
    let _e146: i32 = range;
    if ((_e142.z < 0.5f) || (_e146 <= 0i)) {
        {
            return false;
        }
    }
    let _e151: vec3<f32> = rel_1;
    let _e153: vec4<f32> = G.lightA;
    local_21 = (_e151 - _e153.xyz);
    let _e157: i32 = range;
    let _e159: i32 = range;
    let _e163: i32 = range;
    size = vec3<f32>(f32(_e157), f32((_e159 / 2i)), f32(_e163));
    let _e167: vec3<f32> = local_21;
    let _e172: vec3<f32> = local_21;
    let _e173: vec3<f32> = size;
    return (all((_e167 >= vec3(0.5f))) && all((_e172 <= (_e173 - vec3(0.5f)))));
}

fn colorLightUv(slice: i32, xz: vec2<f32>) -> vec2<f32> {
    var slice_1: i32;
    var xz_1: vec2<f32>;
    var range_1: i32;
    var columns: i32;
    var local_22: vec2<f32>;
    var corner: vec2<f32>;

    slice_1 = slice;
    xz_1 = xz;
    let _e139: vec4<f32> = G.lightA;
    range_1 = i32(_e139.w);
    let _e144: vec4<f32> = G.lightB;
    columns = max(i32(_e144.w), 1i);
    let _e150: vec2<f32> = xz_1;
    let _e153: vec2<f32> = (_e150 - vec2(0.5f));
    let _e154: i32 = range_1;
    let _e156: vec2<f32> = vec2(f32(_e154));
    local_22 = (_e153 - (floor((_e153 / _e156)) * _e156));
    let _e162: i32 = slice_1;
    let _e163: i32 = columns;
    let _e166: i32 = slice_1;
    let _e167: i32 = columns;
    let _e171: i32 = range_1;
    corner = (vec2<f32>(f32((_e162 % _e163)), f32((_e166 / _e167))) * f32((_e171 + 2i)));
    let _e177: vec2<f32> = corner;
    let _e181: vec2<f32> = local_22;
    let _e184: vec4<f32> = G.lightC;
    return (((_e177 + vec2(1.5f)) + _e181) / _e184.xy);
}

fn colorLightAt(rel_2: vec3<f32>, typed: ptr<function, f32>) -> vec3<f32> {
    var rel_3: vec3<f32>;
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
    var local_23: vec3<f32>;
    var size_1: vec3<f32>;
    var edge: vec3<f32>;
    var scale: f32;
    var a: vec4<f32>;
    var b: vec4<f32>;
    var m: vec4<f32>;
    var light: vec3<f32>;

    rel_3 = rel_2;
    (*typed) = 0f;
    let _e139: vec4<f32> = G.lightA;
    range_2 = i32(_e139.w);
    let _e143: i32 = range_2;
    height = (_e143 / 2i);
    let _e147: vec3<f32> = rel_3;
    let _e149: vec4<f32> = G.lightB;
    world = (_e147 + _e149.xyz);
    let _e153: vec3<f32> = world;
    let _e156: f32 = (_e153.y - 0.5f);
    let _e157: i32 = height;
    let _e158: f32 = f32(_e157);
    y = (_e156 - (floor((_e156 / _e158)) * _e158));
    let _e164: f32 = y;
    y0_ = i32(floor(_e164));
    let _e168: i32 = y0_;
    let _e171: i32 = height;
    y1_ = ((_e168 + 1i) % _e171);
    let _e174: f32 = y;
    let _e175: f32 = y;
    fy = (_e174 - floor(_e175));
    let _e179: i32 = y0_;
    let _e180: vec3<f32> = world;
    let _e182: vec2<f32> = colorLightUv(_e179, _e180.xz);
    uv0_ = _e182;
    let _e184: i32 = y1_;
    let _e185: vec3<f32> = world;
    let _e187: vec2<f32> = colorLightUv(_e184, _e185.xz);
    uv1_ = _e187;
    let _e189: vec2<f32> = uv0_;
    let _e191: vec4<f32> = textureSampleLevel(skLightTint_texture, skLightTint_sampler, _e189, 0f);
    let _e192: vec2<f32> = uv1_;
    let _e194: vec4<f32> = textureSampleLevel(skLightTint_texture, skLightTint_sampler, _e192, 0f);
    let _e195: f32 = fy;
    t_4 = mix(_e191, _e194, vec4(_e195));
    let _e199: vec4<f32> = t_4;
    if (_e199.w < 0.001f) {
        {
            return vec3(0f);
        }
    }
    let _e205: vec3<f32> = rel_3;
    let _e207: vec4<f32> = G.lightA;
    local_23 = (_e205 - _e207.xyz);
    let _e211: i32 = range_2;
    let _e213: i32 = height;
    let _e215: i32 = range_2;
    size_1 = vec3<f32>(f32(_e211), f32(_e213), f32(_e215));
    let _e219: vec3<f32> = local_23;
    let _e220: vec3<f32> = size_1;
    let _e221: vec3<f32> = local_23;
    edge = min(_e219, (_e220 - _e221));
    let _e225: vec3<f32> = edge;
    let _e227: vec3<f32> = edge;
    let _e229: vec3<f32> = edge;
    let _e240: vec4<f32> = t_4;
    scale = (clamp(((min(_e225.x, min(_e227.y, _e229.z)) / 6f) - 0.1f), 0f, 1f) / _e240.w);
    let _e244: vec2<f32> = uv0_;
    let _e246: vec4<f32> = textureSampleLevel(skLightA_texture, skLightA_sampler, _e244, 0f);
    let _e247: vec2<f32> = uv1_;
    let _e249: vec4<f32> = textureSampleLevel(skLightA_texture, skLightA_sampler, _e247, 0f);
    let _e250: f32 = fy;
    let _e253: f32 = scale;
    a = (mix(_e246, _e249, vec4(_e250)) * _e253);
    let _e256: vec2<f32> = uv0_;
    let _e258: vec4<f32> = textureSampleLevel(skLightB_texture, skLightB_sampler, _e256, 0f);
    let _e259: vec2<f32> = uv1_;
    let _e261: vec4<f32> = textureSampleLevel(skLightB_texture, skLightB_sampler, _e259, 0f);
    let _e262: f32 = fy;
    let _e265: f32 = scale;
    b = (mix(_e258, _e261, vec4(_e262)) * _e265);
    let _e268: vec4<f32> = a;
    let _e269: vec4<f32> = b;
    m = max(_e268, _e269);
    let _e272: vec4<f32> = m;
    let _e274: vec4<f32> = m;
    let _e277: vec4<f32> = m;
    let _e279: vec4<f32> = m;
    (*typed) = max(max(_e272.x, _e274.y), max(_e277.z, _e279.w));
    let _e283: vec4<f32> = a;
    let _e288: vec4<f32> = G.lightColors[0];
    let _e291: vec4<f32> = a;
    let _e296: vec4<f32> = G.lightColors[1];
    let _e300: vec4<f32> = a;
    let _e305: vec4<f32> = G.lightColors[2];
    let _e309: vec4<f32> = a;
    let _e314: vec4<f32> = G.lightColors[3];
    let _e318: vec4<f32> = b;
    let _e323: vec4<f32> = G.lightColors[4];
    let _e327: vec4<f32> = b;
    let _e332: vec4<f32> = G.lightColors[5];
    let _e336: vec4<f32> = b;
    let _e341: vec4<f32> = G.lightColors[6];
    let _e345: vec4<f32> = b;
    let _e350: vec4<f32> = G.lightColors[7];
    light = ((((((((_e283.x * _e288.xyz) + (_e291.y * _e296.xyz)) + (_e300.z * _e305.xyz)) + (_e309.w * _e314.xyz)) + (_e318.x * _e323.xyz)) + (_e327.y * _e332.xyz)) + (_e336.z * _e341.xyz)) + (_e345.w * _e350.xyz));
    let _e355: vec3<f32> = light;
    let _e356: vec4<f32> = t_4;
    let _e359: vec4<f32> = t_4;
    return ((_e355 * _e356.xyz) / vec3(_e359.w));
}

fn shaderBlockLight(rel_4: vec3<f32>, nWorld_2: vec3<f32>, level_2: f32) -> vec3<f32> {
    var rel_5: vec3<f32>;
    var nWorld_3: vec3<f32>;
    var level_3: f32;
    var torch: vec3<f32> = vec3<f32>(1.4f, 0.84000003f, 0.42000002f);
    var vanilla: vec3<f32>;
    var at: vec3<f32>;
    var typed_1: f32;
    var colored: vec3<f32>;
    var local_24: vec3<f32>;
    var shaped: vec3<f32>;
    var rest: vec3<f32>;

    rel_5 = rel_4;
    nWorld_3 = nWorld_2;
    level_3 = level_2;
    let _e151: vec3<f32> = torch;
    let _e152: f32 = level_3;
    let _e153: f32 = blockCurve(_e152);
    vanilla = (_e151 * _e153);
    let _e156: vec3<f32> = rel_5;
    let _e157: vec3<f32> = nWorld_3;
    at = (_e156 + (_e157 * 0.5f));
    let _e162: vec3<f32> = at;
    let _e163: bool = inColorVolume(_e162);
    if !(_e163) {
        {
            let _e165: vec3<f32> = vanilla;
            return _e165;
        }
    }
    let _e167: vec3<f32> = at;
    let _e170: vec3<f32> = colorLightAt(_e167, (&typed_1));
    colored = _e170;
    let _e172: f32 = typed_1;
    if (_e172 > 0.0001f) {
        let _e175: vec3<f32> = colored;
        let _e176: f32 = typed_1;
        let _e179: f32 = typed_1;
        let _e182: f32 = blockCurve(min(_e179, 1f));
        local_24 = (((_e175 / vec3(_e176)) * _e182) * 1.4f);
    } else {
        local_24 = vec3(0f);
    }
    let _e189: vec3<f32> = local_24;
    shaped = _e189;
    let _e191: vec3<f32> = torch;
    let _e192: f32 = level_3;
    let _e193: f32 = blockCurve(_e192);
    let _e194: f32 = typed_1;
    let _e201: f32 = blockCurve(min((_e194 + 0.06666667f), 1f));
    rest = (_e191 * max((_e193 - _e201), 0f));
    let _e207: vec3<f32> = shaped;
    let _e208: vec3<f32> = rest;
    return (_e207 + _e208);
}

fn shaderSurfaceLight(rel_6: vec3<f32>, viewPos_2: vec3<f32>, nWorld_4: vec3<f32>, bs_2: vec2<f32>) -> vec3<f32> {
    var rel_7: vec3<f32>;
    var viewPos_3: vec3<f32>;
    var nWorld_5: vec3<f32>;
    var bs_3: vec2<f32>;
    var toSun: vec3<f32>;
    var day: f32;
    var direct: f32;
    var sunColor: vec3<f32>;

    rel_7 = rel_6;
    viewPos_3 = viewPos_2;
    nWorld_5 = nWorld_4;
    bs_3 = bs_2;
    let _e143: mat4x4<f32> = G.invView;
    let _e154: vec4<f32> = G.sunDir;
    toSun = normalize((mat3x3<f32>(_e143[0].xyz, _e143[1].xyz, _e143[2].xyz) * _e154.xyz));
    let _e160: vec4<f32> = G.skyColor;
    day = clamp((_e160.w / 0.85f), 0.2f, 1f);
    let _e168: vec3<f32> = nWorld_5;
    let _e169: vec3<f32> = toSun;
    let _e174: vec4<f32> = G.sunDir;
    let _e177: vec3<f32> = viewPos_3;
    let _e178: f32 = sunLit(_e177);
    let _e182: vec2<f32> = bs_3;
    direct = (((max(dot(_e168, _e169), 0f) * _e174.w) * _e178) * smoothstep(0.5f, 0.95f, _e182.y));
    let _e197: vec3<f32> = toSun;
    sunColor = mix(vec3<f32>(1f, 0.46f, 0.18f), vec3<f32>(1f, 0.95f, 0.88f), vec3(smoothstep(0f, 0.42f, max(_e197.y, 0f))));
    let _e206: vec4<f32> = G.compatB;
    let _e208: f32 = direct;
    let _e210: vec3<f32> = sunColor;
    let _e213: vec4<f32> = G.compatB;
    let _e215: f32 = day;
    let _e217: vec3<f32> = nWorld_5;
    let _e218: vec3<f32> = shaderSkyAmbient(_e217);
    let _e220: vec2<f32> = bs_3;
    let _e223: vec2<f32> = bs_3;
    let _e227: vec3<f32> = rel_7;
    let _e228: vec3<f32> = nWorld_5;
    let _e229: vec2<f32> = bs_3;
    let _e231: vec3<f32> = shaderBlockLight(_e227, _e228, _e229.x);
    return (((((_e206.x * _e208) * _e210) + ((((_e213.y * _e215) * _e218) * _e220.y) * _e223.y)) + _e231) + vec3<f32>(0.01f, 0.012f, 0.018f));
}

fn linearDepth(device: f32) -> f32 {
    var device_1: f32;
    var v_4: vec4<f32>;

    device_1 = device;
    let _e142: mat4x4<f32> = G.invProj;
    let _e145: f32 = device_1;
    v_4 = (_e142 * vec4<f32>(0f, 0f, _e145, 1f));
    let _e150: vec4<f32> = v_4;
    let _e153: vec4<f32> = v_4;
    return (-(_e150.z) / _e153.w);
}

fn viewPosAt(uv_1: vec2<f32>, dist: f32) -> vec3<f32> {
    var uv_2: vec2<f32>;
    var dist_1: f32;
    var v_5: vec4<f32>;
    var dir: vec3<f32>;

    uv_2 = uv_1;
    dist_1 = dist;
    let _e144: mat4x4<f32> = G.invProj;
    let _e145: vec2<f32> = uv_2;
    let _e150: vec2<f32> = ((_e145 * 2f) - vec2(1f));
    v_5 = (_e144 * vec4<f32>(_e150.x, _e150.y, 0.5f, 1f));
    let _e158: vec4<f32> = v_5;
    let _e160: vec4<f32> = v_5;
    dir = (_e158.xyz / vec3(_e160.w));
    let _e165: vec3<f32> = dir;
    let _e166: f32 = dist_1;
    let _e167: vec3<f32> = dir;
    return (_e165 * (_e166 / -(_e167.z)));
}

fn pixelFootprint(dist_2: f32) -> f32 {
    var dist_3: f32;

    dist_3 = dist_2;
    let _e142: f32 = dist_3;
    let _e149: f32 = G.proj[1][1];
    let _e151: vec4<f32> = G.screen;
    return ((2f * _e142) / max((_e149 * _e151.y), 0.0001f));
}

fn skyColor(dirWorld: vec3<f32>) -> vec3<f32> {
    var dirWorld_1: vec3<f32>;
    var t_5: f32;
    var horizon: vec3<f32>;
    var zenith: vec3<f32>;

    dirWorld_1 = dirWorld;
    let _e141: vec3<f32> = dirWorld_1;
    t_5 = _e141.y;
    let _e145: vec4<f32> = G.fogColor;
    horizon = _e145.xyz;
    let _e149: vec4<f32> = G.skyColor;
    zenith = _e149.xyz;
    let _e152: f32 = t_5;
    if (_e152 >= 0f) {
        {
            let _e155: vec3<f32> = horizon;
            let _e156: vec3<f32> = zenith;
            let _e159: f32 = t_5;
            return mix(_e155, _e156, vec3(smoothstep(0f, 0.45f, _e159)));
        }
    }
    let _e163: vec3<f32> = horizon;
    let _e168: f32 = t_5;
    return (_e163 * mix(0.9f, 0.35f, smoothstep(0f, 0.35f, -(_e168))));
}

fn reflectedSky(Rv: vec3<f32>, Rw: vec3<f32>) -> vec3<f32> {
    var Rv_1: vec3<f32>;
    var Rw_1: vec3<f32>;
    var sky_1: vec3<f32>;
    var clip_1: vec4<f32>;
    var suv: vec2<f32>;
    var edge_1: vec2<f32>;

    Rv_1 = Rv;
    Rw_1 = Rw;
    let _e143: vec3<f32> = Rw_1;
    let _e144: vec3<f32> = skyColor(_e143);
    let _e146: vec4<f32> = G.compat;
    sky_1 = (_e144 * _e146.y);
    let _e151: vec4<f32> = G.compat;
    if (_e151.x < 1.5f) {
        {
            let _e155: vec3<f32> = sky_1;
            return _e155;
        }
    }
    let _e157: mat4x4<f32> = G.proj;
    let _e158: vec3<f32> = Rv_1;
    let _e160: vec3<f32> = (_e158 * 1000f);
    clip_1 = (_e157 * vec4<f32>(_e160.x, _e160.y, _e160.z, 1f));
    let _e168: vec4<f32> = clip_1;
    if (_e168.w <= 0f) {
        {
            let _e172: vec3<f32> = sky_1;
            return _e172;
        }
    }
    let _e173: vec4<f32> = clip_1;
    let _e175: vec4<f32> = clip_1;
    suv = (((_e173.xy / vec2(_e175.w)) * 0.5f) + vec2(0.5f));
    let _e185: vec2<f32> = suv;
    let _e190: vec2<f32> = suv;
    let _e196: vec2<f32> = suv;
    let _e197: vec4<f32> = textureSample(sceneDepth_texture, sceneDepth_sampler, _e196);
    if ((any((_e185 < vec2(0f))) || any((_e190 > vec2(1f)))) || (_e197.x > 0f)) {
        {
            let _e202: vec3<f32> = sky_1;
            return _e202;
        }
    }
    let _e207: vec2<f32> = suv;
    let _e214: vec2<f32> = suv;
    edge_1 = (smoothstep(vec2(0f), vec2(0.1f), _e207) * (vec2(1f) - smoothstep(vec2(0.9f), vec2(1f), _e214)));
    let _e220: vec3<f32> = sky_1;
    let _e221: vec2<f32> = suv;
    let _e222: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e221);
    let _e224: vec2<f32> = edge_1;
    let _e226: vec2<f32> = edge_1;
    return mix(_e220, _e222.xyz, vec3((_e224.x * _e226.y)));
}

fn traceReflection(origin: vec3<f32>, R: vec3<f32>, hit: ptr<function, f32>) -> vec3<f32> {
    var origin_1: vec3<f32>;
    var R_1: vec3<f32>;
    var pos: vec3<f32>;
    var stepLen: f32 = 0.15f;
    var i_5: i32 = 0i;
    var clip_2: vec4<f32>;
    var suv_1: vec2<f32>;
    var sceneDist: f32;
    var rayDist: f32;
    var edge_2: vec2<f32>;

    origin_1 = origin;
    R_1 = R;
    (*hit) = 0f;
    let _e145: vec3<f32> = origin_1;
    pos = _e145;
    loop {
        let _e151: i32 = i_5;
        if !((_e151 < 48i)) {
            break;
        }
        {
            let _e158: vec3<f32> = pos;
            let _e159: vec3<f32> = R_1;
            let _e160: f32 = stepLen;
            pos = (_e158 + (_e159 * _e160));
            let _e163: f32 = stepLen;
            stepLen = (_e163 * 1.1f);
            let _e167: mat4x4<f32> = G.proj;
            let _e168: vec3<f32> = pos;
            clip_2 = (_e167 * vec4<f32>(_e168.x, _e168.y, _e168.z, 1f));
            let _e176: vec4<f32> = clip_2;
            if (_e176.w <= 0f) {
                {
                    break;
                }
            }
            let _e180: vec4<f32> = clip_2;
            let _e182: vec4<f32> = clip_2;
            suv_1 = (((_e180.xy / vec2(_e182.w)) * 0.5f) + vec2(0.5f));
            let _e192: vec2<f32> = suv_1;
            let _e197: vec2<f32> = suv_1;
            if (any((_e192 < vec2(0f))) || any((_e197 > vec2(1f)))) {
                {
                    break;
                }
            }
            let _e203: vec2<f32> = suv_1;
            let _e204: vec4<f32> = textureSample(sceneDepth_texture, sceneDepth_sampler, _e203);
            let _e206: f32 = linearDepth(_e204.x);
            sceneDist = _e206;
            let _e208: vec3<f32> = pos;
            rayDist = -(_e208.z);
            let _e212: f32 = rayDist;
            let _e213: f32 = sceneDist;
            let _e215: f32 = rayDist;
            let _e216: f32 = sceneDist;
            let _e218: f32 = stepLen;
            if ((_e212 > _e213) && ((_e215 - _e216) < ((_e218 * 2f) + 0.25f))) {
                {
                    let _e229: vec2<f32> = suv_1;
                    let _e236: vec2<f32> = suv_1;
                    edge_2 = (smoothstep(vec2(0f), vec2(0.08f), _e229) * (vec2(1f) - smoothstep(vec2(0.92f), vec2(1f), _e236)));
                    let _e242: vec2<f32> = edge_2;
                    let _e244: vec2<f32> = edge_2;
                    (*hit) = (_e242.x * _e244.y);
                    let _e247: vec2<f32> = suv_1;
                    let _e248: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e247);
                    return _e248.xyz;
                }
            }
        }
        continuing {
            let _e155: i32 = i_5;
            i_5 = (_e155 + 1i);
        }
    }
    return vec3(0f);
}

fn rippleGradient(p_7: vec2<f32>, t_6: f32, footprint: f32) -> vec2<f32> {
    var p_8: vec2<f32>;
    var t_7: f32;
    var footprint_1: f32;
    var g: vec2<f32> = vec2(0f);
    var q_1: vec2<f32>;
    var i_6: i32 = 0i;
    var local_25: array<f32, 5> = RIPPLE_FREQ;
    var lambda: f32;
    var fade: f32;
    var local_26: array<vec2<f32>, 5> = RIPPLE_DIR;
    var local_27: array<f32, 5> = RIPPLE_FREQ;
    var phase: f32;
    var local_28: array<vec2<f32>, 5> = RIPPLE_DIR;
    var local_29: array<f32, 5> = RIPPLE_WEIGHT;
    var local_30: array<vec2<f32>, 5> = RIPPLE_DIR;
    var local_31: array<f32, 5> = RIPPLE_WEIGHT;
    var local_32: array<f32, 5> = RIPPLE_FREQ;

    p_8 = p_7;
    t_7 = t_6;
    footprint_1 = footprint;
    let _e151: vec2<f32> = p_8;
    q_1 = _e151;
    loop {
        let _e155: i32 = i_6;
        if !((_e155 < 5i)) {
            break;
        }
        {
            let _e163: i32 = i_6;
            let _e167: f32 = local_25[_e163];
            lambda = (6.2831855f / _e167);
            let _e172: f32 = lambda;
            let _e173: f32 = footprint_1;
            fade = smoothstep(1.5f, 4f, (_e172 / max(_e173, 0.00001f)));
            let _e179: f32 = fade;
            if (_e179 <= 0f) {
                {
                    break;
                }
            }
            let _e182: vec2<f32> = q_1;
            let _e183: i32 = i_6;
            let _e187: vec2<f32> = local_26[_e183];
            let _e189: i32 = i_6;
            let _e193: f32 = local_27[_e189];
            let _e195: f32 = t_7;
            let _e198: i32 = i_6;
            phase = ((dot(_e182, _e187) * _e193) + (_e195 * (0.8f + (0.3f * f32(_e198)))));
            let _e205: vec2<f32> = g;
            let _e206: i32 = i_6;
            let _e210: vec2<f32> = local_28[_e206];
            let _e211: i32 = i_6;
            let _e215: f32 = local_29[_e211];
            let _e216: f32 = fade;
            let _e218: f32 = phase;
            g = (_e205 + (_e210 * ((_e215 * _e216) * cos(_e218))));
            let _e223: vec2<f32> = q_1;
            let _e224: i32 = i_6;
            let _e228: vec2<f32> = local_30[_e224];
            let _e230: i32 = i_6;
            let _e234: f32 = local_31[_e230];
            let _e235: i32 = i_6;
            let _e239: f32 = local_32[_e235];
            let _e241: f32 = phase;
            q_1 = (_e223 + (_e228.yx * (((_e234 / _e239) * sin(_e241)) * 0.6f)));
        }
        continuing {
            let _e159: i32 = i_6;
            i_6 = (_e159 + 1i);
        }
    }
    let _e248: vec2<f32> = g;
    return _e248;
}

fn rippleNormal(nView: vec3<f32>, viewPos_4: vec3<f32>, footprint_2: f32) -> vec3<f32> {
    var nView_1: vec3<f32>;
    var viewPos_5: vec3<f32>;
    var footprint_3: f32;
    var nWorld_6: vec3<f32>;
    var world_1: vec3<f32>;
    var scale_1: f32;
    var grad: vec2<f32>;
    var g_1: vec3<f32>;

    nView_1 = nView;
    viewPos_5 = viewPos_4;
    footprint_3 = footprint_2;
    let _e149: vec4<f32> = G.shadeA;
    if (_e149.x <= 0f) {
        {
            let _e153: vec3<f32> = nView_1;
            return _e153;
        }
    }
    let _e155: mat4x4<f32> = G.invView;
    let _e165: vec3<f32> = nView_1;
    nWorld_6 = normalize((mat3x3<f32>(_e155[0].xyz, _e155[1].xyz, _e155[2].xyz) * _e165));
    let _e170: vec4<f32> = G.misc;
    let _e173: mat4x4<f32> = G.invView;
    let _e174: vec3<f32> = viewPos_5;
    world_1 = (_e170.yzw + (_e173 * vec4<f32>(_e174.x, _e174.y, _e174.z, 0f)).xyz);
    let _e185: vec4<f32> = G.shadeA;
    scale_1 = max(_e185.y, 0.001f);
    let _e190: vec3<f32> = world_1;
    let _e192: f32 = scale_1;
    let _e195: vec4<f32> = G.simB;
    let _e198: vec4<f32> = G.shadeA;
    let _e201: f32 = footprint_3;
    let _e202: f32 = scale_1;
    let _e204: vec2<f32> = rippleGradient((_e190.xz * _e192), (_e195.z * _e198.z), (_e201 * _e202));
    grad = _e204;
    let _e206: vec2<f32> = grad;
    let _e209: vec2<f32> = grad;
    let _e213: vec4<f32> = G.shadeA;
    g_1 = (vec3<f32>(_e206.x, 0f, _e209.y) * _e213.x);
    let _e218: mat4x4<f32> = G.view;
    let _e228: vec3<f32> = nWorld_6;
    let _e229: vec3<f32> = g_1;
    let _e230: vec3<f32> = nWorld_6;
    let _e231: vec3<f32> = g_1;
    let _e232: vec3<f32> = nWorld_6;
    return normalize((mat3x3<f32>(_e218[0].xyz, _e218[1].xyz, _e218[2].xyz) * normalize((_e228 - (_e229 - (_e230 * dot(_e231, _e232)))))));
}

fn sunSpecular(n_4: vec3<f32>, V: vec3<f32>, footprint_4: f32) -> vec3<f32> {
    var n_5: vec3<f32>;
    var V_1: vec3<f32>;
    var footprint_5: f32;
    var L: vec3<f32>;
    var NoL: f32;
    var H: vec3<f32>;
    var NoH: f32;
    var NoV: f32;
    var rough: f32;
    var a2_: f32;
    var den: f32;
    var D: f32;
    var F: f32;
    var k_1: f32;
    var Vis: f32;

    n_5 = n_4;
    V_1 = V;
    footprint_5 = footprint_4;
    let _e149: vec4<f32> = G.sunDir;
    L = normalize(_e149.xyz);
    let _e153: vec3<f32> = n_5;
    let _e154: vec3<f32> = L;
    NoL = dot(_e153, _e154);
    let _e157: f32 = NoL;
    let _e161: vec4<f32> = G.sunDir;
    if ((_e157 <= 0f) || (_e161.w <= 0f)) {
        {
            return vec3(0f);
        }
    }
    let _e168: vec3<f32> = L;
    let _e169: vec3<f32> = V_1;
    H = normalize((_e168 + _e169));
    let _e173: vec3<f32> = n_5;
    let _e174: vec3<f32> = H;
    NoH = max(dot(_e173, _e174), 0f);
    let _e179: vec3<f32> = n_5;
    let _e180: vec3<f32> = V_1;
    NoV = max(dot(_e179, _e180), 0.001f);
    let _e186: vec4<f32> = G.shadeA;
    let _e188: f32 = footprint_5;
    rough = clamp((_e186.w + (_e188 * 0.25f)), 0.02f, 0.7f);
    let _e196: f32 = rough;
    let _e197: f32 = rough;
    let _e199: f32 = rough;
    let _e201: f32 = rough;
    a2_ = (((_e196 * _e197) * _e199) * _e201);
    let _e204: f32 = NoH;
    let _e205: f32 = NoH;
    let _e207: f32 = a2_;
    den = (((_e204 * _e205) * (_e207 - 1f)) + 1f);
    let _e214: f32 = a2_;
    let _e215: f32 = den;
    let _e217: f32 = den;
    D = (_e214 / max(((PI * _e215) * _e217), 0.000000001f));
    let _e226: vec3<f32> = V_1;
    let _e227: vec3<f32> = H;
    F = (0.02f + (0.98f * pow((1f - max(dot(_e226, _e227), 0f)), 5f)));
    let _e237: f32 = rough;
    let _e238: f32 = rough;
    k_1 = ((_e237 * _e238) * 0.5f);
    let _e244: f32 = NoL;
    let _e245: f32 = NoV;
    let _e247: f32 = k_1;
    let _e250: f32 = k_1;
    let _e253: f32 = NoV;
    let _e254: f32 = NoL;
    let _e256: f32 = k_1;
    let _e259: f32 = k_1;
    Vis = (0.5f / max(((_e244 * ((_e245 * (1f - _e247)) + _e250)) + (_e253 * ((_e254 * (1f - _e256)) + _e259))), 0.00001f));
    let _e271: f32 = D;
    let _e272: f32 = Vis;
    let _e274: f32 = F;
    let _e276: f32 = NoL;
    let _e279: vec4<f32> = G.shadeB;
    let _e283: vec4<f32> = G.compat;
    let _e288: vec4<f32> = G.sunDir;
    return ((vec3<f32>(1f, 0.96f, 0.88f) * min(((((_e271 * _e272) * _e274) * _e276) * _e279.x), _e283.z)) * _e288.w);
}

fn shadeAboveLava(uv_3: vec2<f32>, n_6: vec3<f32>, fd_1: f32, ambient: f32) -> vec3<f32> {
    var uv_4: vec2<f32>;
    var n_7: vec3<f32>;
    var fd_2: f32;
    var ambient_1: f32;
    var P: vec3<f32>;
    var V_2: vec3<f32>;
    var local_33: vec3<f32>;
    var footprint_6: f32;
    var wrinkled: vec3<f32>;
    var path: f32;
    var glow: vec3<f32>;
    var core: vec3<f32>;
    var fresnel: f32;
    var rim: vec3<f32>;

    uv_4 = uv_3;
    n_7 = n_6;
    fd_2 = fd_1;
    ambient_1 = ambient;
    let _e150: vec2<f32> = uv_4;
    let _e151: f32 = fd_2;
    let _e152: vec3<f32> = viewPosAt(_e150, _e151);
    P = _e152;
    let _e154: vec3<f32> = P;
    V_2 = normalize(-(_e154));
    let _e158: vec3<f32> = n_7;
    let _e159: vec3<f32> = V_2;
    if (dot(_e158, _e159) < 0f) {
        let _e163: vec3<f32> = n_7;
        local_33 = -(_e163);
    } else {
        let _e165: vec3<f32> = n_7;
        local_33 = _e165;
    }
    let _e167: vec3<f32> = local_33;
    n_7 = _e167;
    let _e168: f32 = fd_2;
    let _e169: f32 = pixelFootprint(_e168);
    footprint_6 = _e169;
    let _e171: vec3<f32> = n_7;
    let _e172: vec3<f32> = P;
    let _e173: f32 = footprint_6;
    let _e174: vec3<f32> = rippleNormal(_e171, _e172, _e173);
    wrinkled = _e174;
    let _e176: vec3<f32> = n_7;
    let _e177: vec3<f32> = wrinkled;
    let _e180: vec3<f32> = wrinkled;
    let _e181: vec3<f32> = V_2;
    n_7 = normalize(mix(_e176, _e177, vec3(smoothstep(0f, 0.2f, dot(_e180, _e181)))));
    let _e187: vec2<f32> = uv_4;
    let _e188: vec4<f32> = textureSample(thicknessTex_texture, thicknessTex_sampler, _e187);
    let _e193: vec4<f32> = G.waterA;
    path = (max(_e188.x, 0f) * _e193.y);
    let _e198: vec4<f32> = G.scatter;
    let _e201: f32 = ambient_1;
    glow = (_e198.xyz * (1.4f + _e201));
    let _e205: vec3<f32> = glow;
    let _e208: vec4<f32> = G.scatter;
    let _e211: f32 = path;
    core = (_e205 * (1f - exp(((-(_e208.w) * _e211) * 0.45f))));
    let _e220: vec3<f32> = n_7;
    let _e221: vec3<f32> = V_2;
    fresnel = pow((1f - clamp(dot(_e220, _e221), 0f, 1f)), 2f);
    let _e230: vec3<f32> = glow;
    let _e231: f32 = fresnel;
    rim = ((_e230 * _e231) * 0.85f);
    let _e236: vec3<f32> = core;
    let _e237: vec3<f32> = rim;
    let _e239: vec3<f32> = n_7;
    let _e240: vec3<f32> = V_2;
    let _e241: f32 = footprint_6;
    let _e242: vec3<f32> = sunSpecular(_e239, _e240, _e241);
    let _e248: vec3<f32> = P;
    let _e249: f32 = sunLit(_e248);
    return ((_e236 + _e237) + ((_e242 * vec3<f32>(1f, 0.65f, 0.25f)) * _e249));
}

fn shadeAboveWater(uv_5: vec2<f32>, n_8: vec3<f32>, fd_3: f32, sceneDist_1: f32, ambient_2: f32, bs_4: vec2<f32>) -> vec3<f32> {
    var uv_6: vec2<f32>;
    var n_9: vec3<f32>;
    var fd_4: f32;
    var sceneDist_2: f32;
    var ambient_3: f32;
    var bs_5: vec2<f32>;
    var P_1: vec3<f32>;
    var V_3: vec3<f32>;
    var local_34: vec3<f32>;
    var footprint_7: f32;
    var thickness: f32;
    var upV: vec3<f32>;
    var vertical: f32;
    var film: f32;
    var wrinkled_1: vec3<f32>;
    var offset: vec2<f32>;
    var ruv: vec2<f32>;
    var refrDist: f32;
    var path_1: f32;
    var under: vec3<f32>;
    var wet: f32;
    var transmitted: vec3<f32>;
    var nWorld_7: vec3<f32>;
    var local_35: vec3<f32>;
    var lightColor: vec3<f32>;
    var scattered: vec3<f32>;
    var water: vec3<f32>;
    var Rv_2: vec3<f32>;
    var Rw_2: vec3<f32>;
    var hit_1: f32;
    var ssr: vec3<f32>;
    var skyVisible: f32;
    var reflection: vec3<f32>;
    var F_1: f32;

    uv_6 = uv_5;
    n_9 = n_8;
    fd_4 = fd_3;
    sceneDist_2 = sceneDist_1;
    ambient_3 = ambient_2;
    bs_5 = bs_4;
    let _e154: vec2<f32> = uv_6;
    let _e155: f32 = fd_4;
    let _e156: vec3<f32> = viewPosAt(_e154, _e155);
    P_1 = _e156;
    let _e158: vec3<f32> = P_1;
    V_3 = normalize(-(_e158));
    let _e162: vec3<f32> = n_9;
    let _e163: vec3<f32> = V_3;
    if (dot(_e162, _e163) < 0f) {
        let _e167: vec3<f32> = n_9;
        local_34 = -(_e167);
    } else {
        let _e169: vec3<f32> = n_9;
        local_34 = _e169;
    }
    let _e171: vec3<f32> = local_34;
    n_9 = _e171;
    let _e172: f32 = fd_4;
    let _e173: f32 = pixelFootprint(_e172);
    footprint_7 = _e173;
    let _e175: vec2<f32> = uv_6;
    let _e176: vec4<f32> = textureSample(thicknessTex_texture, thicknessTex_sampler, _e175);
    thickness = max(_e176.x, 0f);
    let _e182: mat4x4<f32> = G.view;
    upV = normalize((mat3x3<f32>(_e182[0].xyz, _e182[1].xyz, _e182[2].xyz) * vec3<f32>(0f, 1f, 0f)));
    let _e199: f32 = thickness;
    let _e200: vec3<f32> = V_3;
    let _e201: vec3<f32> = upV;
    vertical = (_e199 * abs(dot(_e200, _e201)));
    let _e209: vec4<f32> = G.shadeB;
    let _e213: f32 = vertical;
    film = (1f - smoothstep(0.02f, max(_e209.z, 0.03f), _e213));
    let _e217: vec3<f32> = n_9;
    let _e218: vec3<f32> = upV;
    let _e219: f32 = film;
    n_9 = normalize(mix(_e217, _e218, vec3((_e219 * 0.9f))));
    let _e225: vec3<f32> = n_9;
    let _e226: vec3<f32> = P_1;
    let _e227: f32 = footprint_7;
    let _e228: vec3<f32> = rippleNormal(_e225, _e226, _e227);
    wrinkled_1 = _e228;
    let _e230: vec3<f32> = n_9;
    let _e231: vec3<f32> = wrinkled_1;
    let _e234: vec3<f32> = wrinkled_1;
    let _e235: vec3<f32> = V_3;
    n_9 = normalize(mix(_e230, _e231, vec3(smoothstep(0f, 0.15f, dot(_e234, _e235)))));
    let _e241: vec3<f32> = n_9;
    let _e244: vec4<f32> = G.waterA;
    let _e247: f32 = thickness;
    let _e252: f32 = fd_4;
    offset = (((_e241.xy * _e244.z) * clamp(_e247, 0f, 2f)) / vec2(max(_e252, 1f)));
    let _e258: vec2<f32> = uv_6;
    let _e259: vec2<f32> = offset;
    ruv = clamp((_e258 + _e259), vec2(0f), vec2(1f));
    let _e267: vec2<f32> = ruv;
    let _e268: vec4<f32> = textureSample(sceneDepth_texture, sceneDepth_sampler, _e267);
    let _e270: f32 = linearDepth(_e268.x);
    refrDist = _e270;
    let _e272: vec2<f32> = ruv;
    let _e273: vec4<f32> = textureSample(thicknessTex_texture, thicknessTex_sampler, _e272);
    path_1 = max(_e273.x, 0f);
    let _e278: f32 = refrDist;
    let _e279: f32 = fd_4;
    if (_e278 < _e279) {
        {
            let _e281: vec2<f32> = uv_6;
            ruv = _e281;
            let _e282: f32 = thickness;
            path_1 = _e282;
        }
    }
    let _e283: f32 = path_1;
    let _e285: vec4<f32> = G.waterA;
    path_1 = (_e283 * _e285.y);
    let _e288: vec2<f32> = ruv;
    let _e289: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e288);
    under = _e289.xyz;
    let _e293: vec4<f32> = G.shadeB;
    let _e297: f32 = path_1;
    wet = (_e293.y * smoothstep(0f, 0.03f, _e297));
    let _e301: vec3<f32> = under;
    let _e306: f32 = wet;
    let _e312: f32 = wet;
    under = (pow(max(_e301, vec3(0f)), vec3((1f + _e306))) * (1f - (0.15f * _e312)));
    let _e316: vec3<f32> = under;
    let _e318: vec4<f32> = G.absorb;
    let _e321: f32 = path_1;
    transmitted = (_e316 * exp((-(_e318.xyz) * _e321)));
    let _e327: mat4x4<f32> = G.invView;
    let _e337: vec3<f32> = n_9;
    nWorld_7 = normalize((mat3x3<f32>(_e327[0].xyz, _e327[1].xyz, _e327[2].xyz) * _e337));
    let _e342: vec4<f32> = G.compat;
    if (_e342.y <= 1f) {
        let _e346: vec2<f32> = bs_5;
        let _e347: vec3<f32> = vanillaLight(_e346);
        local_35 = _e347;
    } else {
        let _e348: f32 = ambient_3;
        let _e349: vec2<f32> = bs_5;
        let _e352: vec2<f32> = bs_5;
        let _e357: mat4x4<f32> = G.invView;
        let _e367: vec3<f32> = P_1;
        let _e369: vec3<f32> = nWorld_7;
        let _e370: vec2<f32> = bs_5;
        let _e372: vec3<f32> = shaderBlockLight((mat3x3<f32>(_e357[0].xyz, _e357[1].xyz, _e357[2].xyz) * _e367), _e369, _e370.x);
        local_35 = (vec3(((_e348 * _e349.y) * _e352.y)) + (_e372 * 0.5f));
    }
    let _e377: vec3<f32> = local_35;
    lightColor = _e377;
    let _e380: vec4<f32> = G.scatter;
    let _e382: vec3<f32> = lightColor;
    let _e386: vec4<f32> = G.scatter;
    let _e389: f32 = path_1;
    let _e395: vec4<f32> = G.compat;
    scattered = (((_e380.xyz * _e382) * (1f - exp((-(_e386.w) * _e389)))) * _e395.y);
    let _e399: vec3<f32> = transmitted;
    let _e400: vec3<f32> = scattered;
    water = (_e399 + _e400);
    let _e403: vec3<f32> = V_3;
    let _e405: vec3<f32> = n_9;
    Rv_2 = reflect(-(_e403), _e405);
    let _e409: mat4x4<f32> = G.invView;
    let _e410: vec3<f32> = Rv_2;
    Rw_2 = (_e409 * vec4<f32>(_e410.x, _e410.y, _e410.z, 0f)).xyz;
    let _e420: vec3<f32> = P_1;
    let _e421: vec3<f32> = n_9;
    let _e425: vec3<f32> = Rv_2;
    let _e428: vec3<f32> = traceReflection((_e420 + (_e421 * 0.05f)), _e425, (&hit_1));
    ssr = _e428;
    let _e432: vec2<f32> = bs_5;
    skyVisible = smoothstep(0f, 0.7f, _e432.y);
    let _e436: vec3<f32> = Rv_2;
    let _e437: vec3<f32> = Rw_2;
    let _e438: vec3<f32> = reflectedSky(_e436, _e437);
    let _e439: vec3<f32> = lightColor;
    let _e444: f32 = skyVisible;
    let _e448: vec3<f32> = ssr;
    let _e449: f32 = hit_1;
    reflection = mix((_e438 * mix((_e439 * 0.3f), vec3(1f), vec3(_e444))), _e448, vec3(_e449));
    let _e456: vec3<f32> = n_9;
    let _e457: vec3<f32> = V_3;
    F_1 = (0.02f + (0.98f * pow((1f - clamp(dot(_e456, _e457), 0f, 1f)), 5f)));
    let _e468: vec3<f32> = water;
    let _e469: vec3<f32> = reflection;
    let _e470: f32 = F_1;
    let _e473: vec3<f32> = n_9;
    let _e474: vec3<f32> = V_3;
    let _e475: f32 = footprint_7;
    let _e476: vec3<f32> = sunSpecular(_e473, _e474, _e475);
    let _e477: vec3<f32> = P_1;
    let _e478: f32 = sunLit(_e477);
    let _e482: vec2<f32> = bs_5;
    return (mix(_e468, _e469, vec3(_e470)) + ((_e476 * _e478) * smoothstep(0.5f, 0.95f, _e482.y)));
}

fn slimeRgb(argb: i32) -> vec3<f32> {
    var argb_1: i32;

    argb_1 = argb;
    let _e144: i32 = argb_1;
    let _e150: i32 = argb_1;
    let _e156: i32 = argb_1;
    return (vec3<f32>(f32(((_e144 >> 16u) & 255i)), f32(((_e150 >> 8u) & 255i)), f32((_e156 & 255i))) / vec3(255f));
}

fn slimeTexel(uv_7: vec2<f32>, texelsPerBlock: f32) -> vec3<f32> {
    var uv_8: vec2<f32>;
    var texelsPerBlock_1: f32;
    var size_2: vec2<i32>;
    var t_8: vec2<i32>;

    uv_8 = uv_7;
    texelsPerBlock_1 = texelsPerBlock;
    let _e148: i32 = global_1.slimeTex[0];
    let _e151: i32 = global_1.slimeTex[1];
    size_2 = vec2<i32>(_e148, _e151);
    let _e154: vec2<f32> = uv_8;
    let _e155: f32 = texelsPerBlock_1;
    t_8 = vec2<i32>(floor((_e154 * _e155)));
    let _e160: vec2<i32> = t_8;
    let _e161: vec2<i32> = size_2;
    let _e163: vec2<i32> = size_2;
    let _e165: vec2<i32> = size_2;
    t_8 = (((_e160 % _e161) + _e163) % _e165);
    let _e168: vec2<i32> = t_8;
    let _e171: vec2<i32> = t_8;
    let _e173: vec2<i32> = size_2;
    let _e178: i32 = global_1.slimeTex[((4i + _e168.x) + (_e171.y * _e173.x))];
    let _e179: vec3<f32> = slimeRgb(_e178);
    return _e179;
}

fn slimeAlbedo(world_2: vec3<f32>, nWorld_8: vec3<f32>, footprint_8: f32) -> vec3<f32> {
    var world_3: vec3<f32>;
    var nWorld_9: vec3<f32>;
    var footprint_9: f32;
    var tpb: f32;
    var w: vec3<f32>;
    var c_8: vec3<f32>;
    var detail: f32;

    world_3 = world_2;
    nWorld_9 = nWorld_8;
    footprint_9 = footprint_8;
    let _e150: i32 = global_1.slimeTex[0];
    tpb = f32(_e150);
    let _e153: vec3<f32> = nWorld_9;
    w = pow(abs(_e153), vec3(8f));
    let _e159: vec3<f32> = w;
    let _e160: vec3<f32> = w;
    let _e162: vec3<f32> = w;
    let _e165: vec3<f32> = w;
    w = (_e159 / vec3(((_e160.x + _e162.y) + _e165.z)));
    let _e170: vec3<f32> = w;
    let _e172: vec3<f32> = world_3;
    let _e174: vec3<f32> = world_3;
    let _e177: f32 = tpb;
    let _e178: vec3<f32> = slimeTexel(vec2<f32>(_e172.x, _e174.z), _e177);
    let _e180: vec3<f32> = w;
    let _e182: vec3<f32> = world_3;
    let _e184: vec3<f32> = world_3;
    let _e188: f32 = tpb;
    let _e189: vec3<f32> = slimeTexel(vec2<f32>(_e182.z, -(_e184.y)), _e188);
    let _e192: vec3<f32> = w;
    let _e194: vec3<f32> = world_3;
    let _e196: vec3<f32> = world_3;
    let _e200: f32 = tpb;
    let _e201: vec3<f32> = slimeTexel(vec2<f32>(_e194.x, -(_e196.y)), _e200);
    c_8 = (((_e170.y * _e178) + (_e180.x * _e189)) + (_e192.z * _e201));
    let _e208: f32 = footprint_9;
    let _e209: f32 = tpb;
    detail = (1f - smoothstep(0.5f, 1.5f, (_e208 * _e209)));
    let _e216: i32 = global_1.slimeTex[2];
    let _e217: vec3<f32> = slimeRgb(_e216);
    let _e218: vec3<f32> = c_8;
    let _e219: f32 = detail;
    return mix(_e217, _e218, vec3(_e219));
}

fn shadeSlime(uv_9: vec2<f32>, n_10: vec3<f32>, fd_5: f32, bs_6: vec2<f32>) -> vec3<f32> {
    var uv_10: vec2<f32>;
    var n_11: vec3<f32>;
    var fd_6: f32;
    var bs_7: vec2<f32>;
    var P_2: vec3<f32>;
    var V_4: vec3<f32>;
    var local_36: vec3<f32>;
    var nWorld_10: vec3<f32>;
    var world_4: vec3<f32>;
    var albedo: vec3<f32>;
    var lit_1: vec3<f32>;
    var n2_: vec3<f32>;
    var local_37: f32;
    var face: f32;
    var path_2: f32;
    var opacity: f32;
    var behind: vec3<f32>;

    uv_10 = uv_9;
    n_11 = n_10;
    fd_6 = fd_5;
    bs_7 = bs_6;
    let _e150: vec2<f32> = uv_10;
    let _e151: f32 = fd_6;
    let _e152: vec3<f32> = viewPosAt(_e150, _e151);
    P_2 = _e152;
    let _e154: vec3<f32> = P_2;
    V_4 = normalize(-(_e154));
    let _e158: vec3<f32> = n_11;
    let _e159: vec3<f32> = V_4;
    if (dot(_e158, _e159) < 0f) {
        let _e163: vec3<f32> = n_11;
        local_36 = -(_e163);
    } else {
        let _e165: vec3<f32> = n_11;
        local_36 = _e165;
    }
    let _e167: vec3<f32> = local_36;
    n_11 = _e167;
    let _e169: mat4x4<f32> = G.invView;
    let _e179: vec3<f32> = n_11;
    nWorld_10 = normalize((mat3x3<f32>(_e169[0].xyz, _e169[1].xyz, _e169[2].xyz) * _e179));
    let _e184: vec4<f32> = G.misc;
    let _e187: mat4x4<f32> = G.invView;
    let _e188: vec3<f32> = P_2;
    let _e197: vec3<f32> = nWorld_10;
    world_4 = ((_e184.yzw + (_e187 * vec4<f32>(_e188.x, _e188.y, _e188.z, 0f)).xyz) - (_e197 * 0.01f));
    let _e202: vec3<f32> = world_4;
    let _e203: vec3<f32> = nWorld_10;
    let _e204: f32 = fd_6;
    let _e205: f32 = pixelFootprint(_e204);
    let _e206: vec3<f32> = slimeAlbedo(_e202, _e203, _e205);
    albedo = _e206;
    let _e210: vec4<f32> = G.compat;
    if (_e210.y <= 1f) {
        {
            let _e214: vec3<f32> = nWorld_10;
            let _e215: vec3<f32> = nWorld_10;
            n2_ = (_e214 * _e215);
            let _e218: vec3<f32> = n2_;
            let _e222: vec3<f32> = n2_;
            let _e227: vec3<f32> = n2_;
            let _e229: vec3<f32> = nWorld_10;
            if (_e229.y > 0f) {
                local_37 = 1f;
            } else {
                local_37 = 0.5f;
            }
            let _e236: f32 = local_37;
            face = (((_e218.x * 0.6f) + (_e222.z * 0.8f)) + (_e227.y * _e236));
            let _e240: vec3<f32> = albedo;
            let _e241: f32 = face;
            let _e243: vec2<f32> = bs_7;
            let _e244: vec3<f32> = vanillaLight(_e243);
            let _e247: vec4<f32> = G.matD;
            lit_1 = min((((_e240 * _e241) * _e244) * _e247.y), vec3(1f));
        }
    } else {
        {
            let _e253: vec3<f32> = albedo;
            let _e255: vec4<f32> = G.matD;
            let _e259: vec4<f32> = G.compat;
            let _e265: mat4x4<f32> = G.invView;
            let _e275: vec3<f32> = P_2;
            let _e277: vec3<f32> = P_2;
            let _e278: vec3<f32> = nWorld_10;
            let _e279: vec2<f32> = bs_7;
            let _e280: vec3<f32> = shaderSurfaceLight((mat3x3<f32>(_e265[0].xyz, _e265[1].xyz, _e265[2].xyz) * _e275), _e277, _e278, _e279);
            lit_1 = ((((_e253 * _e255.y) * _e259.y) * 0.5f) * _e280);
        }
    }
    let _e282: vec2<f32> = uv_10;
    let _e283: vec4<f32> = textureSample(thicknessTex_texture, thicknessTex_sampler, _e282);
    let _e288: vec4<f32> = G.waterA;
    path_2 = (max(_e283.x, 0f) * _e288.y);
    let _e293: vec4<f32> = G.matD;
    let _e297: f32 = path_2;
    opacity = mix(_e293.w, 1f, (1f - exp((-(_e297) * 3f))));
    let _e305: vec2<f32> = uv_10;
    let _e306: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e305);
    let _e310: vec3<f32> = albedo;
    behind = (_e306.xyz * mix(vec3(1f), (_e310 * 1.3f), vec3(0.75f)));
    let _e318: vec3<f32> = behind;
    let _e319: vec3<f32> = lit_1;
    let _e320: f32 = opacity;
    return mix(_e318, _e319, vec3(_e320));
}

fn foamLace(p_9: vec2<f32>, coverage: f32, footprint_10: f32) -> f32 {
    var p_10: vec2<f32>;
    var coverage_1: f32;
    var footprint_11: f32;
    var size_3: f32;
    var q_2: vec2<f32>;
    var cell: vec2<i32>;
    var f1_: f32 = 9f;
    var f2_: f32 = 9f;
    var k_2: i32 = 0i;
    var c_9: vec2<i32>;
    var s: u32;
    var feature: vec2<f32>;
    var d_5: f32;
    var wall: f32;
    var detail_1: f32;

    p_10 = p_9;
    coverage_1 = coverage;
    footprint_11 = footprint_10;
    let _e149: vec4<f32> = G.shadeB;
    size_3 = max(_e149.w, 0.001f);
    let _e154: vec2<f32> = p_10;
    let _e155: f32 = size_3;
    q_2 = (_e154 / vec2(_e155));
    let _e159: vec2<f32> = q_2;
    cell = vec2<i32>(floor(_e159));
    loop {
        let _e169: i32 = k_2;
        if !((_e169 < 9i)) {
            break;
        }
        {
            let _e176: vec2<i32> = cell;
            let _e177: i32 = k_2;
            let _e182: i32 = k_2;
            c_9 = (_e176 + vec2<i32>(((_e177 % 3i) - 1i), ((_e182 / 3i) - 1i)));
            let _e190: vec2<i32> = c_9;
            let _e195: vec2<i32> = c_9;
            let _e201: u32 = hash(((u32(_e190.x) * 73856093u) ^ (u32(_e195.y) * 19349663u)));
            s = _e201;
            let _e203: vec2<i32> = c_9;
            let _e211: f32 = rand((&s));
            let _e214: f32 = rand((&s));
            feature = ((vec2<f32>(_e203) + vec2(0.1f)) + (0.8f * vec2<f32>(_e211, _e214)));
            let _e219: vec2<f32> = q_2;
            let _e220: vec2<f32> = feature;
            d_5 = length((_e219 - _e220));
            let _e224: f32 = d_5;
            let _e225: f32 = f1_;
            if (_e224 < _e225) {
                {
                    let _e227: f32 = f1_;
                    f2_ = _e227;
                    let _e228: f32 = d_5;
                    f1_ = _e228;
                }
            } else {
                let _e229: f32 = d_5;
                let _e230: f32 = f2_;
                if (_e229 < _e230) {
                    {
                        let _e232: f32 = d_5;
                        f2_ = _e232;
                    }
                }
            }
        }
        continuing {
            let _e173: i32 = k_2;
            k_2 = (_e173 + 1i);
        }
    }
    let _e237: f32 = coverage_1;
    let _e240: f32 = f2_;
    let _e241: f32 = f1_;
    wall = (1f - smoothstep(0f, (0.06f + (0.6f * _e237)), (_e240 - _e241)));
    let _e248: f32 = size_3;
    let _e249: f32 = footprint_11;
    detail_1 = smoothstep(0.7f, 2.5f, (_e248 / max(_e249, 0.00001f)));
    let _e256: f32 = wall;
    let _e257: f32 = detail_1;
    return mix(0.55f, _e256, _e257);
}

fn shadeSurfaceFromBelow(uv_11: vec2<f32>, n_12: vec3<f32>, fd_7: f32, deep: vec3<f32>) -> vec3<f32> {
    var uv_12: vec2<f32>;
    var n_13: vec3<f32>;
    var fd_8: f32;
    var deep_1: vec3<f32>;
    var P_3: vec3<f32>;
    var V_5: vec3<f32>;
    var local_38: vec3<f32>;
    var wrinkled_2: vec3<f32>;
    var cosI: f32;
    var sinT2_: f32;
    var cosT: f32;
    var F_2: f32;
    var ruv_1: vec2<f32>;
    var above: vec3<f32>;

    uv_12 = uv_11;
    n_13 = n_12;
    fd_8 = fd_7;
    deep_1 = deep;
    let _e150: vec2<f32> = uv_12;
    let _e151: f32 = fd_8;
    let _e152: vec3<f32> = viewPosAt(_e150, _e151);
    P_3 = _e152;
    let _e154: vec3<f32> = P_3;
    V_5 = normalize(-(_e154));
    let _e158: vec3<f32> = n_13;
    let _e159: vec3<f32> = V_5;
    if (dot(_e158, _e159) < 0f) {
        let _e163: vec3<f32> = n_13;
        local_38 = -(_e163);
    } else {
        let _e165: vec3<f32> = n_13;
        local_38 = _e165;
    }
    let _e167: vec3<f32> = local_38;
    n_13 = _e167;
    let _e168: vec3<f32> = n_13;
    let _e169: vec3<f32> = P_3;
    let _e170: f32 = fd_8;
    let _e171: f32 = pixelFootprint(_e170);
    let _e172: vec3<f32> = rippleNormal(_e168, _e169, _e171);
    wrinkled_2 = _e172;
    let _e174: vec3<f32> = n_13;
    let _e175: vec3<f32> = wrinkled_2;
    let _e178: vec3<f32> = wrinkled_2;
    let _e179: vec3<f32> = V_5;
    n_13 = normalize(mix(_e174, _e175, vec3(smoothstep(0f, 0.15f, dot(_e178, _e179)))));
    let _e185: vec3<f32> = n_13;
    let _e186: vec3<f32> = V_5;
    cosI = clamp(dot(_e185, _e186), 0f, 1f);
    let _e198: f32 = cosI;
    let _e199: f32 = cosI;
    sinT2_ = (1.7768888f * (1f - (_e198 * _e199)));
    let _e204: f32 = sinT2_;
    if (_e204 >= 1f) {
        {
            let _e207: vec3<f32> = deep_1;
            return (_e207 * 1.4f);
        }
    }
    let _e211: f32 = sinT2_;
    cosT = sqrt((1f - _e211));
    let _e218: f32 = cosT;
    F_2 = (0.02f + (0.98f * pow((1f - _e218), 5f)));
    let _e225: vec2<f32> = uv_12;
    let _e226: vec3<f32> = n_13;
    let _e229: vec4<f32> = G.waterA;
    ruv_1 = clamp((_e225 - ((_e226.xy * _e229.z) * 0.6f)), vec2(0f), vec2(1f));
    let _e241: vec2<f32> = ruv_1;
    let _e242: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e241);
    above = _e242.xyz;
    let _e245: vec3<f32> = above;
    let _e246: vec3<f32> = deep_1;
    let _e249: f32 = F_2;
    return mix(_e245, (_e246 * 1.4f), vec3(_e249));
}

fn main_1() {
    var uv_13: vec2<f32>;
    var g_2: vec4<f32>;
    var fd_9: f32;
    var matSample: vec4<f32>;
    var matId: f32;
    var surfaceLight: vec2<f32>;
    var lavaPass: bool;
    var slimePass: bool;
    var surfaceOnly: bool;
    var local_39: vec4<f32>;
    var foam: vec4<f32>;
    var sceneDev: f32;
    var sceneDist_3: f32;
    var hasFluid: bool;
    var underwater: bool;
    var matTagged: bool;
    var slime: vec3<f32>;
    var slimeDepth: f32;
    var clip_3: vec4<f32>;
    var inside: vec3<f32>;
    var ambient_4: f32;
    var color: vec3<f32>;
    var outDepth: f32;
    var local_40: vec3<f32>;
    var deep_2: vec3<f32>;
    var visible: f32;
    var local_41: vec3<f32>;
    var clip_4: vec4<f32>;
    var fog: f32;
    var local_42: vec3<f32>;
    var clip_5: vec4<f32>;
    var foamColor: vec3<f32>;
    var coverage_2: f32;
    var world_5: vec3<f32>;

    let _e143: vec4<f32> = gl_FragCoord_1;
    let _e146: vec4<f32> = G.screen;
    uv_13 = (_e143.xy * _e146.zw);
    let _e150: vec2<f32> = uv_13;
    let _e151: vec4<f32> = textureSample(gbuffer_texture, gbuffer_sampler, _e150);
    g_2 = _e151;
    let _e153: vec4<f32> = g_2;
    fd_9 = _e153.w;
    let _e156: vec2<f32> = uv_13;
    let _e157: vec4<f32> = textureSample(materialTex_texture, materialTex_sampler, _e156);
    matSample = _e157;
    let _e159: vec4<f32> = matSample;
    matId = _e159.x;
    let _e162: vec4<f32> = matSample;
    surfaceLight = _e162.yz;
    let _e166: f32 = pc.filterMat;
    lavaPass = (abs((_e166 - 2f)) < 0.5f);
    let _e174: f32 = pc.filterMat;
    slimePass = (_e174 > 2.5f);
    let _e178: bool = lavaPass;
    let _e179: bool = slimePass;
    surfaceOnly = (_e178 || _e179);
    let _e182: bool = slimePass;
    if _e182 {
        local_39 = vec4(0f);
    } else {
        let _e185: vec2<f32> = uv_13;
        let _e186: vec4<f32> = textureSample(foamTex_texture, foamTex_sampler, _e185);
        local_39 = _e186;
    }
    let _e188: vec4<f32> = local_39;
    foam = _e188;
    let _e190: vec2<f32> = uv_13;
    let _e191: vec4<f32> = textureSample(sceneDepth_texture, sceneDepth_sampler, _e190);
    sceneDev = _e191.x;
    let _e194: f32 = sceneDev;
    let _e195: f32 = linearDepth(_e194);
    sceneDist_3 = _e195;
    let _e197: f32 = fd_9;
    let _e200: f32 = fd_9;
    let _e201: f32 = sceneDist_3;
    hasFluid = ((_e197 > 0f) && (_e200 < _e201));
    let _e205: vec4<f32> = global.viewState;
    let _e209: bool = slimePass;
    underwater = ((_e205.x > 0.5f) && !(_e209));
    let _e213: f32 = matId;
    matTagged = (_e213 >= -0.5f);
    let _e218: bool = hasFluid;
    let _e219: bool = matTagged;
    if (_e218 && _e219) {
        {
            let _e221: f32 = matId;
            let _e223: f32 = pc.filterMat;
            if (abs((_e221 - _e223)) > 0.25f) {
                {
                    discard;
                }
            }
        }
    } else {
        let _e228: bool = surfaceOnly;
        let _e229: bool = slimePass;
        let _e231: vec4<f32> = G.matD;
        if (_e228 && !((_e229 && (_e231.x > 0.5f)))) {
            {
                discard;
            }
        }
    }
    let _e238: bool = slimePass;
    if _e238 {
        {
            let _e239: vec2<f32> = uv_13;
            let _e240: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e239);
            slime = _e240.xyz;
            let _e243: f32 = sceneDev;
            slimeDepth = _e243;
            let _e245: bool = hasFluid;
            let _e246: bool = matTagged;
            if (_e245 && _e246) {
                {
                    let _e248: vec2<f32> = uv_13;
                    let _e249: vec4<f32> = g_2;
                    let _e251: f32 = fd_9;
                    let _e252: vec2<f32> = surfaceLight;
                    let _e253: vec3<f32> = shadeSlime(_e248, _e249.xyz, _e251, _e252);
                    slime = _e253;
                    let _e255: mat4x4<f32> = G.proj;
                    let _e256: vec2<f32> = uv_13;
                    let _e257: f32 = fd_9;
                    let _e258: vec3<f32> = viewPosAt(_e256, _e257);
                    clip_3 = (_e255 * vec4<f32>(_e258.x, _e258.y, _e258.z, 1f));
                    let _e266: vec4<f32> = clip_3;
                    let _e268: vec4<f32> = clip_3;
                    slimeDepth = (_e266.z / _e268.w);
                }
            }
            let _e272: vec4<f32> = G.matD;
            if (_e272.x > 0.5f) {
                {
                    let _e278: i32 = global_1.slimeTex[2];
                    let _e279: vec3<f32> = slimeRgb(_e278);
                    let _e283: vec4<f32> = G.skyColor;
                    let _e292: vec4<f32> = G.matD;
                    inside = (((_e279 * 0.55f) * clamp((_e283.w / 0.85f), 0.2f, 1f)) * _e292.y);
                    let _e296: vec3<f32> = slime;
                    let _e297: vec3<f32> = inside;
                    let _e299: vec4<f32> = G.matD;
                    slime = mix(_e296, _e297, vec3(_e299.z));
                }
            }
            let _e303: vec3<f32> = slime;
            outColor = vec4<f32>(_e303.x, _e303.y, _e303.z, 1f);
            let _e310: f32 = slimeDepth;
            gl_FragDepth = _e310;
            return;
        }
    }
    let _e311: bool = hasFluid;
    let _e313: vec4<f32> = foam;
    let _e318: bool = underwater;
    if ((!(_e311) && (_e313.w < 0.001f)) && !(_e318)) {
        {
            discard;
        }
    }
    let _e322: vec4<f32> = G.skyColor;
    ambient_4 = _e322.w;
    let _e325: vec2<f32> = uv_13;
    let _e326: vec4<f32> = textureSample(sceneColor_texture, sceneColor_sampler, _e325);
    color = _e326.xyz;
    let _e329: f32 = sceneDev;
    outDepth = _e329;
    let _e331: bool = underwater;
    if _e331 {
        {
            let _e332: bool = lavaPass;
            if _e332 {
                let _e334: vec4<f32> = G.scatter;
                let _e337: f32 = ambient_4;
                local_40 = (_e334.xyz * (1.2f + _e337));
            } else {
                let _e341: vec4<f32> = G.scatter;
                let _e343: f32 = ambient_4;
                let _e346: vec4<f32> = G.compat;
                local_40 = ((_e341.xyz * _e343) * _e346.y);
            }
            let _e350: vec3<f32> = local_40;
            deep_2 = _e350;
            let _e352: f32 = sceneDist_3;
            visible = min(_e352, 160f);
            let _e356: bool = hasFluid;
            if _e356 {
                {
                    let _e357: bool = lavaPass;
                    if _e357 {
                        let _e358: vec3<f32> = deep_2;
                        local_41 = (_e358 * 1.35f);
                    } else {
                        let _e361: vec2<f32> = uv_13;
                        let _e362: vec4<f32> = g_2;
                        let _e364: f32 = fd_9;
                        let _e365: vec3<f32> = deep_2;
                        let _e366: vec3<f32> = shadeSurfaceFromBelow(_e361, _e362.xyz, _e364, _e365);
                        local_41 = _e366;
                    }
                    let _e368: vec3<f32> = local_41;
                    color = _e368;
                    let _e369: f32 = fd_9;
                    visible = _e369;
                    let _e371: mat4x4<f32> = G.proj;
                    let _e372: vec2<f32> = uv_13;
                    let _e373: f32 = fd_9;
                    let _e374: vec3<f32> = viewPosAt(_e372, _e373);
                    clip_4 = (_e371 * vec4<f32>(_e374.x, _e374.y, _e374.z, 1f));
                    let _e382: vec4<f32> = clip_4;
                    let _e384: vec4<f32> = clip_4;
                    outDepth = (_e382.z / _e384.w);
                }
            }
            let _e388: vec4<f32> = G.scatter;
            let _e391: vec4<f32> = G.misc;
            fog = (_e388.w * _e391.x);
            let _e395: vec3<f32> = color;
            let _e397: vec4<f32> = G.absorb;
            let _e400: f32 = visible;
            let _e403: vec4<f32> = G.misc;
            let _e408: vec3<f32> = deep_2;
            let _e410: f32 = fog;
            let _e412: f32 = visible;
            color = ((_e395 * exp(((-(_e397.xyz) * _e400) * _e403.x))) + (_e408 * (1f - exp((-(_e410) * _e412)))));
        }
    } else {
        let _e418: bool = hasFluid;
        if _e418 {
            {
                let _e419: bool = lavaPass;
                if _e419 {
                    let _e420: vec2<f32> = uv_13;
                    let _e421: vec4<f32> = g_2;
                    let _e423: f32 = fd_9;
                    let _e424: f32 = ambient_4;
                    let _e425: vec3<f32> = shadeAboveLava(_e420, _e421.xyz, _e423, _e424);
                    local_42 = _e425;
                } else {
                    let _e426: vec2<f32> = uv_13;
                    let _e427: vec4<f32> = g_2;
                    let _e429: f32 = fd_9;
                    let _e430: f32 = sceneDist_3;
                    let _e431: f32 = ambient_4;
                    let _e432: vec2<f32> = surfaceLight;
                    let _e433: vec3<f32> = shadeAboveWater(_e426, _e427.xyz, _e429, _e430, _e431, _e432);
                    local_42 = _e433;
                }
                let _e435: vec3<f32> = local_42;
                color = _e435;
                let _e437: mat4x4<f32> = G.proj;
                let _e438: vec2<f32> = uv_13;
                let _e439: f32 = fd_9;
                let _e440: vec3<f32> = viewPosAt(_e438, _e439);
                clip_5 = (_e437 * vec4<f32>(_e440.x, _e440.y, _e440.z, 1f));
                let _e448: vec4<f32> = clip_5;
                let _e450: vec4<f32> = clip_5;
                outDepth = (_e448.z / _e450.w);
            }
        }
    }
    let _e453: vec4<f32> = foam;
    if (_e453.w > 0.0001f) {
        {
            let _e457: vec4<f32> = foam;
            let _e459: vec4<f32> = foam;
            foamColor = (_e457.xyz / vec3(_e459.w));
            let _e465: vec4<f32> = foam;
            let _e469: vec4<f32> = G.foamA;
            coverage_2 = min((1f - exp((-(_e465.w) * _e469.y))), 0.9f);
            let _e477: bool = hasFluid;
            let _e478: bool = underwater;
            if (_e477 && !(_e478)) {
                {
                    let _e482: vec4<f32> = G.misc;
                    let _e485: mat4x4<f32> = G.invView;
                    let _e486: vec2<f32> = uv_13;
                    let _e487: f32 = fd_9;
                    let _e488: vec3<f32> = viewPosAt(_e486, _e487);
                    world_5 = (_e482.yzw + (_e485 * vec4<f32>(_e488.x, _e488.y, _e488.z, 0f)).xyz);
                    let _e498: f32 = coverage_2;
                    let _e499: vec3<f32> = world_5;
                    let _e501: f32 = coverage_2;
                    let _e502: f32 = fd_9;
                    let _e503: f32 = pixelFootprint(_e502);
                    let _e504: f32 = foamLace(_e499.xz, _e501, _e503);
                    coverage_2 = (_e498 * _e504);
                }
            }
            let _e506: vec3<f32> = color;
            let _e507: vec3<f32> = foamColor;
            let _e510: f32 = ambient_4;
            let _e514: vec4<f32> = G.compat;
            let _e517: f32 = coverage_2;
            color = mix(_e506, ((_e507 * mix(0.25f, 1f, _e510)) * _e514.y), vec3(_e517));
        }
    }
    let _e520: vec3<f32> = color;
    outColor = vec4<f32>(_e520.x, _e520.y, _e520.z, 1f);
    let _e526: f32 = outDepth;
    gl_FragDepth = _e526;
    return;
}

@fragment
fn main(@builtin(position) gl_FragCoord: vec4<f32>) -> FragmentOutput {
    gl_FragCoord_1 = gl_FragCoord;
    main_1();
    let _e173: vec4<f32> = outColor;
    let _e175: f32 = gl_FragDepth;
    return FragmentOutput(_e173, _e175);
}
