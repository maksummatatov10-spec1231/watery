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

struct Stencil {
    base: vec3<i32>,
    fx: vec3<f32>,
    w: array<vec3<f32>, 3>,
}

struct Src {
    src: array<Particle>,
}

struct Dst {
    dst: array<Particle>,
}

struct Counters {
    counters: array<u32>,
}

struct Grid {
    grid: array<vec4<f32>>,
}

struct StateSrc {
    stateSrc: array<f32>,
}

struct StateDst {
    stateDst: array<f32>,
}

struct Static {
    staticSolid: array<u32>,
}

struct PC {
    a: vec4<i32>,
    b: vec4<i32>,
}

struct Counters_1 {
    counters: array<atomic<u32>>,
}

const FP_SCALE: f32 = 65536f;
const MASS_FP: f32 = 1048576f;
const MOM_FP: f32 = 131072f;
const OUT: array<vec3<i32>, 6> = array<vec3<i32>, 6>(vec3<i32>(0i, 1i, 0i), vec3<i32>(1i, 0i, 0i), vec3<i32>(-1i, 0i, 0i), vec3<i32>(0i, 0i, 1i), vec3<i32>(0i, 0i, -1i), vec3<i32>(0i, -1i, 0i));
const ORDER: array<i32, 3> = array<i32, 3>(1i, 0i, 2i);

@group(0) @binding(0)
var<uniform> G: Globals;
@group(0) @binding(1)
var<storage> global: Src;
@group(0) @binding(2)
var<storage, read_write> global_1: Dst;
@group(0) @binding(3)
var<storage, read_write> global_2: Counters_1;
@group(0) @binding(4)
var<storage> global_3: Grid;
@group(0) @binding(5)
var<storage> global_4: StateSrc;
@group(0) @binding(6)
var<storage, read_write> global_5: StateDst;
@group(0) @binding(7)
var<storage> global_6: Static;
@group(1) @binding(0)
var<uniform> pc: PC;
var<private> gl_GlobalInvocationID_1: vec3<u32>;
var<private> gl_NumWorkGroups_1: vec3<u32>;
var<private> gl_SubgroupInvocationID_1: u32;

fn wateryIsNan(v: vec3<f32>) -> vec3<bool> {
    var v_1: vec3<f32>;

    v_1 = v;
    let _e2: vec3<f32> = v_1;
    return ((bitcast<vec3<u32>>(_e2) & vec3(2147483647u)) > vec3(2139095040u));
}

fn wateryIsInf(v_2: vec3<f32>) -> vec3<bool> {
    var v_3: vec3<f32>;

    v_3 = v_2;
    let _e2: vec3<f32> = v_3;
    return ((bitcast<vec3<u32>>(_e2) & vec3(2147483647u)) == vec3(2139095040u));
}

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

