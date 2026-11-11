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

struct MgFlags {
    mgFlags: array<u32>,
}

struct B0_ {
    b0_: array<f32>,
}

struct X0_ {
    x0_: array<f32>,
}

struct MgB {
    mgB: array<f32>,
}

struct MgX {
    mgX: array<f32>,
}

struct Flags {
    cellFlags: array<u32>,
}

struct Div {
    div: array<f32>,
}

struct Pressure {
    pressure: array<f32>,
}

struct P {
    p: array<f32>,
}

struct Q {
    q: array<f32>,
}

struct PC {
    a: vec4<i32>,
    b: vec4<i32>,
}

const FP_SCALE: f32 = 65536f;
const NB: array<vec3<i32>, 6> = array<vec3<i32>, 6>(vec3<i32>(1i, 0i, 0i), vec3<i32>(-1i, 0i, 0i), vec3<i32>(0i, 1i, 0i), vec3<i32>(0i, -1i, 0i), vec3<i32>(0i, 0i, 1i), vec3<i32>(0i, 0i, -1i));

@group(0) @binding(0)
var<uniform> G: Globals;
@group(0) @binding(1)
var<storage, read_write> global: MgFlags;
@group(0) @binding(2)
var<storage, read_write> global_1: B0_;
@group(0) @binding(3)
var<storage, read_write> global_2: X0_;
@group(0) @binding(4)
var<storage, read_write> global_3: MgB;
@group(0) @binding(5)
var<storage, read_write> global_4: MgX;
@group(0) @binding(6)
var<storage> global_5: Flags;
@group(0) @binding(7)
var<storage> global_6: Div;
@group(0) @binding(8)
var<storage, read_write> global_7: Pressure;
@group(0) @binding(9)
var<storage, read_write> global_8: P;
@group(0) @binding(10)
var<storage, read_write> global_9: Q;
@group(1) @binding(0)
var<uniform> pc: PC;
var<private> gl_LocalInvocationID_1: vec3<u32>;
var<workgroup> partial: array<f32, 1024>;

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

fn levelDims(l_1: i32) -> vec4<i32> {
    var l_2: i32;
    var d_5: vec3<i32>;
    var offset: i32 = 0i;
    var k: i32 = 0i;

    l_2 = l_1;
    let _e137: vec4<i32> = G.dims;
    d_5 = _e137.xyz;
    loop {
        let _e144: i32 = k;
        let _e145: i32 = l_2;
        if !((_e144 < _e145)) {
            break;
        }
        {
            let _e151: i32 = offset;
            let _e152: vec3<i32> = d_5;
            let _e154: vec3<i32> = d_5;
            let _e157: vec3<i32> = d_5;
            offset = (_e151 + ((_e152.x * _e154.y) * _e157.z));
            let _e161: vec3<i32> = d_5;
            d_5 = ((_e161 + vec3(1i)) / vec3(2i));
        }
        continuing {
            let _e148: i32 = k;
            k = (_e148 + 1i);
        }
    }
    let _e168: vec3<i32> = d_5;
    let _e169: i32 = offset;
    return vec4<i32>(_e168.x, _e168.y, _e168.z, _e169);
}

fn idx(c_8: vec3<i32>, d_6: vec4<i32>) -> i32 {
    var c_9: vec3<i32>;
    var d_7: vec4<i32>;

    c_9 = c_8;
    d_7 = d_6;
    let _e138: vec4<i32> = d_7;
    let _e140: vec3<i32> = c_9;
    let _e143: vec4<i32> = d_7;
    let _e145: vec3<i32> = c_9;
    let _e147: vec4<i32> = d_7;
    let _e149: vec3<i32> = c_9;
    return ((_e138.w + _e140.x) + (_e143.x * (_e145.y + (_e147.y * _e149.z))));
}

fn boxLo(l_3: i32) -> vec3<i32> {
    var l_4: i32;

    l_4 = l_3;
    let _e137: vec4<i32> = G.boxMin;
    let _e139: i32 = l_4;
    return (_e137.xyz >> vec3(u32(_e139)));
}

fn boxHi(l_5: i32, d_8: vec4<i32>) -> vec3<i32> {
    var l_6: i32;
    var d_9: vec4<i32>;

    l_6 = l_5;
    d_9 = d_8;
    let _e139: vec4<i32> = G.boxMax;
    let _e142: i32 = l_6;
    let _e149: i32 = l_6;
    let _e153: vec4<i32> = d_9;
    return min(((_e139.xyz + vec3(((1i << u32(_e142)) - 1i))) >> vec3(u32(_e149))), _e153.xyz);
}

fn inLevel(c_10: vec3<i32>, d_10: vec4<i32>, l_7: i32) -> bool {
    var c_11: vec3<i32>;
    var d_11: vec4<i32>;
    var l_8: i32;

    c_11 = c_10;
    d_11 = d_10;
    l_8 = l_7;
    let _e140: vec3<i32> = c_11;
    let _e141: i32 = l_8;
    let _e142: vec3<i32> = boxLo(_e141);
    let _e145: vec3<i32> = c_11;
    let _e146: i32 = l_8;
    let _e147: vec4<i32> = d_11;
    let _e148: vec3<i32> = boxHi(_e146, _e147);
    return (all((_e140 >= _e142)) && all((_e145 < _e148)));
}

fn boxCount(d_12: vec4<i32>, l_9: i32) -> i32 {
    var d_13: vec4<i32>;
    var l_10: i32;
    var s: vec3<i32>;

    d_13 = d_12;
    l_10 = l_9;
    let _e138: i32 = l_10;
    let _e139: vec4<i32> = d_13;
    let _e140: vec3<i32> = boxHi(_e138, _e139);
    let _e141: i32 = l_10;
    let _e142: vec3<i32> = boxLo(_e141);
    s = max((_e140 - _e142), vec3(0i));
    let _e148: vec3<i32> = s;
    let _e150: vec3<i32> = s;
    let _e153: vec3<i32> = s;
    return ((_e148.x * _e150.y) * _e153.z);
}

