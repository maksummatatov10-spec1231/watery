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

struct PC {
    dims: vec4<i32>,
    cdims: vec4<i32>,
    misc: vec4<i32>,
    misc2_: vec4<i32>,
}

struct MgFlags {
    mgFlags: array<u32>,
}

struct B {
    b: array<f32>,
}

struct X {
    x: array<f32>,
}

const FP_SCALE: f32 = 65536f;
const MG_NB: array<vec3<i32>, 6> = array<vec3<i32>, 6>(vec3<i32>(1i, 0i, 0i), vec3<i32>(-1i, 0i, 0i), vec3<i32>(0i, 1i, 0i), vec3<i32>(0i, -1i, 0i), vec3<i32>(0i, 0i, 1i), vec3<i32>(0i, 0i, -1i));

@group(0) @binding(0)
var<uniform> G: Globals;
@group(1) @binding(0)
var<uniform> pc: PC;
@group(0) @binding(1)
var<storage> global: MgFlags;
@group(0) @binding(2)
var<storage> global_1: B;
@group(0) @binding(3)
var<storage, read_write> global_2: X;
var<workgroup> sx: array<f32, 1024>;
var<workgroup> sb: array<f32, 1024>;
var<workgroup> sf: array<u32, 1024>;
var<private> gl_LocalInvocationID_1: vec3<u32>;

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

fn lvlIndex(c_8: vec3<i32>, d_5: vec4<i32>) -> i32 {
    var c_9: vec3<i32>;
    var d_6: vec4<i32>;

    c_9 = c_8;
    d_6 = d_5;
    let _e121: vec4<i32> = d_6;
    let _e123: vec3<i32> = c_9;
    let _e126: vec4<i32> = d_6;
    let _e128: vec3<i32> = c_9;
    let _e130: vec4<i32> = d_6;
    let _e132: vec3<i32> = c_9;
    return ((_e121.w + _e123.x) + (_e126.x * (_e128.y + (_e130.y * _e132.z))));
}

fn lvlBoxMin(l_1: i32) -> vec3<i32> {
    var l_2: i32;

    l_2 = l_1;
    let _e120: vec4<i32> = G.boxMin;
    let _e122: i32 = l_2;
    return (_e120.xyz >> vec3(u32(_e122)));
}

fn lvlBoxMax(l_3: i32, d_7: vec4<i32>) -> vec3<i32> {
    var l_4: i32;
    var d_8: vec4<i32>;

    l_4 = l_3;
    d_8 = d_7;
    let _e122: vec4<i32> = G.boxMax;
    let _e125: i32 = l_4;
    let _e132: i32 = l_4;
    let _e136: vec4<i32> = d_8;
    return min(((_e122.xyz + vec3(((1i << u32(_e125)) - 1i))) >> vec3(u32(_e132))), _e136.xyz);
}

fn lvlActive(c_10: vec3<i32>, d_9: vec4<i32>, l_5: i32) -> bool {
    var c_11: vec3<i32>;
    var d_10: vec4<i32>;
    var l_6: i32;

    c_11 = c_10;
    d_10 = d_9;
    l_6 = l_5;
    let _e123: vec3<i32> = c_11;
    let _e124: i32 = l_6;
    let _e125: vec3<i32> = lvlBoxMin(_e124);
    let _e128: vec3<i32> = c_11;
    let _e129: i32 = l_6;
    let _e130: vec4<i32> = d_10;
    let _e131: vec3<i32> = lvlBoxMax(_e129, _e130);
    return (all((_e123 >= _e125)) && all((_e128 < _e131)));
}

fn lvlBoxCount(d_11: vec4<i32>, l_7: i32) -> i32 {
    var d_12: vec4<i32>;
    var l_8: i32;
    var s: vec3<i32>;

    d_12 = d_11;
    l_8 = l_7;
    let _e121: i32 = l_8;
    let _e122: vec4<i32> = d_12;
    let _e123: vec3<i32> = lvlBoxMax(_e121, _e122);
    let _e124: i32 = l_8;
    let _e125: vec3<i32> = lvlBoxMin(_e124);
    s = max((_e123 - _e125), vec3(0i));
    let _e131: vec3<i32> = s;
    let _e133: vec3<i32> = s;
    let _e136: vec3<i32> = s;
    return ((_e131.x * _e133.y) * _e136.z);
}