fn clampPhi(v_4: f32, lo: f32, hi: f32) -> f32 {
    var v_5: f32;
    var lo_1: f32;
    var hi_1: f32;

    v_5 = v_4;
    lo_1 = lo;
    hi_1 = hi;
    let _e114: f32 = v_5;
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

fn unpackNormal(v_6: u32, flag_2: ptr<function, bool>) -> vec3<f32> {
    var v_7: u32;
    var e_8: vec2<f32>;
    var n_3: vec3<f32>;
    var local_18: f32;
    var local_19: f32;

    v_7 = v_6;
    let _e111: u32 = v_7;
    (*flag_2) = ((_e111 & 1073741824u) != 0u);
    let _e116: u32 = v_7;
    let _e120: u32 = v_7;
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

fn stencil(x_4: vec3<f32>) -> Stencil {
    var x_5: vec3<f32>;
    var s: Stencil;

    x_5 = x_4;
    let _e114: vec3<f32> = x_5;
    s.base = vec3<i32>(floor((_e114 - vec3(1f))));
    let _e121: vec3<f32> = x_5;
    let _e126: vec3<i32> = s.base;
    s.fx = ((_e121 - vec3(0.5f)) - vec3<f32>(_e126));
    let _e135: vec3<f32> = s.fx;
    let _e141: vec3<f32> = s.fx;
    s.w[0i] = ((0.5f * (vec3(1.5f) - _e135)) * (vec3(1.5f) - _e141));
    let _e150: vec3<f32> = s.fx;
    let _e155: vec3<f32> = s.fx;
    s.w[1i] = (vec3(0.75f) - ((_e150 - vec3(1f)) * (_e155 - vec3(1f))));
    let _e167: vec3<f32> = s.fx;
    let _e173: vec3<f32> = s.fx;
    s.w[2i] = ((0.5f * (_e167 - vec3(0.5f))) * (_e173 - vec3(0.5f)));
    let _e178: Stencil = s;
    return _e178;
}

fn jacobi(A: ptr<function, mat3x3<f32>>, V: ptr<function, mat3x3<f32>>, p_7: i32, q_1: i32) {
    var p_8: i32;
    var q_2: i32;
    var apq: f32;
    var theta: f32;
    var local_20: f32;
    var t_4: f32;
    var c_8: f32;
    var s_1: f32;
    var J: mat3x3<f32> = mat3x3<f32>(vec3<f32>(1f, 0f, 0f), vec3<f32>(0f, 1f, 0f), vec3<f32>(0f, 0f, 1f));

    p_8 = p_7;
    q_2 = q_1;
    let _e116: i32 = p_8;
    let _e117: i32 = q_2;
    let _e120: f32 = (*A)[_e117][_e116];
    apq = _e120;
    let _e122: f32 = apq;
    if (abs(_e122) < 0.000000000001f) {
        {
            return;
        }
    }
    let _e126: i32 = q_2;
    let _e127: i32 = q_2;
    let _e130: f32 = (*A)[_e127][_e126];
    let _e131: i32 = p_8;
    let _e132: i32 = p_8;
    let _e135: f32 = (*A)[_e132][_e131];
    let _e138: f32 = apq;
    theta = ((_e130 - _e135) / (2f * _e138));
    let _e142: f32 = theta;
    if (_e142 == 0f) {
        local_20 = 1f;
    } else {
        let _e146: f32 = theta;
        let _e148: f32 = theta;
        let _e150: f32 = theta;
        let _e151: f32 = theta;
        local_20 = (sign(_e146) / (abs(_e148) + sqrt(((_e150 * _e151) + 1f))));
    }
    let _e159: f32 = local_20;
    t_4 = _e159;
    let _e161: f32 = t_4;
    let _e162: f32 = t_4;
    c_8 = inverseSqrt(((_e161 * _e162) + 1f));
    let _e168: f32 = t_4;
    let _e169: f32 = c_8;
    s_1 = (_e168 * _e169);
    let _e179: i32 = p_8;
    let _e180: i32 = p_8;
    let _e183: f32 = c_8;
    J[_e180][_e179] = _e183;
    let _e184: i32 = q_2;
    let _e185: i32 = q_2;
    let _e188: f32 = c_8;
    J[_e185][_e184] = _e188;
    let _e189: i32 = p_8;
    let _e190: i32 = q_2;
    let _e193: f32 = s_1;
    J[_e190][_e189] = _e193;
    let _e194: i32 = q_2;
    let _e195: i32 = p_8;
    let _e198: f32 = s_1;
    J[_e195][_e194] = -(_e198);
    let _e200: mat3x3<f32> = J;
    let _e202: mat3x3<f32> = (*A);
    let _e204: mat3x3<f32> = J;
    (*A) = ((transpose(_e200) * _e202) * _e204);
    let _e206: mat3x3<f32> = (*V);
    let _e207: mat3x3<f32> = J;
    (*V) = (_e206 * _e207);
    return;
}

fn svd3_(F: mat3x3<f32>, U: ptr<function, mat3x3<f32>>, S: ptr<function, vec3<f32>>, V_1: ptr<function, mat3x3<f32>>) {
    var F_1: mat3x3<f32>;
    var A_1: mat3x3<f32>;
    var sweep: i32 = 0i;
    var local_21: mat3x3<f32>;
    var local_22: mat3x3<f32>;
    var local_23: mat3x3<f32>;
    var i_5: i32 = 0i;
    var local_24: i32;
    var local_25: i32;
    var local_26: i32;
    var m: i32;

    F_1 = F;
    let _e115: mat3x3<f32> = F_1;
    let _e117: mat3x3<f32> = F_1;
    A_1 = (transpose(_e115) * _e117);
    (*V_1) = mat3x3<f32>(vec3<f32>(1f, 0f, 0f), vec3<f32>(0f, 1f, 0f), vec3<f32>(0f, 0f, 1f));
    loop {
        let _e128: i32 = sweep;
        if !((_e128 < 5i)) {
            break;
        }
        {
            let _e140: mat3x3<f32> = (*V_1);
            local_21 = _e140;
            jacobi((&A_1), (&local_21), 0i, 1i);
            let _e142: mat3x3<f32> = local_21;
            (*V_1) = _e142;
            let _e148: mat3x3<f32> = (*V_1);
            local_22 = _e148;
            jacobi((&A_1), (&local_22), 0i, 2i);
            let _e150: mat3x3<f32> = local_22;
            (*V_1) = _e150;
            let _e156: mat3x3<f32> = (*V_1);
            local_23 = _e156;
            jacobi((&A_1), (&local_23), 1i, 2i);
            let _e158: mat3x3<f32> = local_23;
            (*V_1) = _e158;
        }
        continuing {
            let _e132: i32 = sweep;
            sweep = (_e132 + 1i);
        }
    }
    let _e163: f32 = A_1[0][0];
    let _e168: f32 = A_1[1][1];
    let _e173: f32 = A_1[2][2];
    (*S) = sqrt(max(vec3<f32>(_e163, _e168, _e173), vec3(0f)));
    let _e179: mat3x3<f32> = (*V_1);
    if (determinant(_e179) < 0f) {
        {
            let _e187: vec3<f32> = (*V_1)[0];
            (*V_1)[0i] = -(_e187);
        }
    }
    let _e189: mat3x3<f32> = F_1;
    let _e190: mat3x3<f32> = (*V_1);
    (*U) = (_e189 * _e190);
    loop {
        let _e194: i32 = i_5;
        if !((_e194 < 3i)) {
            break;
        }
        {
            let _e201: i32 = i_5;
            let _e203: i32 = i_5;
            let _e205: vec3<f32> = (*U)[_e203];
            let _e206: i32 = i_5;
            let _e208: f32 = (*S)[_e206];
            (*U)[_e201] = (_e205 / vec3(max(_e208, 0.00000001f)));
        }
        continuing {
            let _e198: i32 = i_5;
            i_5 = (_e198 + 1i);
        }
    }
    let _e213: mat3x3<f32> = F_1;
    if (determinant(_e213) < 0f) {
        {
            let _e217: vec3<f32> = (*S);
            let _e219: vec3<f32> = (*S);
            if (_e217.x < _e219.y) {
                let _e222: vec3<f32> = (*S);
                let _e224: vec3<f32> = (*S);
                if (_e222.x < _e224.z) {
                    local_24 = 0i;
                } else {
                    local_24 = 2i;
                }
                let _e230: i32 = local_24;
                local_26 = _e230;
            } else {
                let _e231: vec3<f32> = (*S);
                let _e233: vec3<f32> = (*S);
                if (_e231.y < _e233.z) {
                    local_25 = 1i;
                } else {
                    local_25 = 2i;
                }
                let _e239: i32 = local_25;
                local_26 = _e239;
            }
            let _e241: i32 = local_26;
            m = _e241;
            let _e243: i32 = m;
            let _e245: i32 = m;
            let _e247: f32 = (*S)[_e245];
            (*S)[_e243] = -(_e247);
            let _e249: i32 = m;
            let _e251: i32 = m;
            let _e253: vec3<f32> = (*U)[_e251];
            (*U)[_e249] = -(_e253);
            return;
        }
    } else {
        return;
    }
}

fn diag3_(d_5: vec3<f32>) -> mat3x3<f32> {
    var d_6: vec3<f32>;

    d_6 = d_5;
    let _e112: vec3<f32> = d_6;
    let _e117: vec3<f32> = d_6;
    let _e122: vec3<f32> = d_6;
    return mat3x3<f32>(vec3<f32>(_e112.x, 0f, 0f), vec3<f32>(0f, _e117.y, 0f), vec3<f32>(0f, 0f, _e122.z));
}

fn projectSand(F_2: mat3x3<f32>, squeeze: f32, tau: ptr<function, mat3x3<f32>>) -> mat3x3<f32> {
    var F_3: mat3x3<f32>;
    var squeeze_1: f32;
    var U_1: mat3x3<f32>;
    var S_1: vec3<f32>;
    var V_2: mat3x3<f32>;
    var e_9: vec3<f32>;
    var logJ: f32;
    var tr: f32;
    var eh: vec3<f32>;
    var en: f32;
    var dg: f32;
    var l_1: vec3<f32>;

    F_3 = F_2;
    squeeze_1 = squeeze;
    let _e118: mat3x3<f32> = F_3;
    svd3_(_e118, (&U_1), (&S_1), (&V_2));
    let _e125: vec3<f32> = S_1;
    e_9 = log(max(_e125, vec3(0.000001f)));
    let _e131: vec3<f32> = e_9;
    let _e133: vec3<f32> = e_9;
    let _e136: vec3<f32> = e_9;
    logJ = ((_e131.x + _e133.y) + _e136.z);
    let _e140: f32 = squeeze_1;
    let _e142: vec4<f32> = G.matC;
    let _e146: f32 = logJ;
    let _e148: vec4<f32> = G.matE;
    if ((_e140 < -(_e142.w)) && (_e146 < _e148.w)) {
        {
            let _e152: vec3<f32> = e_9;
            let _e154: vec4<f32> = G.matE;
            let _e156: f32 = logJ;
            e_9 = (_e152 + vec3(((_e154.w - _e156) / 3f)));
            let _e162: vec3<f32> = e_9;
            S_1 = exp(_e162);
        }
    }
    let _e164: vec3<f32> = e_9;
    let _e166: vec3<f32> = e_9;
    let _e169: vec3<f32> = e_9;
    let _e173: vec4<f32> = G.matA;
    tr = (((_e164.x + _e166.y) + _e169.z) - _e173.z);
    let _e177: f32 = tr;
    if (_e177 >= 0f) {
        {
            let _e181: vec4<f32> = G.matA;
            S_1 = vec3(exp((_e181.z / 3f)));
        }
    } else {
        {
            let _e187: vec3<f32> = e_9;
            let _e188: f32 = tr;
            let _e190: vec4<f32> = G.matA;
            eh = (_e187 - vec3(((_e188 + _e190.z) / 3f)));
            let _e198: vec3<f32> = eh;
            en = length(_e198);
            let _e201: f32 = en;
            let _e204: vec4<f32> = G.matB;
            let _e209: vec4<f32> = G.matB;
            let _e215: vec4<f32> = G.matB;
            let _e219: f32 = tr;
            let _e222: vec4<f32> = G.matA;
            dg = (_e201 + (((((3f * _e204.y) + (2f * _e209.x)) / (2f * _e215.x)) * _e219) * _e222.y));
            let _e227: f32 = dg;
            let _e230: f32 = en;
            if ((_e227 > 0f) && (_e230 > 0.000000000001f)) {
                {
                    let _e234: vec3<f32> = e_9;
                    let _e235: f32 = dg;
                    let _e236: vec3<f32> = eh;
                    let _e238: f32 = en;
                    S_1 = exp((_e234 - ((_e235 * _e236) / vec3(_e238))));
                }
            }
        }
    }
    let _e243: vec3<f32> = S_1;
    l_1 = log(max(_e243, vec3(0.000001f)));
    let _e249: mat3x3<f32> = U_1;
    let _e252: vec4<f32> = G.matB;
    let _e255: vec3<f32> = l_1;
    let _e258: vec4<f32> = G.matB;
    let _e260: vec3<f32> = l_1;
    let _e262: vec3<f32> = l_1;
    let _e265: vec3<f32> = l_1;
    let _e271: mat3x3<f32> = diag3_((((2f * _e252.x) * _e255) + vec3((_e258.y * ((_e260.x + _e262.y) + _e265.z)))));
    let _e273: mat3x3<f32> = U_1;
    (*tau) = ((_e249 * _e271) * transpose(_e273));
    let _e276: mat3x3<f32> = U_1;
    let _e277: vec3<f32> = S_1;
    let _e278: mat3x3<f32> = diag3_(_e277);
    let _e280: mat3x3<f32> = V_2;
    return ((_e276 * _e278) * transpose(_e280));
}

fn solidAt(p_9: vec3<f32>) -> bool {
    var p_10: vec3<f32>;
    var c_9: vec3<i32>;

    p_10 = p_9;
    let _e131: vec3<f32> = p_10;
    c_9 = vec3<i32>(floor(_e131));
    let _e135: vec3<i32> = c_9;
    let _e136: bool = inGrid(_e135);
    let _e137: vec3<i32> = c_9;
    let _e138: i32 = cellIndex(_e137);
    let _e140: u32 = global_6.staticSolid[_e138];
    return (_e136 && (_e140 != 0u));
}

fn collideStatic(x_6: vec3<f32>, xn: vec3<f32>, v_8: ptr<function, vec3<f32>>) -> vec3<f32> {
    var x_7: vec3<f32>;
    var xn_1: vec3<f32>;
    var c_10: vec3<i32>;
    var k: i32 = 0i;
    var local_27: array<vec3<i32>, 6> = OUT;
    var nc: vec3<i32>;
    var r: vec3<f32>;
    var k_1: i32 = 0i;
    var local_28: array<i32, 3> = ORDER;
    var a: i32;
    var t_5: vec3<f32>;

    x_7 = x_6;
    xn_1 = xn;
    let _e134: vec3<f32> = x_7;
    let _e135: bool = solidAt(_e134);
    if _e135 {
        {
            let _e136: vec3<f32> = x_7;
            c_10 = vec3<i32>(floor(_e136));
            loop {
                let _e171: i32 = k;
                if !((_e171 < 6i)) {
                    break;
                }
                {
                    let _e178: vec3<i32> = c_10;
                    let _e179: i32 = k;
                    let _e183: vec3<i32> = local_27[_e179];
                    nc = (_e178 + _e183);
                    let _e186: vec3<i32> = nc;
                    let _e187: bool = inGrid(_e186);
                    let _e189: vec3<i32> = nc;
                    let _e190: i32 = cellIndex(_e189);
                    let _e192: u32 = global_6.staticSolid[_e190];
                    if (!(_e187) || (_e192 == 0u)) {
                        {
                            (*v_8) = vec3(0f);
                            let _e198: vec3<i32> = nc;
                            return (vec3<f32>(_e198) + vec3(0.5f));
                        }
                    }
                }
                continuing {
                    let _e175: i32 = k;
                    k = (_e175 + 1i);
                }
            }
            let _e203: vec3<f32> = x_7;
            return _e203;
        }
    }
    let _e204: vec3<f32> = x_7;
    r = _e204;
    loop {
        let _e213: i32 = k_1;
        if !((_e213 < 3i)) {
            break;
        }
        {
            let _e220: i32 = k_1;
            let _e224: i32 = local_28[_e220];
            a = _e224;
            let _e226: vec3<f32> = r;
            t_5 = _e226;
            let _e228: i32 = a;
            let _e230: i32 = a;
            let _e232: f32 = xn_1[_e230];
            t_5[_e228] = _e232;
            let _e233: vec3<f32> = t_5;
            let _e234: bool = solidAt(_e233);
            if !(_e234) {
                {
                    let _e236: vec3<f32> = t_5;
                    r = _e236;
                }
            } else {
                {
                    let _e237: i32 = a;
                    (*v_8)[_e237] = 0f;
                }
            }
        }
        continuing {
            let _e217: i32 = k_1;
            k_1 = (_e217 + 1i);
        }
    }
    let _e240: vec3<f32> = r;
    return _e240;
}

fn collideEntities(x_8: vec3<f32>, v_9: ptr<function, vec3<f32>>) -> vec3<f32> {
    var x_9: vec3<f32>;
    var e_10: i32 = 0i;
    var lo_2: vec3<f32>;
    var hi_2: vec3<f32>;
    var dLo: vec3<f32>;
    var dHi: vec3<f32>;
    var ve: vec3<f32>;
    var axis: i32;
    var best: f32;
    var dir: f32;
    var a_1: i32;
    var local_29: f32;

    x_9 = x_8;
    loop {
        let _e134: i32 = e_10;
        let _e135: i32 = numEntities();
        if !((_e134 < _e135)) {
            break;
        }
        {
            let _e141: i32 = e_10;
            let _e142: vec3<f32> = entMin(_e141);
            lo_2 = _e142;
            let _e144: i32 = e_10;
            let _e145: vec3<f32> = entMax(_e144);
            hi_2 = _e145;
            let _e147: vec3<f32> = x_9;
            let _e148: vec3<f32> = lo_2;
            let _e151: vec3<f32> = x_9;
            let _e152: vec3<f32> = hi_2;
            if (any((_e147 < _e148)) || any((_e151 > _e152))) {
                {
                    continue;
                }
            }
            let _e156: vec3<f32> = x_9;
            let _e157: vec3<f32> = lo_2;
            dLo = (_e156 - _e157);
            let _e160: vec3<f32> = hi_2;
            let _e161: vec3<f32> = x_9;
            dHi = (_e160 - _e161);
            let _e164: i32 = e_10;
            let _e165: vec3<f32> = entVel(_e164);
            ve = _e165;
            axis = 0i;
            best = 1000000000f;
            dir = 1f;
            a_1 = 0i;
            loop {
                let _e175: i32 = a_1;
                if !((_e175 < 3i)) {
                    break;
                }
                {
                    let _e182: i32 = a_1;
                    let _e184: f32 = dLo[_e182];
                    let _e185: f32 = best;
                    if (_e184 < _e185) {
                        {
                            let _e187: i32 = a_1;
                            let _e189: f32 = dLo[_e187];
                            best = _e189;
                            let _e190: i32 = a_1;
                            axis = _e190;
                            dir = -1f;
                        }
                    }
                    let _e193: i32 = a_1;
                    let _e195: f32 = dHi[_e193];
                    let _e196: f32 = best;
                    if (_e195 < _e196) {
                        {
                            let _e198: i32 = a_1;
                            let _e200: f32 = dHi[_e198];
                            best = _e200;
                            let _e201: i32 = a_1;
                            axis = _e201;
                            dir = 1f;
                        }
                    }
                }
                continuing {
                    let _e179: i32 = a_1;
                    a_1 = (_e179 + 1i);
                }
            }
            let _e203: i32 = axis;
            let _e205: f32 = dir;
            if (_e205 > 0f) {
                let _e208: i32 = axis;
                let _e210: f32 = hi_2[_e208];
                local_29 = (_e210 + 0.01f);
            } else {
                let _e213: i32 = axis;
                let _e215: f32 = lo_2[_e213];
                local_29 = (_e215 - 0.01f);
            }
            let _e219: f32 = local_29;
            x_9[_e203] = _e219;
            let _e220: i32 = axis;
            let _e222: f32 = dir;
            let _e223: f32 = dir;
            let _e224: i32 = axis;
            let _e226: f32 = (*v_9)[_e224];
            let _e228: f32 = dir;
            let _e229: i32 = axis;
            let _e231: f32 = ve[_e229];
            (*v_9)[_e220] = (_e222 * max((_e223 * _e226), (_e228 * _e231)));
        }
        continuing {
            let _e138: i32 = e_10;
            e_10 = (_e138 + 1i);
        }
    }
    let _e235: vec3<f32> = x_9;
    return _e235;
}

fn main_1() {
    var i_6: u32;
    var p_11: Particle;
    var x_10: vec3<f32>;
    var si: i32;
    var valid: bool;
    var local_30: mat3x3<f32>;
    var F_4: mat3x3<f32>;
    var tau6_: array<f32, 6> = array<f32, 6>(0f, 0f, 0f, 0f, 0f, 0f);
    var rest: f32 = 0f;
    var k_2: i32 = 0i;
    var v_10: vec3<f32>;
    var C: mat3x3<f32> = mat3x3<f32>(vec3<f32>(0f, 0f, 0f), vec3<f32>(0f, 0f, 0f), vec3<f32>(0f, 0f, 0f));
    var spread: f32;
    var asleep: bool = false;
    var density: f32 = 0f;
    var s_2: Stencil;
    var k_3: i32 = 0i;
    var j: i32;
    var ii: i32;
    var c_11: vec3<i32>;
    var w: f32;
    var g: vec4<f32>;
    var dpos: vec3<f32>;
    var local_31: f32;
    var local_32: f32;
    var tau_1: mat3x3<f32>;
    var maxSpeed: f32;
    var sp: f32;
    var local_33: vec3<f32>;
    var xn_2: vec3<f32>;
    var pushed: vec3<f32>;
    var killMargin: f32;
    var groupTotal: u32;
    var prefix: u32;
    var groupMax: f32;
    var local_34: u32;
    var groupAwake: u32;
    var base: u32 = 0u;
    var o: u32;
    var so: i32;
    var c_12: i32 = 0i;
    var r_1: i32;
    var k_4: i32 = 0i;
    var cell: vec3<u32>;
    var lo_3: vec3<u32>;
    var hi_3: vec3<u32>;

    let _e131: vec3<u32> = gl_GlobalInvocationID_1;
    let _e133: vec3<u32> = gl_GlobalInvocationID_1;
    let _e135: vec3<u32> = gl_NumWorkGroups_1;
    i_6 = (_e131.x + ((_e133.y * _e135.x) * 256u));
    let _e142: u32 = i_6;
    let _e144: vec4<i32> = pc.a;
    let _e147: u32 = atomicLoad((&global_2.counters[_e144.x]));
    if (_e142 >= _e147) {
        {
            return;
        }
    }
    let _e149: u32 = i_6;
    let _e151: Particle = global.src[_e149];
    p_11 = _e151;
    let _e154: vec4<f32> = p_11.pos;
    if (_e154.w < 0f) {
        {
            return;
        }
    }
    let _e159: vec4<f32> = p_11.pos;
    x_10 = _e159.xyz;
    let _e162: u32 = i_6;
    si = (i32(_e162) * 28i);
    let _e168: vec4<f32> = p_11.pos;
    valid = (_e168.w >= 0.5f);
    let _e173: bool = valid;
    if _e173 {
        let _e174: i32 = si;
        let _e178: f32 = global_4.stateSrc[(_e174 + 9i)];
        let _e179: i32 = si;
        let _e185: f32 = global_4.stateSrc[((_e179 + 9i) + 1i)];
        let _e186: i32 = si;
        let _e192: f32 = global_4.stateSrc[((_e186 + 9i) + 2i)];
        let _e193: i32 = si;
        let _e199: f32 = global_4.stateSrc[((_e193 + 9i) + 3i)];
        let _e200: i32 = si;
        let _e206: f32 = global_4.stateSrc[((_e200 + 9i) + 4i)];
        let _e207: i32 = si;
        let _e213: f32 = global_4.stateSrc[((_e207 + 9i) + 5i)];
        let _e214: i32 = si;
        let _e220: f32 = global_4.stateSrc[((_e214 + 9i) + 6i)];
        let _e221: i32 = si;
        let _e227: f32 = global_4.stateSrc[((_e221 + 9i) + 7i)];
        let _e228: i32 = si;
        let _e234: f32 = global_4.stateSrc[((_e228 + 9i) + 8i)];
        local_30 = mat3x3<f32>(vec3<f32>(_e178, _e185, _e192), vec3<f32>(_e199, _e206, _e213), vec3<f32>(_e220, _e227, _e234));
    } else {
        local_30 = mat3x3<f32>(vec3<f32>(1f, 0f, 0f), vec3<f32>(0f, 1f, 0f), vec3<f32>(0f, 0f, 1f));
    }
    let _e246: mat3x3<f32> = local_30;
    F_4 = _e246;
    let _e258: bool = valid;
    if _e258 {
        {
            loop {
                let _e261: i32 = k_2;
                if !((_e261 < 6i)) {
                    break;
                }
                {
                    let _e268: i32 = k_2;
                    let _e270: i32 = si;
                    let _e273: i32 = k_2;
                    let _e276: f32 = global_4.stateSrc[((_e270 + 18i) + _e273)];
                    tau6_[_e268] = _e276;
                }
                continuing {
                    let _e265: i32 = k_2;
                    k_2 = (_e265 + 1i);
                }
            }
            let _e277: i32 = si;
            let _e281: f32 = global_4.stateSrc[(_e277 + 24i)];
            rest = _e281;
        }
    }
    let _e291: vec4<f32> = p_11.pos;
    spread = max(_e291.w, 1f);
    let _e298: vec3<f32> = x_10;
    let _e299: bool = inInnerBox(_e298);
    if _e299 {
        {
            v_10 = vec3(0f);
            let _e304: vec3<f32> = x_10;
            let _e305: Stencil = stencil(_e304);
            s_2 = _e305;
            loop {
                let _e309: i32 = k_3;
                if !((_e309 < 3i)) {
                    break;
                }
                {
                    j = 0i;
                    loop {
                        let _e318: i32 = j;
                        if !((_e318 < 3i)) {
                            break;
                        }
                        {
                            ii = 0i;
                            loop {
                                let _e327: i32 = ii;
                                if !((_e327 < 3i)) {
                                    break;
                                }
                                {
                                    let _e335: vec3<i32> = s_2.base;
                                    let _e336: i32 = ii;
                                    let _e337: i32 = j;
                                    let _e338: i32 = k_3;
                                    c_11 = (_e335 + vec3<i32>(_e336, _e337, _e338));
                                    let _e342: i32 = ii;
                                    let _e345: vec3<f32> = s_2.w[_e342];
                                    let _e347: i32 = j;
                                    let _e350: vec3<f32> = s_2.w[_e347];
                                    let _e353: i32 = k_3;
                                    let _e356: vec3<f32> = s_2.w[_e353];
                                    w = ((_e345.x * _e350.y) * _e356.z);
                                    let _e360: vec3<i32> = c_11;
                                    let _e361: i32 = cellIndex(_e360);
                                    let _e363: vec4<f32> = global_3.grid[_e361];
                                    g = _e363;
                                    let _e365: i32 = ii;
                                    let _e366: i32 = j;
                                    let _e367: i32 = k_3;
                                    let _e373: vec3<f32> = s_2.fx;
                                    dpos = (vec3<f32>(f32(_e365), f32(_e366), f32(_e367)) - _e373);
                                    let _e376: vec3<f32> = v_10;
                                    let _e377: f32 = w;
                                    let _e378: vec4<f32> = g;
                                    v_10 = (_e376 + (_e377 * _e378.xyz));
                                    let _e382: mat3x3<f32> = C;
                                    let _e384: f32 = w;
                                    let _e386: vec4<f32> = g;
                                    let _e388: vec3<f32> = dpos;
                                    let _e390: vec3<f32> = (_e386.xyz * _e388.x);
                                    let _e391: vec4<f32> = g;
                                    let _e393: vec3<f32> = dpos;
                                    let _e395: vec3<f32> = (_e391.xyz * _e393.y);
                                    let _e396: vec4<f32> = g;
                                    let _e398: vec3<f32> = dpos;
                                    let _e400: vec3<f32> = (_e396.xyz * _e398.z);
                                    C = (_e382 + ((4f * _e384) * mat3x3<f32>(vec3<f32>(_e390.x, _e390.y, _e390.z), vec3<f32>(_e395.x, _e395.y, _e395.z), vec3<f32>(_e400.x, _e400.y, _e400.z))));
                                    let _e416: f32 = density;
                                    let _e417: f32 = w;
                                    let _e418: vec4<f32> = g;
                                    density = (_e416 + (_e417 * _e418.w));
                                }
                                continuing {
                                    let _e331: i32 = ii;
                                    ii = (_e331 + 1i);
                                }
                            }
                        }
                        continuing {
                            let _e322: i32 = j;
                            j = (_e322 + 1i);
                        }
                    }
                }
                continuing {
                    let _e313: i32 = k_3;
                    k_3 = (_e313 + 1i);
                }
            }
            let _e422: f32 = rest;
            let _e424: vec4<f32> = G.matE;
            if (_e422 >= _e424.y) {
                {
                    let _e427: vec3<f32> = v_10;
                    let _e430: vec4<f32> = G.matE;
                    if (length(_e427) > _e430.z) {
                        local_31 = 0f;
                    } else {
                        let _e434: f32 = rest;
                        local_31 = _e434;
                    }
                    let _e436: f32 = local_31;
                    rest = _e436;
                }
            } else {
                {
                    let _e437: vec3<f32> = v_10;
                    let _e440: vec4<f32> = G.matE;
                    if (length(_e437) < _e440.x) {
                        let _e443: f32 = rest;
                        let _e445: vec4<f32> = G.gravityDt;
                        local_32 = (_e443 + _e445.w);
                    } else {
                        local_32 = 0f;
                    }
                    let _e450: f32 = local_32;
                    rest = _e450;
                }
            }
            let _e451: f32 = rest;
            let _e453: vec4<f32> = G.matE;
            asleep = (_e451 >= _e453.y);
            let _e456: bool = asleep;
            if _e456 {
                {
                    v_10 = vec3(0f);
                    C = mat3x3<f32>(vec3<f32>(0f, 0f, 0f), vec3<f32>(0f, 0f, 0f), vec3<f32>(0f, 0f, 0f));
                }
            } else {
                {
                    let _e473: vec4<f32> = G.gravityDt;
                    let _e475: mat3x3<f32> = C;
                    let _e478: mat3x3<f32> = F_4;
                    let _e484: f32 = C[0][0];
                    let _e489: f32 = C[1][1];
                    let _e495: f32 = C[2][2];
                    let _e499: mat3x3<f32> = projectSand(((mat3x3<f32>(vec3<f32>(1f, 0f, 0f), vec3<f32>(0f, 1f, 0f), vec3<f32>(0f, 0f, 1f)) + (_e473.w * _e475)) * _e478), ((_e484 + _e489) + _e495), (&tau_1));
                    F_4 = _e499;
                    let _e504: f32 = tau_1[0][0];
                    let _e509: f32 = tau_1[1][1];
                    let _e514: f32 = tau_1[2][2];
                    let _e519: f32 = tau_1[1][0];
                    let _e524: f32 = tau_1[2][0];
                    let _e529: f32 = tau_1[2][1];
                    tau6_ = array<f32, 6>(_e504, _e509, _e514, _e519, _e524, _e529);
                    let _e532: f32 = density;
                    let _e534: vec4<f32> = G.matC;
                    spread = clamp(sqrt((1f / max((_e532 * _e534.y), 0.05f))), 1f, 3f);
                }
            }
        }
    } else {
        {
            let _e545: vec4<f32> = p_11.vel;
            let _e548: vec4<f32> = G.gravityDt;
            let _e551: vec4<f32> = G.gravityDt;
            v_10 = (_e545.xyz + (_e548.xyz * _e551.w));
            rest = 0f;
        }
    }
    let _e557: vec4<f32> = G.simB;
    maxSpeed = _e557.x;
    let _e560: vec3<f32> = v_10;
    sp = length(_e560);
    let _e563: f32 = sp;
    let _e564: f32 = maxSpeed;
    if (_e563 > _e564) {
        {
            let _e566: vec3<f32> = v_10;
            let _e567: f32 = maxSpeed;
            let _e568: f32 = sp;
            v_10 = (_e566 * (_e567 / _e568));
        }
    }
    let _e571: bool = asleep;
    if _e571 {
        let _e572: vec3<f32> = x_10;
        local_33 = _e572;
    } else {
        let _e573: vec3<f32> = x_10;
        let _e574: vec3<f32> = x_10;
        let _e576: vec4<f32> = G.gravityDt;
        let _e578: vec3<f32> = v_10;
        let _e583: vec3<f32> = collideStatic(_e573, (_e574 + (_e576.w * _e578)), (&v_10));
        local_33 = _e583;
    }
    let _e585: vec3<f32> = local_33;
    xn_2 = _e585;
    let _e587: vec3<f32> = xn_2;
    let _e590: vec3<f32> = collideEntities(_e587, (&v_10));
    pushed = _e590;
    let _e592: vec3<f32> = pushed;
    let _e593: vec3<f32> = xn_2;
    if any((_e592 != _e593)) {
        {
            rest = 0f;
            asleep = false;
        }
    }
    let _e598: vec3<f32> = pushed;
    xn_2 = _e598;
    let _e599: vec3<f32> = xn_2;
    let _e600: vec3<bool> = wateryIsNan(_e599);
    let _e602: vec3<f32> = xn_2;
    let _e603: vec3<bool> = wateryIsInf(_e602);
    let _e606: vec3<f32> = v_10;
    let _e607: vec3<bool> = wateryIsNan(_e606);
    let _e612: vec3<f32> = F_4[0];
    let _e613: vec3<bool> = wateryIsNan(_e612);
    let _e618: vec3<f32> = F_4[1];
    let _e619: vec3<bool> = wateryIsNan(_e618);
    let _e624: vec3<f32> = F_4[2];
    let _e625: vec3<bool> = wateryIsNan(_e624);
    if (((((any(_e600) || any(_e603)) || any(_e607)) || any(_e613)) || any(_e619)) || any(_e625)) {
        {
            return;
        }
    }
    let _e629: vec4<f32> = G.killInfo;
    killMargin = _e629.y;
    let _e632: vec3<f32> = xn_2;
    let _e633: f32 = killMargin;
    let _e638: vec3<f32> = xn_2;
    let _e640: vec4<i32> = G.dims;
    let _e643: vec4<i32> = G.dims;
    let _e646: vec4<i32> = G.dims;
    let _e652: f32 = killMargin;
    let _e658: vec3<f32> = xn_2;
    let _e661: vec4<f32> = G.killInfo;
    if ((any((_e632 < vec3(-(_e633)))) || any((_e638 >= (vec3<f32>(f32(_e640.x), f32(_e643.y), f32(_e646.z)) + vec3(_e652))))) || (_e658.y < _e661.x)) {
        {
            return;
        }
    }
    let _e666: u32 = subgroupAdd(1u);
    groupTotal = _e666;
    let _e669: u32 = subgroupExclusiveAdd(1u);
    prefix = _e669;
    let _e671: vec3<f32> = v_10;
    let _e673: f32 = subgroupMax(length(_e671));
    groupMax = _e673;
    let _e675: bool = asleep;
    if _e675 {
        local_34 = 0u;
    } else {
        local_34 = 1u;
    }
    let _e679: u32 = local_34;
    let _e680: u32 = subgroupAdd(_e679);
    groupAwake = _e680;
    let _e685: u32 = gl_SubgroupInvocationID_1;
    let _e686: u32 = gl_SubgroupInvocationID_1;
    let _e687: u32 = subgroupBroadcastFirst(_e686);
    if (_e685 == _e687) {
        {
            let _e690: vec4<i32> = pc.a;
            let _e694: u32 = groupTotal;
            let _e696: vec4<i32> = pc.a;
            let _e699: u32 = atomicAdd((&global_2.counters[_e696.y]), _e694);
            base = _e699;
            let _e703: f32 = groupMax;
            let _e707: u32 = atomicMax((&global_2.counters[6i]), bitcast<u32>(_e703));
            let _e711: u32 = groupAwake;
            let _e714: u32 = atomicAdd((&global_2.counters[14i]), _e711);
        }
    }
    let _e715: u32 = base;
    let _e716: u32 = subgroupBroadcastFirst(_e715);
    let _e717: u32 = prefix;
    o = (_e716 + _e717);
    let _e720: u32 = o;
    let _e722: vec4<i32> = G.caps;
    if (_e720 >= u32(_e722.x)) {
        {
            return;
        }
    }
    let _e726: u32 = o;
    let _e728: vec3<f32> = xn_2;
    let _e729: f32 = spread;
    let _e734: vec3<f32> = v_10;
    let _e736: vec4<f32> = p_11.vel;
    global_1.dst[_e726] = Particle(vec4<f32>(_e728.x, _e728.y, _e728.z, _e729), vec4<f32>(_e734.x, _e734.y, _e734.z, _e736.w));
    let _e743: u32 = o;
    so = (i32(_e743) * 28i);
    loop {
        let _e750: i32 = c_12;
        if !((_e750 < 3i)) {
            break;
        }
        {
            r_1 = 0i;
            loop {
                let _e759: i32 = r_1;
                if !((_e759 < 3i)) {
                    break;
                }
                {
                    let _e766: i32 = so;
                    let _e768: i32 = c_12;
                    let _e771: i32 = r_1;
                    let _e774: i32 = r_1;
                    let _e775: i32 = c_12;
                    let _e778: f32 = C[_e775][_e774];
                    global_5.stateDst[((_e766 + (3i * _e768)) + _e771)] = _e778;
                    let _e779: i32 = so;
                    let _e783: i32 = c_12;
                    let _e786: i32 = r_1;
                    let _e789: i32 = r_1;
                    let _e790: i32 = c_12;
                    let _e793: f32 = F_4[_e790][_e789];
                    global_5.stateDst[(((_e779 + 9i) + (3i * _e783)) + _e786)] = _e793;
                }
                continuing {
                    let _e763: i32 = r_1;
                    r_1 = (_e763 + 1i);
                }
            }
        }
        continuing {
            let _e754: i32 = c_12;
            c_12 = (_e754 + 1i);
        }
    }
    loop {
        let _e796: i32 = k_4;
        if !((_e796 < 6i)) {
            break;
        }
        {
            let _e803: i32 = so;
            let _e806: i32 = k_4;
            let _e809: i32 = k_4;
            let _e811: f32 = tau6_[_e809];
            global_5.stateDst[((_e803 + 18i) + _e806)] = _e811;
        }
        continuing {
            let _e800: i32 = k_4;
            k_4 = (_e800 + 1i);
        }
    }
    let _e812: i32 = so;
    let _e816: f32 = rest;
    global_5.stateDst[(_e812 + 24i)] = _e816;
    let _e817: vec3<f32> = xn_2;
    cell = vec3<u32>((vec3<i32>(floor(_e817)) + vec3(1048576i)));
    let _e825: vec3<u32> = cell;
    let _e827: u32 = subgroupMin(_e825.x);
    let _e828: vec3<u32> = cell;
    let _e830: u32 = subgroupMin(_e828.y);
    let _e831: vec3<u32> = cell;
    let _e833: u32 = subgroupMin(_e831.z);
    lo_3 = vec3<u32>(_e827, _e830, _e833);
    let _e836: vec3<u32> = cell;
    let _e838: u32 = subgroupMax(_e836.x);
    let _e839: vec3<u32> = cell;
    let _e841: u32 = subgroupMax(_e839.y);
    let _e842: vec3<u32> = cell;
    let _e844: u32 = subgroupMax(_e842.z);
    hi_3 = vec3<u32>(_e838, _e841, _e844);
    let _e847: u32 = gl_SubgroupInvocationID_1;
    let _e848: u32 = gl_SubgroupInvocationID_1;
    let _e849: u32 = subgroupBroadcastFirst(_e848);
    if (_e847 == _e849) {
        {
            let _e854: vec3<u32> = lo_3;
            let _e858: u32 = atomicMin((&global_2.counters[8i]), _e854.x);
            let _e862: vec3<u32> = lo_3;
            let _e866: u32 = atomicMin((&global_2.counters[9i]), _e862.y);
            let _e870: vec3<u32> = lo_3;
            let _e874: u32 = atomicMin((&global_2.counters[10i]), _e870.z);
            let _e878: vec3<u32> = hi_3;
            let _e882: u32 = atomicMax((&global_2.counters[11i]), _e878.x);
            let _e886: vec3<u32> = hi_3;
            let _e890: u32 = atomicMax((&global_2.counters[12i]), _e886.y);
            let _e894: vec3<u32> = hi_3;
            let _e898: u32 = atomicMax((&global_2.counters[13i]), _e894.z);
            return;
        }
    } else {
        return;
    }
}

@compute @workgroup_size(256, 1, 1)
fn main(@builtin(global_invocation_id) gl_GlobalInvocationID: vec3<u32>, @builtin(num_workgroups) gl_NumWorkGroups: vec3<u32>, @builtin(subgroup_invocation_id) gl_SubgroupInvocationID: u32) {
    gl_GlobalInvocationID_1 = gl_GlobalInvocationID;
    gl_NumWorkGroups_1 = gl_NumWorkGroups;
    gl_SubgroupInvocationID_1 = gl_SubgroupInvocationID;
    main_1();
    return;
}