fn boxCellOf(t_4: i32, d_14: vec4<i32>, l_11: i32) -> vec3<i32> {
    var t_5: i32;
    var d_15: vec4<i32>;
    var l_12: i32;
    var s_1: vec3<i32>;

    t_5 = t_4;
    d_15 = d_14;
    l_12 = l_11;
    let _e140: i32 = l_12;
    let _e141: vec4<i32> = d_15;
    let _e142: vec3<i32> = boxHi(_e140, _e141);
    let _e143: i32 = l_12;
    let _e144: vec3<i32> = boxLo(_e143);
    s_1 = (_e142 - _e144);
    let _e147: i32 = l_12;
    let _e148: vec3<i32> = boxLo(_e147);
    let _e149: i32 = t_5;
    let _e150: vec3<i32> = s_1;
    let _e153: i32 = t_5;
    let _e154: vec3<i32> = s_1;
    let _e157: vec3<i32> = s_1;
    let _e160: i32 = t_5;
    let _e161: vec3<i32> = s_1;
    let _e163: vec3<i32> = s_1;
    return (_e148 + vec3<i32>((_e149 % _e150.x), ((_e153 / _e154.x) % _e157.y), (_e160 / (_e161.x * _e163.y))));
}

fn bAt(l_13: i32, i_5: i32) -> f32 {
    var l_14: i32;
    var i_6: i32;
    var local_20: f32;

    l_14 = l_13;
    i_6 = i_5;
    let _e138: i32 = l_14;
    if (_e138 == 0i) {
        let _e141: i32 = i_6;
        let _e143: f32 = global_1.b0_[_e141];
        local_20 = _e143;
    } else {
        let _e144: i32 = i_6;
        let _e146: f32 = global_3.mgB[_e144];
        local_20 = _e146;
    }
    let _e148: f32 = local_20;
    return _e148;
}

fn xAt(l_15: i32, i_7: i32) -> f32 {
    var l_16: i32;
    var i_8: i32;
    var local_21: f32;

    l_16 = l_15;
    i_8 = i_7;
    let _e138: i32 = l_16;
    if (_e138 == 0i) {
        let _e141: i32 = i_8;
        let _e143: f32 = global_2.x0_[_e141];
        local_21 = _e143;
    } else {
        let _e144: i32 = i_8;
        let _e146: f32 = global_4.mgX[_e144];
        local_21 = _e146;
    }
    let _e148: f32 = local_21;
    return _e148;
}

fn setX(l_17: i32, i_9: i32, v_4: f32) {
    var l_18: i32;
    var i_10: i32;
    var v_5: f32;

    l_18 = l_17;
    i_10 = i_9;
    v_5 = v_4;
    let _e140: i32 = l_18;
    if (_e140 == 0i) {
        {
            let _e143: i32 = i_10;
            let _e145: f32 = v_5;
            global_2.x0_[_e143] = _e145;
            return;
        }
    } else {
        {
            let _e146: i32 = i_10;
            let _e148: f32 = v_5;
            global_4.mgX[_e146] = _e148;
            return;
        }
    }
}

fn sync() {
    storageBarrier();
    storageBarrier();
    workgroupBarrier();
    textureBarrier();
    return;
}

fn applyA(c_12: vec3<i32>, i_11: i32, d_16: vec4<i32>, l_19: i32) -> f32 {
    var c_13: vec3<i32>;
    var i_12: i32;
    var d_17: vec4<i32>;
    var l_20: i32;
    var s_2: f32 = 0f;
    var n_4: f32 = 0f;
    var k_1: i32 = 0i;
    var local_22: array<vec3<i32>, 6> = NB;
    var nb: vec3<i32>;
    var j: i32;
    var t_6: u32;

    c_13 = c_12;
    i_12 = i_11;
    d_17 = d_16;
    l_20 = l_19;
    loop {
        let _e148: i32 = k_1;
        if !((_e148 < 6i)) {
            break;
        }
        {
            let _e155: vec3<i32> = c_13;
            let _e156: i32 = k_1;
            let _e160: vec3<i32> = local_22[_e156];
            nb = (_e155 + _e160);
            let _e163: vec3<i32> = nb;
            let _e164: vec4<i32> = d_17;
            let _e165: i32 = l_20;
            let _e166: bool = inLevel(_e163, _e164, _e165);
            if !(_e166) {
                {
                    let _e168: f32 = n_4;
                    n_4 = (_e168 + 1f);
                    continue;
                }
            }
            let _e171: vec3<i32> = nb;
            let _e172: vec4<i32> = d_17;
            let _e173: i32 = idx(_e171, _e172);
            j = _e173;
            let _e175: i32 = j;
            let _e177: u32 = global.mgFlags[_e175];
            t_6 = _e177;
            let _e179: u32 = t_6;
            if (_e179 == 2u) {
                {
                    continue;
                }
            }
            let _e182: f32 = n_4;
            n_4 = (_e182 + 1f);
            let _e185: u32 = t_6;
            if (_e185 == 1u) {
                {
                    let _e188: f32 = s_2;
                    let _e189: i32 = l_20;
                    let _e190: i32 = j;
                    let _e191: f32 = xAt(_e189, _e190);
                    s_2 = (_e188 + _e191);
                }
            }
        }
        continuing {
            let _e152: i32 = k_1;
            k_1 = (_e152 + 1i);
        }
    }
    let _e193: f32 = n_4;
    let _e194: i32 = l_20;
    let _e195: i32 = i_12;
    let _e196: f32 = xAt(_e194, _e195);
    let _e198: f32 = s_2;
    return ((_e193 * _e196) - _e198);
}