fn lvlBoxCell(t_4: i32, d_13: vec4<i32>, l_9: i32) -> vec3<i32> {
    var t_5: i32;
    var d_14: vec4<i32>;
    var l_10: i32;
    var s_1: vec3<i32>;

    t_5 = t_4;
    d_14 = d_13;
    l_10 = l_9;
    let _e123: i32 = l_10;
    let _e124: vec4<i32> = d_14;
    let _e125: vec3<i32> = lvlBoxMax(_e123, _e124);
    let _e126: i32 = l_10;
    let _e127: vec3<i32> = lvlBoxMin(_e126);
    s_1 = (_e125 - _e127);
    let _e130: i32 = l_10;
    let _e131: vec3<i32> = lvlBoxMin(_e130);
    let _e132: i32 = t_5;
    let _e133: vec3<i32> = s_1;
    let _e136: i32 = t_5;
    let _e137: vec3<i32> = s_1;
    let _e140: vec3<i32> = s_1;
    let _e143: i32 = t_5;
    let _e144: vec3<i32> = s_1;
    let _e146: vec3<i32> = s_1;
    return (_e131 + vec3<i32>((_e132 % _e133.x), ((_e136 / _e137.x) % _e140.y), (_e143 / (_e144.x * _e146.y))));
}

fn sweep(t_6: i32, count: i32, c_12: vec3<i32>, lo_2: vec3<i32>, size: vec3<i32>, parity: i32) {
    var t_7: i32;
    var count_1: i32;
    var c_13: vec3<i32>;
    var lo_3: vec3<i32>;
    var size_1: vec3<i32>;
    var parity_1: i32;
    var s_2: f32 = 0f;
    var n_4: f32 = 0f;
    var k: i32 = 0i;
    var local_20: array<vec3<i32>, 6> = MG_NB;
    var nb: vec3<i32>;
    var j: i32;

    t_7 = t_6;
    count_1 = count;
    c_13 = c_12;
    lo_3 = lo_2;
    size_1 = size;
    parity_1 = parity;
    let _e139: i32 = t_7;
    let _e140: i32 = count_1;
    let _e142: i32 = t_7;
    let _e144: u32 = sf[_e142];
    let _e148: vec3<i32> = c_13;
    let _e150: vec3<i32> = c_13;
    let _e153: vec3<i32> = c_13;
    let _e158: i32 = parity_1;
    if (((_e139 < _e140) && (_e144 == 1u)) && ((((_e148.x + _e150.y) + _e153.z) & 1i) == _e158)) {
        {
            loop {
                let _e167: i32 = k;
                if !((_e167 < 6i)) {
                    break;
                }
                {
                    let _e174: vec3<i32> = c_13;
                    let _e175: i32 = k;
                    let _e179: vec3<i32> = local_20[_e175];
                    let _e181: vec3<i32> = lo_3;
                    nb = ((_e174 + _e179) - _e181);
                    let _e184: vec3<i32> = nb;
                    let _e189: vec3<i32> = nb;
                    let _e190: vec3<i32> = size_1;
                    if (any((_e184 < vec3(0i))) || any((_e189 >= _e190))) {
                        {
                            let _e194: f32 = n_4;
                            n_4 = (_e194 + 1f);
                            continue;
                        }
                    }
                    let _e197: vec3<i32> = nb;
                    let _e199: vec3<i32> = size_1;
                    let _e201: vec3<i32> = nb;
                    let _e203: vec3<i32> = size_1;
                    let _e205: vec3<i32> = nb;
                    j = (_e197.x + (_e199.x * (_e201.y + (_e203.y * _e205.z))));
                    let _e212: i32 = j;
                    let _e214: u32 = sf[_e212];
                    if (_e214 == 2u) {
                        {
                            continue;
                        }
                    }
                    let _e217: f32 = n_4;
                    n_4 = (_e217 + 1f);
                    let _e220: i32 = j;
                    let _e222: u32 = sf[_e220];
                    if (_e222 == 1u) {
                        {
                            let _e225: f32 = s_2;
                            let _e226: i32 = j;
                            let _e228: f32 = sx[_e226];
                            s_2 = (_e225 + _e228);
                        }
                    }
                }
                continuing {
                    let _e171: i32 = k;
                    k = (_e171 + 1i);
                }
            }
            let _e230: f32 = n_4;
            if (_e230 > 0f) {
                {
                    let _e233: i32 = t_7;
                    let _e235: i32 = t_7;
                    let _e237: f32 = sb[_e235];
                    let _e238: f32 = s_2;
                    let _e240: f32 = n_4;
                    sx[_e233] = ((_e237 + _e238) / _e240);
                }
            }
        }
    }
    storageBarrier();
    workgroupBarrier();
    textureBarrier();
    return;
}