fn relax(l_21: i32, parity: i32, init: bool) {
    var l_22: i32;
    var parity_1: i32;
    var init_1: bool;
    var d_18: vec4<i32>;
    var count: i32;
    var t_7: i32;
    var c_14: vec3<i32>;
    var i_13: i32;
    var s_3: f32;
    var n_5: f32;
    var k_2: i32;
    var local_23: array<vec3<i32>, 6> = NB;
    var nb_1: vec3<i32>;
    var j_1: i32;
    var ty: u32;

    l_22 = l_21;
    parity_1 = parity;
    init_1 = init;
    let _e140: i32 = l_22;
    let _e141: vec4<i32> = levelDims(_e140);
    d_18 = _e141;
    let _e143: vec4<i32> = d_18;
    let _e144: i32 = l_22;
    let _e145: i32 = boxCount(_e143, _e144);
    count = _e145;
    let _e148: vec3<u32> = gl_LocalInvocationID_1;
    t_7 = i32(_e148.x);
    loop {
        let _e152: i32 = t_7;
        let _e153: i32 = count;
        if !((_e152 < _e153)) {
            break;
        }
        {
            let _e159: i32 = t_7;
            let _e160: vec4<i32> = d_18;
            let _e161: i32 = l_22;
            let _e162: vec3<i32> = boxCellOf(_e159, _e160, _e161);
            c_14 = _e162;
            let _e164: vec3<i32> = c_14;
            let _e165: vec4<i32> = d_18;
            let _e166: i32 = idx(_e164, _e165);
            i_13 = _e166;
            let _e168: i32 = i_13;
            let _e170: u32 = global.mgFlags[_e168];
            if (_e170 != 1u) {
                {
                    let _e173: bool = init_1;
                    if _e173 {
                        {
                            let _e174: i32 = l_22;
                            let _e175: i32 = i_13;
                            setX(_e174, _e175, 0f);
                        }
                    }
                    continue;
                }
            }
            let _e177: vec3<i32> = c_14;
            let _e179: vec3<i32> = c_14;
            let _e182: vec3<i32> = c_14;
            let _e187: i32 = parity_1;
            if ((((_e177.x + _e179.y) + _e182.z) & 1i) != _e187) {
                {
                    continue;
                }
            }
            s_3 = 0f;
            n_5 = 0f;
            k_2 = 0i;
            loop {
                let _e195: i32 = k_2;
                if !((_e195 < 6i)) {
                    break;
                }
                {
                    let _e202: vec3<i32> = c_14;
                    let _e203: i32 = k_2;
                    let _e207: vec3<i32> = local_23[_e203];
                    nb_1 = (_e202 + _e207);
                    let _e210: vec3<i32> = nb_1;
                    let _e211: vec4<i32> = d_18;
                    let _e212: i32 = l_22;
                    let _e213: bool = inLevel(_e210, _e211, _e212);
                    if !(_e213) {
                        {
                            let _e215: f32 = n_5;
                            n_5 = (_e215 + 1f);
                            continue;
                        }
                    }
                    let _e218: vec3<i32> = nb_1;
                    let _e219: vec4<i32> = d_18;
                    let _e220: i32 = idx(_e218, _e219);
                    j_1 = _e220;
                    let _e222: i32 = j_1;
                    let _e224: u32 = global.mgFlags[_e222];
                    ty = _e224;
                    let _e226: u32 = ty;
                    if (_e226 == 2u) {
                        {
                            continue;
                        }
                    }
                    let _e229: f32 = n_5;
                    n_5 = (_e229 + 1f);
                    let _e232: u32 = ty;
                    let _e235: bool = init_1;
                    if ((_e232 == 1u) && !(_e235)) {
                        {
                            let _e238: f32 = s_3;
                            let _e239: i32 = l_22;
                            let _e240: i32 = j_1;
                            let _e241: f32 = xAt(_e239, _e240);
                            s_3 = (_e238 + _e241);
                        }
                    }
                }
                continuing {
                    let _e199: i32 = k_2;
                    k_2 = (_e199 + 1i);
                }
            }
            let _e243: f32 = n_5;
            if (_e243 > 0f) {
                {
                    let _e246: i32 = l_22;
                    let _e247: i32 = i_13;
                    let _e248: i32 = l_22;
                    let _e249: i32 = i_13;
                    let _e250: f32 = bAt(_e248, _e249);
                    let _e251: f32 = s_3;
                    let _e253: f32 = n_5;
                    setX(_e246, _e247, ((_e250 + _e251) / _e253));
                }
            }
        }
        continuing {
            let _e156: i32 = t_7;
            t_7 = (_e156 + 1024i);
        }
    }
    sync();
    return;
}

fn restrictTo(l_23: i32) {
    var l_24: i32;
    var d_19: vec4<i32>;
    var cd: vec4<i32>;
    var count_1: i32;
    var t_8: i32;
    var C: vec3<i32>;
    var ci: i32;
    var sum: f32;
    var k_3: i32;
    var f_6: vec3<i32>;
    var fi: i32;

    l_24 = l_23;
    let _e137: i32 = l_24;
    let _e138: vec4<i32> = levelDims(_e137);
    d_19 = _e138;
    let _e140: i32 = l_24;
    let _e143: vec4<i32> = levelDims((_e140 + 1i));
    cd = _e143;
    let _e145: vec4<i32> = cd;
    let _e146: i32 = l_24;
    let _e149: i32 = boxCount(_e145, (_e146 + 1i));
    count_1 = _e149;
    let _e151: vec3<u32> = gl_LocalInvocationID_1;
    t_8 = i32(_e151.x);
    loop {
        let _e155: i32 = t_8;
        let _e156: i32 = count_1;
        if !((_e155 < _e156)) {
            break;
        }
        {
            let _e162: i32 = t_8;
            let _e163: vec4<i32> = cd;
            let _e164: i32 = l_24;
            let _e167: vec3<i32> = boxCellOf(_e162, _e163, (_e164 + 1i));
            C = _e167;
            let _e169: vec3<i32> = C;
            let _e170: vec4<i32> = cd;
            let _e171: i32 = idx(_e169, _e170);
            ci = _e171;
            sum = 0f;
            let _e175: i32 = ci;
            let _e177: u32 = global.mgFlags[_e175];
            if (_e177 == 1u) {
                {
                    k_3 = 0i;
                    loop {
                        let _e182: i32 = k_3;
                        if !((_e182 < 8i)) {
                            break;
                        }
                        {
                            let _e190: vec3<i32> = C;
                            let _e192: i32 = k_3;
                            let _e195: i32 = k_3;
                            let _e201: i32 = k_3;
                            f_6 = ((2i * _e190) + vec3<i32>((_e192 & 1i), ((_e195 >> 1u) & 1i), ((_e201 >> 2u) & 1i)));
                            let _e210: vec3<i32> = f_6;
                            let _e211: vec4<i32> = d_19;
                            let _e212: i32 = l_24;
                            let _e213: bool = inLevel(_e210, _e211, _e212);
                            if !(_e213) {
                                {
                                    continue;
                                }
                            }
                            let _e215: vec3<i32> = f_6;
                            let _e216: vec4<i32> = d_19;
                            let _e217: i32 = idx(_e215, _e216);
                            fi = _e217;
                            let _e219: i32 = fi;
                            let _e221: u32 = global.mgFlags[_e219];
                            if (_e221 != 1u) {
                                {
                                    continue;
                                }
                            }
                            let _e224: f32 = sum;
                            let _e225: i32 = l_24;
                            let _e226: i32 = fi;
                            let _e227: f32 = bAt(_e225, _e226);
                            let _e228: vec3<i32> = f_6;
                            let _e229: i32 = fi;
                            let _e230: vec4<i32> = d_19;
                            let _e231: i32 = l_24;
                            let _e232: f32 = applyA(_e228, _e229, _e230, _e231);
                            sum = (_e224 + (_e227 - _e232));
                        }
                        continuing {
                            let _e186: i32 = k_3;
                            k_3 = (_e186 + 1i);
                        }
                    }
                }
            }
            let _e235: i32 = ci;
            let _e238: f32 = sum;
            global_3.mgB[_e235] = (0.5f * _e238);
            let _e240: i32 = ci;
            global_4.mgX[_e240] = 0f;
        }
        continuing {
            let _e159: i32 = t_8;
            t_8 = (_e159 + 1024i);
        }
    }
    sync();
    return;
}

fn prolongFrom(l_25: i32) {
    var l_26: i32;
    var d_20: vec4<i32>;
    var cd_1: vec4<i32>;
    var count_2: i32;
    var t_9: i32;
    var f_7: vec3<i32>;
    var fi_1: i32;

    l_26 = l_25;
    let _e137: i32 = l_26;
    let _e138: vec4<i32> = levelDims(_e137);
    d_20 = _e138;
    let _e140: i32 = l_26;
    let _e143: vec4<i32> = levelDims((_e140 + 1i));
    cd_1 = _e143;
    let _e145: vec4<i32> = d_20;
    let _e146: i32 = l_26;
    let _e147: i32 = boxCount(_e145, _e146);
    count_2 = _e147;
    let _e149: vec3<u32> = gl_LocalInvocationID_1;
    t_9 = i32(_e149.x);
    loop {
        let _e153: i32 = t_9;
        let _e154: i32 = count_2;
        if !((_e153 < _e154)) {
            break;
        }
        {
            let _e160: i32 = t_9;
            let _e161: vec4<i32> = d_20;
            let _e162: i32 = l_26;
            let _e163: vec3<i32> = boxCellOf(_e160, _e161, _e162);
            f_7 = _e163;
            let _e165: vec3<i32> = f_7;
            let _e166: vec4<i32> = d_20;
            let _e167: i32 = idx(_e165, _e166);
            fi_1 = _e167;
            let _e169: i32 = fi_1;
            let _e171: u32 = global.mgFlags[_e169];
            if (_e171 != 1u) {
                {
                    continue;
                }
            }
            let _e174: i32 = l_26;
            let _e175: i32 = fi_1;
            let _e176: i32 = l_26;
            let _e177: i32 = fi_1;
            let _e178: f32 = xAt(_e176, _e177);
            let _e179: vec3<i32> = f_7;
            let _e183: vec4<i32> = cd_1;
            let _e184: i32 = idx((_e179 / vec3(2i)), _e183);
            let _e186: f32 = global_4.mgX[_e184];
            setX(_e174, _e175, (_e178 + _e186));
        }
        continuing {
            let _e157: i32 = t_9;
            t_9 = (_e157 + 1024i);
        }
    }
    sync();
    return;
}