fn main_1() {
    var l_11: i32;
    var t_8: i32;
    var count_2: i32;
    var lo_4: vec3<i32>;
    var size_2: vec3<i32>;
    var c_14: vec3<i32> = vec3(0i);
    var i_5: i32 = 0i;
    var local_21: f32;
    var sweeps: i32;
    var k_1: i32 = 0i;
    var k_2: i32 = 0i;

    let _e128: vec4<i32> = pc.misc;
    l_11 = _e128.z;
    let _e132: vec3<u32> = gl_LocalInvocationID_1;
    t_8 = i32(_e132.x);
    let _e137: vec4<i32> = pc.dims;
    let _e138: i32 = l_11;
    let _e139: i32 = lvlBoxCount(_e137, _e138);
    count_2 = min(_e139, 1024i);
    let _e143: i32 = l_11;
    let _e144: vec3<i32> = lvlBoxMin(_e143);
    lo_4 = _e144;
    let _e146: i32 = l_11;
    let _e148: vec4<i32> = pc.dims;
    let _e149: vec3<i32> = lvlBoxMax(_e146, _e148);
    let _e150: vec3<i32> = lo_4;
    size_2 = (_e149 - _e150);
    let _e158: i32 = t_8;
    let _e159: i32 = count_2;
    if (_e158 < _e159) {
        {
            let _e161: i32 = t_8;
            let _e163: vec4<i32> = pc.dims;
            let _e164: i32 = l_11;
            let _e165: vec3<i32> = lvlBoxCell(_e161, _e163, _e164);
            c_14 = _e165;
            let _e166: vec3<i32> = c_14;
            let _e168: vec4<i32> = pc.dims;
            let _e169: i32 = lvlIndex(_e166, _e168);
            i_5 = _e169;
            let _e170: i32 = t_8;
            let _e172: i32 = i_5;
            let _e174: u32 = global.mgFlags[_e172];
            sf[_e170] = _e174;
            let _e175: i32 = t_8;
            let _e177: i32 = i_5;
            let _e179: f32 = global_1.b[_e177];
            sb[_e175] = _e179;
            let _e180: i32 = t_8;
            let _e183: vec4<i32> = pc.misc;
            let _e187: i32 = t_8;
            let _e189: u32 = sf[_e187];
            if ((_e183.y != 0i) || (_e189 != 1u)) {
                local_21 = 0f;
            } else {
                let _e194: i32 = i_5;
                let _e196: f32 = global_2.x[_e194];
                local_21 = _e196;
            }
            let _e198: f32 = local_21;
            sx[_e180] = _e198;
        }
    }
    storageBarrier();
    workgroupBarrier();
    textureBarrier();
    let _e200: vec4<i32> = pc.misc2_;
    sweeps = max(_e200.x, 1i);
    loop {
        let _e207: i32 = k_1;
        let _e208: i32 = sweeps;
        if !((_e207 < _e208)) {
            break;
        }
        {
            let _e214: i32 = t_8;
            let _e215: i32 = count_2;
            let _e216: vec3<i32> = c_14;
            let _e217: vec3<i32> = lo_4;
            let _e218: vec3<i32> = size_2;
            sweep(_e214, _e215, _e216, _e217, _e218, 0i);
            let _e220: i32 = t_8;
            let _e221: i32 = count_2;
            let _e222: vec3<i32> = c_14;
            let _e223: vec3<i32> = lo_4;
            let _e224: vec3<i32> = size_2;
            sweep(_e220, _e221, _e222, _e223, _e224, 1i);
        }
        continuing {
            let _e211: i32 = k_1;
            k_1 = (_e211 + 1i);
        }
    }
    loop {
        let _e228: i32 = k_2;
        let _e229: i32 = sweeps;
        if !((_e228 < _e229)) {
            break;
        }
        {
            let _e235: i32 = t_8;
            let _e236: i32 = count_2;
            let _e237: vec3<i32> = c_14;
            let _e238: vec3<i32> = lo_4;
            let _e239: vec3<i32> = size_2;
            sweep(_e235, _e236, _e237, _e238, _e239, 1i);
            let _e241: i32 = t_8;
            let _e242: i32 = count_2;
            let _e243: vec3<i32> = c_14;
            let _e244: vec3<i32> = lo_4;
            let _e245: vec3<i32> = size_2;
            sweep(_e241, _e242, _e243, _e244, _e245, 0i);
        }
        continuing {
            let _e232: i32 = k_2;
            k_2 = (_e232 + 1i);
        }
    }
    let _e247: i32 = t_8;
    let _e248: i32 = count_2;
    if (_e247 < _e248) {
        {
            let _e250: i32 = i_5;
            let _e252: i32 = t_8;
            let _e254: f32 = sx[_e252];
            global_2.x[_e250] = _e254;
            return;
        }
    } else {
        return;
    }
}

@compute @workgroup_size(1024, 1, 1)
fn main(@builtin(local_invocation_id) gl_LocalInvocationID: vec3<u32>) {
    gl_LocalInvocationID_1 = gl_LocalInvocationID;
    main_1();
    return;
}