fn vcycleFrom(first: i32, levels: i32, sweeps: i32) {
    var first_1: i32;
    var levels_1: i32;
    var sweeps_1: i32;
    var coarsest: i32;
    var l_27: i32;
    var init_2: bool;
    var k_4: i32 = 0i;
    var k_5: i32 = 0i;
    var l_28: i32;

    first_1 = first;
    levels_1 = levels;
    sweeps_1 = sweeps;
    let _e141: i32 = levels_1;
    coarsest = (_e141 - 1i);
    let _e145: i32 = first_1;
    l_27 = _e145;
    loop {
        let _e147: i32 = l_27;
        let _e148: i32 = coarsest;
        if !((_e147 < _e148)) {
            break;
        }
        {
            let _e154: i32 = l_27;
            let _e156: i32 = l_27;
            relax(_e154, 0i, (_e156 == 0i));
            let _e159: i32 = l_27;
            relax(_e159, 1i, false);
            let _e162: i32 = l_27;
            restrictTo(_e162);
        }
        continuing {
            let _e151: i32 = l_27;
            l_27 = (_e151 + 1i);
        }
    }
    let _e163: i32 = levels_1;
    init_2 = (_e163 == 1i);
    loop {
        let _e169: i32 = k_4;
        let _e170: i32 = sweeps_1;
        if !((_e169 < max(_e170, 1i))) {
            break;
        }
        {
            let _e178: i32 = coarsest;
            let _e180: bool = init_2;
            let _e181: i32 = k_4;
            relax(_e178, 0i, (_e180 && (_e181 == 0i)));
            let _e185: i32 = coarsest;
            relax(_e185, 1i, false);
        }
        continuing {
            let _e175: i32 = k_4;
            k_4 = (_e175 + 1i);
        }
    }
    loop {
        let _e190: i32 = k_5;
        let _e191: i32 = sweeps_1;
        if !((_e190 < max(_e191, 1i))) {
            break;
        }
        {
            let _e199: i32 = coarsest;
            relax(_e199, 1i, false);
            let _e202: i32 = coarsest;
            relax(_e202, 0i, false);
        }
        continuing {
            let _e196: i32 = k_5;
            k_5 = (_e196 + 1i);
        }
    }
    let _e205: i32 = coarsest;
    l_28 = (_e205 - 1i);
    loop {
        let _e209: i32 = l_28;
        let _e210: i32 = first_1;
        if !((_e209 >= _e210)) {
            break;
        }
        {
            let _e216: i32 = l_28;
            prolongFrom(_e216);
            let _e217: i32 = l_28;
            relax(_e217, 1i, false);
            let _e220: i32 = l_28;
            relax(_e220, 0i, false);
        }
        continuing {
            let _e213: i32 = l_28;
            l_28 = (_e213 - 1i);
        }
    }
    return;
}

fn total(v_6: f32) -> f32 {
    var v_7: f32;
    var lid: u32;
    var s_4: u32 = 512u;
    var sum_1: f32;

    v_7 = v_6;
    let _e138: vec3<u32> = gl_LocalInvocationID_1;
    lid = _e138.x;
    let _e141: u32 = lid;
    let _e143: f32 = v_7;
    partial[_e141] = _e143;
    storageBarrier();
    workgroupBarrier();
    textureBarrier();
    loop {
        let _e146: u32 = s_4;
        if !((_e146 > 0u)) {
            break;
        }
        {
            let _e154: u32 = lid;
            let _e155: u32 = s_4;
            if (_e154 < _e155) {
                {
                    let _e157: u32 = lid;
                    let _e159: u32 = lid;
                    let _e161: f32 = partial[_e159];
                    let _e162: u32 = lid;
                    let _e163: u32 = s_4;
                    let _e166: f32 = partial[(_e162 + _e163)];
                    partial[_e157] = (_e161 + _e166);
                }
            }
            storageBarrier();
            workgroupBarrier();
            textureBarrier();
        }
        continuing {
            let _e150: u32 = s_4;
            s_4 = (_e150 >> 1u);
        }
    }
    let _e170: f32 = partial[0];
    sum_1 = _e170;
    storageBarrier();
    workgroupBarrier();
    textureBarrier();
    let _e172: f32 = sum_1;
    return _e172;
}

fn applyTo(c_15: vec3<i32>, i_14: i32, d_21: vec4<i32>, useP: bool) -> f32 {
    var c_16: vec3<i32>;
    var i_15: i32;
    var d_22: vec4<i32>;
    var useP_1: bool;
    var s_5: f32 = 0f;
    var n_6: f32 = 0f;
    var k_6: i32 = 0i;
    var local_24: array<vec3<i32>, 6> = NB;
    var nb_2: vec3<i32>;
    var j_2: i32;
    var t_10: u32;
    var local_25: f32;
    var local_26: f32;

    c_16 = c_15;
    i_15 = i_14;
    d_22 = d_21;
    useP_1 = useP;
    loop {
        let _e150: i32 = k_6;
        if !((_e150 < 6i)) {
            break;
        }
        {
            let _e157: vec3<i32> = c_16;
            let _e158: i32 = k_6;
            let _e162: vec3<i32> = local_24[_e158];
            nb_2 = (_e157 + _e162);
            let _e165: vec3<i32> = nb_2;
            let _e166: vec4<i32> = d_22;
            let _e168: bool = inLevel(_e165, _e166, 0i);
            if !(_e168) {
                {
                    let _e170: f32 = n_6;
                    n_6 = (_e170 + 1f);
                    continue;
                }
            }
            let _e173: vec3<i32> = nb_2;
            let _e174: vec4<i32> = d_22;
            let _e175: i32 = idx(_e173, _e174);
            j_2 = _e175;
            let _e177: i32 = j_2;
            let _e179: u32 = global.mgFlags[_e177];
            t_10 = _e179;
            let _e181: u32 = t_10;
            if (_e181 == 2u) {
                {
                    continue;
                }
            }
            let _e184: f32 = n_6;
            n_6 = (_e184 + 1f);
            let _e187: u32 = t_10;
            if (_e187 == 1u) {
                {
                    let _e190: f32 = s_5;
                    let _e191: bool = useP_1;
                    if _e191 {
                        let _e192: i32 = j_2;
                        let _e194: f32 = global_8.p[_e192];
                        local_25 = _e194;
                    } else {
                        let _e195: i32 = j_2;
                        let _e197: f32 = global_7.pressure[_e195];
                        local_25 = _e197;
                    }
                    let _e199: f32 = local_25;
                    s_5 = (_e190 + _e199);
                }
            }
        }
        continuing {
            let _e154: i32 = k_6;
            k_6 = (_e154 + 1i);
        }
    }
    let _e201: f32 = n_6;
    let _e202: bool = useP_1;
    if _e202 {
        let _e203: i32 = i_15;
        let _e205: f32 = global_8.p[_e203];
        local_26 = _e205;
    } else {
        let _e206: i32 = i_15;
        let _e208: f32 = global_7.pressure[_e206];
        local_26 = _e208;
    }
    let _e210: f32 = local_26;
    let _e212: f32 = s_5;
    return ((_e201 * _e210) - _e212);
}

fn dotRZ(d_23: vec4<i32>, count_3: i32) -> f32 {
    var d_24: vec4<i32>;
    var count_4: i32;
    var v_8: f32 = 0f;
    var t_11: i32;
    var i_16: i32;

    d_24 = d_23;
    count_4 = count_3;
    let _e142: vec3<u32> = gl_LocalInvocationID_1;
    t_11 = i32(_e142.x);
    loop {
        let _e146: i32 = t_11;
        let _e147: i32 = count_4;
        if !((_e146 < _e147)) {
            break;
        }
        {
            let _e153: i32 = t_11;
            let _e154: vec4<i32> = d_24;
            let _e156: vec3<i32> = boxCellOf(_e153, _e154, 0i);
            let _e157: vec4<i32> = d_24;
            let _e158: i32 = idx(_e156, _e157);
            i_16 = _e158;
            let _e160: f32 = v_8;
            let _e161: i32 = i_16;
            let _e163: f32 = global_1.b0_[_e161];
            let _e164: i32 = i_16;
            let _e166: f32 = global_2.x0_[_e164];
            v_8 = (_e160 + (_e163 * _e166));
        }
        continuing {
            let _e150: i32 = t_11;
            t_11 = (_e150 + 1024i);
        }
    }
    let _e169: f32 = v_8;
    let _e170: f32 = total(_e169);
    return _e170;
}

fn safeRatio(num: f32, den: f32) -> f32 {
    var num_1: f32;
    var den_1: f32;
    var local_27: f32;
    var r: f32;
    var local_28: f32;

    num_1 = num;
    den_1 = den;
    let _e140: f32 = den_1;
    if (abs(_e140) > 0.000000000000000000000000000001f) {
        let _e144: f32 = num_1;
        let _e145: f32 = den_1;
        local_27 = (_e144 / _e145);
    } else {
        local_27 = 0f;
    }
    let _e149: f32 = local_27;
    r = _e149;
    let _e151: f32 = r;
    if ((bitcast<u32>(_e151) & 2139095040u) == 2139095040u) {
        local_28 = 0f;
    } else {
        let _e158: f32 = r;
        local_28 = _e158;
    }
    let _e160: f32 = local_28;
    return _e160;
}

fn main_1() {
    var levels_2: i32;
    var d_25: vec4<i32>;
    var count_5: i32;
    var lid_1: i32;
    var t_12: i32;
    var i_17: i32;
    var l_29: i32 = 0i;
    var fd_1: vec4<i32>;
    var cd_2: vec4<i32>;
    var coarseCount: i32;
    var t_13: i32;
    var C_1: vec3<i32>;
    var anyAir: bool;
    var anyFluid: bool;
    var k_7: i32;
    var f_8: vec3<i32>;
    var ty_1: u32;
    var local_29: u32;
    var local_30: u32;
    var t_14: i32;
    var c_17: vec3<i32>;
    var i_18: i32;
    var local_31: f32;
    var rz: f32;
    var t_15: i32;
    var i_19: i32;
    var iterations: i32;
    var k_8: i32 = 0i;
    var v_9: f32;
    var t_16: i32;
    var c_18: vec3<i32>;
    var i_20: i32;
    var aq: f32;
    var alpha: f32;
    var t_17: i32;
    var i_21: i32;
    var next: f32;
    var beta: f32;
    var t_18: i32;
    var i_22: i32;

    let _e137: vec4<i32> = pc.a;
    levels_2 = _e137.x;
    let _e141: vec4<i32> = levelDims(0i);
    d_25 = _e141;
    let _e143: vec4<i32> = d_25;
    let _e145: i32 = boxCount(_e143, 0i);
    count_5 = _e145;
    let _e147: vec3<u32> = gl_LocalInvocationID_1;
    lid_1 = i32(_e147.x);
    let _e151: i32 = lid_1;
    t_12 = _e151;
    loop {
        let _e153: i32 = t_12;
        let _e154: i32 = count_5;
        if !((_e153 < _e154)) {
            break;
        }
        {
            let _e160: i32 = t_12;
            let _e161: vec4<i32> = d_25;
            let _e163: vec3<i32> = boxCellOf(_e160, _e161, 0i);
            let _e164: vec4<i32> = d_25;
            let _e165: i32 = idx(_e163, _e164);
            i_17 = _e165;
            let _e167: i32 = i_17;
            let _e169: i32 = i_17;
            let _e171: u32 = global_5.cellFlags[_e169];
            global.mgFlags[_e167] = (_e171 & 255u);
        }
        continuing {
            let _e157: i32 = t_12;
            t_12 = (_e157 + 1024i);
        }
    }
    sync();
    loop {
        let _e176: i32 = l_29;
        let _e177: i32 = levels_2;
        if !((_e176 < (_e177 - 1i))) {
            break;
        }
        {
            let _e185: i32 = l_29;
            let _e186: vec4<i32> = levelDims(_e185);
            fd_1 = _e186;
            let _e188: i32 = l_29;
            let _e191: vec4<i32> = levelDims((_e188 + 1i));
            cd_2 = _e191;
            let _e193: vec4<i32> = cd_2;
            let _e194: i32 = l_29;
            let _e197: i32 = boxCount(_e193, (_e194 + 1i));
            coarseCount = _e197;
            let _e199: i32 = lid_1;
            t_13 = _e199;
            loop {
                let _e201: i32 = t_13;
                let _e202: i32 = coarseCount;
                if !((_e201 < _e202)) {
                    break;
                }
                {
                    let _e208: i32 = t_13;
                    let _e209: vec4<i32> = cd_2;
                    let _e210: i32 = l_29;
                    let _e213: vec3<i32> = boxCellOf(_e208, _e209, (_e210 + 1i));
                    C_1 = _e213;
                    anyAir = false;
                    anyFluid = false;
                    k_7 = 0i;
                    loop {
                        let _e221: i32 = k_7;
                        if !((_e221 < 8i)) {
                            break;
                        }
                        {
                            let _e229: vec3<i32> = C_1;
                            let _e231: i32 = k_7;
                            let _e234: i32 = k_7;
                            let _e240: i32 = k_7;
                            f_8 = ((2i * _e229) + vec3<i32>((_e231 & 1i), ((_e234 >> 1u) & 1i), ((_e240 >> 2u) & 1i)));
                            let _e249: vec3<i32> = f_8;
                            let _e250: vec4<i32> = fd_1;
                            if any((_e249 >= _e250.xyz)) {
                                {
                                    continue;
                                }
                            }
                            let _e254: vec3<i32> = f_8;
                            let _e255: vec4<i32> = fd_1;
                            let _e256: i32 = l_29;
                            let _e257: bool = inLevel(_e254, _e255, _e256);
                            if !(_e257) {
                                {
                                    anyAir = true;
                                    continue;
                                }
                            }
                            let _e260: vec3<i32> = f_8;
                            let _e261: vec4<i32> = fd_1;
                            let _e262: i32 = idx(_e260, _e261);
                            let _e264: u32 = global.mgFlags[_e262];
                            ty_1 = _e264;
                            let _e266: bool = anyAir;
                            let _e267: u32 = ty_1;
                            anyAir = (_e266 || (_e267 == 0u));
                            let _e271: bool = anyFluid;
                            let _e272: u32 = ty_1;
                            anyFluid = (_e271 || (_e272 == 1u));
                        }
                        continuing {
                            let _e225: i32 = k_7;
                            k_7 = (_e225 + 1i);
                        }
                    }
                    let _e276: vec3<i32> = C_1;
                    let _e277: vec4<i32> = cd_2;
                    let _e278: i32 = idx(_e276, _e277);
                    let _e280: bool = anyAir;
                    if _e280 {
                        local_30 = 0u;
                    } else {
                        let _e282: bool = anyFluid;
                        if _e282 {
                            local_29 = 1u;
                        } else {
                            local_29 = 2u;
                        }
                        let _e286: u32 = local_29;
                        local_30 = _e286;
                    }
                    let _e288: u32 = local_30;
                    global.mgFlags[_e278] = _e288;
                }
                continuing {
                    let _e205: i32 = t_13;
                    t_13 = (_e205 + 1024i);
                }
            }
            sync();
        }
        continuing {
            let _e182: i32 = l_29;
            l_29 = (_e182 + 1i);
        }
    }
    let _e289: i32 = lid_1;
    t_14 = _e289;
    loop {
        let _e291: i32 = t_14;
        let _e292: i32 = count_5;
        if !((_e291 < _e292)) {
            break;
        }
        {
            let _e298: i32 = t_14;
            let _e299: vec4<i32> = d_25;
            let _e301: vec3<i32> = boxCellOf(_e298, _e299, 0i);
            c_17 = _e301;
            let _e303: vec3<i32> = c_17;
            let _e304: vec4<i32> = d_25;
            let _e305: i32 = idx(_e303, _e304);
            i_18 = _e305;
            let _e307: i32 = i_18;
            let _e309: i32 = i_18;
            let _e311: u32 = global.mgFlags[_e309];
            if (_e311 == 1u) {
                let _e314: i32 = i_18;
                let _e316: f32 = global_6.div[_e314];
                let _e317: vec3<i32> = c_17;
                let _e318: i32 = i_18;
                let _e319: vec4<i32> = d_25;
                let _e321: f32 = applyTo(_e317, _e318, _e319, false);
                local_31 = (_e316 - _e321);
            } else {
                local_31 = 0f;
            }
            let _e325: f32 = local_31;
            global_1.b0_[_e307] = _e325;
        }
        continuing {
            let _e295: i32 = t_14;
            t_14 = (_e295 + 1024i);
        }
    }
    sync();
    let _e327: i32 = levels_2;
    let _e329: vec4<i32> = pc.a;
    vcycleFrom(0i, _e327, _e329.z);
    let _e331: vec4<i32> = d_25;
    let _e332: i32 = count_5;
    let _e333: f32 = dotRZ(_e331, _e332);
    rz = _e333;
    let _e335: i32 = lid_1;
    t_15 = _e335;
    loop {
        let _e337: i32 = t_15;
        let _e338: i32 = count_5;
        if !((_e337 < _e338)) {
            break;
        }
        {
            let _e344: i32 = t_15;
            let _e345: vec4<i32> = d_25;
            let _e347: vec3<i32> = boxCellOf(_e344, _e345, 0i);
            let _e348: vec4<i32> = d_25;
            let _e349: i32 = idx(_e347, _e348);
            i_19 = _e349;
            let _e351: i32 = i_19;
            let _e353: i32 = i_19;
            let _e355: f32 = global_2.x0_[_e353];
            global_8.p[_e351] = _e355;
        }
        continuing {
            let _e341: i32 = t_15;
            t_15 = (_e341 + 1024i);
        }
    }
    sync();
    let _e357: vec4<i32> = pc.a;
    iterations = max(_e357.y, 1i);
    loop {
        let _e364: i32 = k_8;
        let _e365: i32 = iterations;
        if !((_e364 < _e365)) {
            break;
        }
        {
            v_9 = 0f;
            let _e373: i32 = lid_1;
            t_16 = _e373;
            loop {
                let _e375: i32 = t_16;
                let _e376: i32 = count_5;
                if !((_e375 < _e376)) {
                    break;
                }
                {
                    let _e382: i32 = t_16;
                    let _e383: vec4<i32> = d_25;
                    let _e385: vec3<i32> = boxCellOf(_e382, _e383, 0i);
                    c_18 = _e385;
                    let _e387: vec3<i32> = c_18;
                    let _e388: vec4<i32> = d_25;
                    let _e389: i32 = idx(_e387, _e388);
                    i_20 = _e389;
                    let _e391: i32 = i_20;
                    let _e393: u32 = global.mgFlags[_e391];
                    if (_e393 == 1u) {
                        {
                            let _e396: vec3<i32> = c_18;
                            let _e397: i32 = i_20;
                            let _e398: vec4<i32> = d_25;
                            let _e400: f32 = applyTo(_e396, _e397, _e398, true);
                            aq = _e400;
                            let _e402: i32 = i_20;
                            let _e404: f32 = aq;
                            global_9.q[_e402] = _e404;
                            let _e405: f32 = v_9;
                            let _e406: f32 = aq;
                            let _e407: i32 = i_20;
                            let _e409: f32 = global_8.p[_e407];
                            v_9 = (_e405 + (_e406 * _e409));
                        }
                    } else {
                        {
                            let _e412: i32 = i_20;
                            global_9.q[_e412] = 0f;
                        }
                    }
                }
                continuing {
                    let _e379: i32 = t_16;
                    t_16 = (_e379 + 1024i);
                }
            }
            let _e415: f32 = rz;
            let _e416: f32 = v_9;
            let _e417: f32 = total(_e416);
            let _e418: f32 = safeRatio(_e415, _e417);
            alpha = _e418;
            sync();
            let _e420: i32 = lid_1;
            t_17 = _e420;
            loop {
                let _e422: i32 = t_17;
                let _e423: i32 = count_5;
                if !((_e422 < _e423)) {
                    break;
                }
                {
                    let _e429: i32 = t_17;
                    let _e430: vec4<i32> = d_25;
                    let _e432: vec3<i32> = boxCellOf(_e429, _e430, 0i);
                    let _e433: vec4<i32> = d_25;
                    let _e434: i32 = idx(_e432, _e433);
                    i_21 = _e434;
                    let _e436: i32 = i_21;
                    let _e438: i32 = i_21;
                    let _e440: f32 = global_7.pressure[_e438];
                    let _e441: f32 = alpha;
                    let _e442: i32 = i_21;
                    let _e444: f32 = global_8.p[_e442];
                    global_7.pressure[_e436] = (_e440 + (_e441 * _e444));
                    let _e447: i32 = i_21;
                    let _e449: i32 = i_21;
                    let _e451: f32 = global_1.b0_[_e449];
                    let _e452: f32 = alpha;
                    let _e453: i32 = i_21;
                    let _e455: f32 = global_9.q[_e453];
                    global_1.b0_[_e447] = (_e451 - (_e452 * _e455));
                }
                continuing {
                    let _e426: i32 = t_17;
                    t_17 = (_e426 + 1024i);
                }
            }
            sync();
            let _e458: i32 = k_8;
            let _e459: i32 = iterations;
            if (_e458 == (_e459 - 1i)) {
                {
                    break;
                }
            }
            let _e464: i32 = levels_2;
            let _e466: vec4<i32> = pc.a;
            vcycleFrom(0i, _e464, _e466.z);
            let _e468: vec4<i32> = d_25;
            let _e469: i32 = count_5;
            let _e470: f32 = dotRZ(_e468, _e469);
            next = _e470;
            let _e472: f32 = next;
            let _e473: f32 = rz;
            let _e474: f32 = safeRatio(_e472, _e473);
            beta = _e474;
            let _e476: i32 = lid_1;
            t_18 = _e476;
            loop {
                let _e478: i32 = t_18;
                let _e479: i32 = count_5;
                if !((_e478 < _e479)) {
                    break;
                }
                {
                    let _e485: i32 = t_18;
                    let _e486: vec4<i32> = d_25;
                    let _e488: vec3<i32> = boxCellOf(_e485, _e486, 0i);
                    let _e489: vec4<i32> = d_25;
                    let _e490: i32 = idx(_e488, _e489);
                    i_22 = _e490;
                    let _e492: i32 = i_22;
                    let _e494: i32 = i_22;
                    let _e496: f32 = global_2.x0_[_e494];
                    let _e497: f32 = beta;
                    let _e498: i32 = i_22;
                    let _e500: f32 = global_8.p[_e498];
                    global_8.p[_e492] = (_e496 + (_e497 * _e500));
                }
                continuing {
                    let _e482: i32 = t_18;
                    t_18 = (_e482 + 1024i);
                }
            }
            sync();
            let _e503: f32 = next;
            rz = _e503;
        }
        continuing {
            let _e368: i32 = k_8;
            k_8 = (_e368 + 1i);
        }
    }
    return;
}

@compute @workgroup_size(1024, 1, 1)
fn main(@builtin(local_invocation_id) gl_LocalInvocationID: vec3<u32>) {
    gl_LocalInvocationID_1 = gl_LocalInvocationID;
    main_1();
    return;
}
