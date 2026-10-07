"""Author Starlantern's adult expedition rig and meshes as a portable GLB.

No downloaded models or build-time packages. Units: metres, +Y up, +Z forward.
Lofted profiles define the silhouette, skin weights bend knees/elbows, and every
animation keys the same 19-joint rig. Re-run with Python 3 from any directory.
Editable second art pass: smooth cloth, individual faces, and volume hair.
"""
from collections import defaultdict
from pathlib import Path
import json
import math
import struct

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/characters/expedition_adult.glb"
PI = math.pi


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    size = math.sqrt(sum(x*x for x in a)) or 1
    return tuple(x/size for x in a)


def quat(x=0, y=0, z=0):
    # XYZ local Euler rotations, represented as glTF x/y/z/w quaternion.
    sx, sy, sz = [math.sin(v/2) for v in (x, y, z)]
    cx, cy, cz = [math.cos(v/2) for v in (x, y, z)]
    return (sx*cy*cz+cx*sy*sz, cx*sy*cz-sx*cy*sz,
            cx*cy*sz+sx*sy*cz, cx*cy*cz-sx*sy*sz)


# Rest joint locations in mesh coordinates; glTF node translations are relative.
BONES = [
    ("hips", None, (0, 1.00, 0)),
    ("spine", "hips", (0, 1.19, 0)),
    ("chest", "spine", (0, 1.43, 0)),
    ("neck", "chest", (0, 1.61, 0)),
    ("head", "neck", (0, 1.69, 0)),
]
for side, sign in [("l", -1), ("r", 1)]:
    BONES += [
        (f"upper_arm_{side}", "chest", (sign*.275, 1.49, 0)),
        (f"forearm_{side}", f"upper_arm_{side}", (sign*.33, 1.19, 0)),
        (f"hand_{side}", f"forearm_{side}", (sign*.355, .955, .025)),
        (f"grip_{side}", f"hand_{side}", (sign*.355, .905, .078)),
        (f"thigh_{side}", "hips", (sign*.122, .98, 0)),
        (f"shin_{side}", f"thigh_{side}", (sign*.125, .55, .014)),
        (f"foot_{side}", f"shin_{side}", (sign*.128, .135, .025)),
    ]
JOINT = {b[0]: i for i, b in enumerate(BONES)}
REST = {b[0]: b[2] for b in BONES}

PALETTE = {
    "Coat": ("426475", .92, 0), "CoatShade": ("2c4350", .94, 0),
    "Linen": ("807b69", 1, 0), "Leather": ("594333", .88, 0),
    "LeatherEdge": ("896c4e", .83, 0), "Trousers": ("393e41", 1, 0),
    "Skin": ("ad886e", .93, 0), "SkinShade": ("82634f", .96, 0),
    "Hair": ("342d28", 1, 0), "Steel": ("747d7c", .53, .50),
    "Edge": ("bdc3bb", .4, .65), "Brass": ("ab8c54", .57, .48),
    "Dark": ("292a28", 1, 0), "Eye": ("30332f", .7, 0),
    "HairLight": ("716250", .95, 0), "EyeWhite": ("ac9f89", .85, 0),
    "Lip": ("956e60", .9, 0), "Stubble": ("806a55", 1, 0),
}


class Model:
    def __init__(self):
        self.parts = defaultdict(list)

    def tri(self, material, vertices, bone="hips", weights=None, normals=None):
        normal = unit(cross(sub(vertices[1], vertices[0]), sub(vertices[2], vertices[0])))
        if weights is None:
            weights = [{bone: 1.0} for _ in vertices]
        for i, (p, w) in enumerate(zip(vertices, weights)):
            self.parts[material].append((p, normals[i] if normals else normal, w))

    def quad(self, material, a, b, c, d, bone="hips"):
        self.tri(material, (a, b, c), bone)
        self.tri(material, (a, c, d), bone)

    def loft(self, material, rows, bone="hips", segments=20, weight=None, caps=True):
        # rows = (y, half width, half depth, center x, center z).
        segments = max(16, segments)
        rings = [[(cx + rx*math.sin(i*2*PI/segments), y,
                   cz + rz*math.cos(i*2*PI/segments))
                  for i in range(segments)] for y, rx, rz, cx, cz in rows]
        # Average the profile tangent at each ring; hard cuffs remain separate
        # lofts. This removes triangle highlights without rounding the silhouette.
        normals = []
        for k,(y,rx,rz,cx,cz) in enumerate(rows):
            a,b = rows[max(0,k-1)],rows[min(len(rows)-1,k+1)]
            ring_normals=[]
            for i in range(segments):
                ang=i*2*PI/segments
                tangent=(rx*math.cos(ang),0,-rz*math.sin(ang))
                longitudinal=((b[1]-a[1])*math.sin(ang)+b[3]-a[3],b[0]-a[0],(b[2]-a[2])*math.cos(ang)+b[4]-a[4])
                ring_normals.append(unit(cross(tangent,longitudinal)))
            normals.append(ring_normals)
        for k,(low, high) in enumerate(zip(rings, rings[1:])):
            for i in range(segments):
                n = (i+1) % segments
                for pts,ns in [((low[i],low[n],high[n]),(normals[k][i],normals[k][n],normals[k+1][n])),
                               ((low[i],high[n],high[i]),(normals[k][i],normals[k+1][n],normals[k+1][i]))]:
                    ws = [weight(p) for p in pts] if weight else None
                    self.tri(material, pts, bone, ws, ns)
        if caps:
            for ring, row, reverse in [(rings[0], rows[0], True), (rings[-1], rows[-1], False)]:
                center = (row[3], row[0], row[4])
                for i in range(segments):
                    pts = (center, ring[(i+1)%segments], ring[i]) if reverse else (center, ring[i], ring[(i+1)%segments])
                    self.tri(material, pts, bone, [weight(p) for p in pts] if weight else None)

    def block(self, material, center, size, bone="hips"):
        x,y,z = center
        a,b,c = [v/2 for v in size]
        vs = [(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in
              [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
        for f in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)]:
            self.quad(material, *(vs[i] for i in f), bone)

    def ribbon(self, material, start, end, width, bone):
        v = sub(end, start)
        side = unit((-v[1],v[0],0))
        d = tuple(t*width/2 for t in side)
        self.quad(material, sub(start,d), sub(end,d), add(end,d), add(start,d), bone)

    def panel(self, material, rows, angle_start, angle_end, bone="hips", weight=None):
        # Open, curved panels: coat skirts and facial overlays follow a volume.
        count = 16
        rings = [[(cx+rx*math.sin(a), y, cz+rz*math.cos(a))
                  for a in [angle_start+(angle_end-angle_start)*i/count for i in range(count+1)]]
                 for y,rx,rz,cx,cz in rows]
        for k in range(len(rings)-1):
            for i in range(count):
                for ids in [((k,i),(k,i+1),(k+1,i+1)),((k,i),(k+1,i+1),(k+1,i))]:
                    pts=[rings[r][j] for r,j in ids]
                    ns=[]
                    for r,j in ids:
                        a=angle_start+(angle_end-angle_start)*j/count
                        rx,rz=rows[r][1:3]
                        lo,hi=rows[max(0,r-1)],rows[min(len(rows)-1,r+1)]
                        tangent=(rx*math.cos(a),0,-rz*math.sin(a))
                        along=((hi[1]-lo[1])*math.sin(a)+hi[3]-lo[3],hi[0]-lo[0],(hi[2]-lo[2])*math.cos(a)+hi[4]-lo[4])
                        ns.append(unit(cross(tangent,along)))
                    self.tri(material,pts,bone,[weight(p) for p in pts] if weight else None,ns)

    def lock(self, material, points, radii, bone="head"):
        # Swept oval lock of hair, with real thickness rather than paper triangles.
        rings=[]; norms=[]
        for i,p in enumerate(points):
            tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(0,i-1)]))
            side=unit(cross(tangent,(0,0,1) if abs(tangent[2])<.9 else (0,1,0)))
            front=unit(cross(side,tangent))
            ring=[];ns=[]
            for j in range(10):
                a=j*2*PI/10
                offset=add(tuple(v*math.cos(a) for v in side),tuple(v*math.sin(a) for v in front))
                ring.append(add(p,tuple(v*radii[i] for v in offset)));ns.append(offset)
            rings.append(ring);norms.append(ns)
        for k in range(len(rings)-1):
            for i in range(10):
                n=(i+1)%10
                for ids in [((k,i),(k+1,n),(k,n)),((k,i),(k+1,i),(k+1,n))]:
                    self.tri(material,[rings[r][j] for r,j in ids],bone,normals=[norms[r][j] for r,j in ids])


def blend_joint(y, low, high, center, span):
    t = max(0, min(1, (y-center)/span + .5))
    return {low: 1-t, high: t}


def make_body():
    m = Model()
    torso_weight = lambda p: blend_joint(p[1], "spine", "chest", 1.31, .26)
    m.loft("Coat", [(1.01,.19,.132,0,0),(1.13,.179,.135,0,0),(1.30,.218,.145,0,0),
                    (1.46,.253,.134,0,0),(1.52,.22,.125,0,0),(1.57,.103,.082,0,0)], weight=torso_weight, segments=12)
    m.loft("Trousers", [(.90,.188,.123,0,0),(1.055,.19,.125,0,0)], segments=10)
    # Curved, split coat skirts. The waist stays on the hips while the hem follows
    # each thigh softly; they no longer look like four flat cardboard flaps.
    for s, side in [(-1,"l"),(1,"r")]:
        rows=[(.665,.24,.171,0,0),(.70,.241,.17,0,0),(.87,.218,.157,0,0),(1.08,.197,.147,0,0)]
        skirt_weight=lambda p,b=f"thigh_{side}": {"hips":1-max(0,1.08-p[1])*.75,b:max(0,1.08-p[1])*.75}
        start,end=(.15,PI-.14) if s>0 else (-PI+.14,-.15)
        m.panel("Coat",rows,start,end,weight=skirt_weight)
        m.panel("CoatShade",rows[:2],start,end,weight=skirt_weight)
        # Thigh and shin are a single weighted profile so joints do not separate.
        thigh,shin = f"thigh_{side}",f"shin_{side}"
        m.loft("Trousers", [(.24,.07,.074,s*.128,0),(.48,.086,.086,s*.126,.015),
                              (.56,.095,.09,s*.125,.008),(.77,.108,.116,s*.123,0),(.98,.10,.118,s*.122,0)],
               thigh, 10, lambda p,lo=shin,hi=thigh: blend_joint(p[1],lo,hi,.55,.19))
        m.loft("Leather", [(.12,.074,.09,s*.128,.016),(.23,.086,.097,s*.128,0),
                             (.39,.088,.10,s*.128,0),(.44,.094,.104,s*.128,0)], shin,10)
        m.loft("LeatherEdge", [(.402,.091,.103,s*.128,0),(.44,.098,.108,s*.128,0)], shin,10)
        m.loft("Leather", [(.035,.088,.163,s*.128,.064),(.075,.092,.174,s*.128,.072),
                             (.145,.076,.132,s*.128,.034),(.20,.072,.078,s*.128,0)], f"foot_{side}",10)
        m.loft("Dark", [(.018,.091,.172,s*.128,.070),(.047,.092,.174,s*.128,.070)], f"foot_{side}",10)
        arm,fore,hand = f"upper_arm_{side}",f"forearm_{side}",f"hand_{side}"
        m.loft("Coat", [(.96,.053,.061,s*.355,.015),(1.16,.075,.078,s*.33,0),
                          (1.23,.077,.077,s*.32,0),(1.37,.095,.092,s*.303,0),(1.48,.104,.098,s*.276,0)],
               arm,10,lambda p,lo=fore,hi=arm: blend_joint(p[1],lo,hi,1.19,.13))
        m.loft("Leather", [(.97,.06,.068,s*.355,.015),(1.03,.071,.074,s*.35,.009),(1.135,.077,.08,s*.335,0)],fore,8)
        m.loft("LeatherEdge", [(1.09,.078,.082,s*.34,0),(1.135,.080,.083,s*.337,0)],fore,8)
        m.loft("Leather", [(.845,.045,.051,s*.357,.04),(.905,.052,.059,s*.357,.042),(.96,.049,.055,s*.355,.023)],hand,8)
        # Thumb and knuckle plate imply a closed grip, not a mitten sphere.
        m.loft("LeatherEdge", [(.875,.021,.032,s*.319,.079),(.935,.026,.036,s*.315,.068)],hand,6)
        m.block("LeatherEdge",(s*.357,.918,.089),(.07,.043,.011),hand)
    # Shirt opening, lapels and broad asymmetrical shoulder harness.
    m.panel("Linen",[(1.10,.186,.147,0,.011),(1.31,.221,.147,0,.011),(1.49,.23,.143,0,.009)],-.31,.31,"chest",torso_weight)
    for s in [-1,1]:
        m.lock("CoatShade",[(s*.067,1.565,.095),(s*.096,1.495,.135),(s*.072,1.31,.16),(s*.061,1.105,.158)],[.012,.015,.012,.007],"chest")
        m.ribbon("Leather",(s*.20,1.47,.141),(s*.145,1.10,.15),.044,"chest")
        m.ribbon("LeatherEdge",(s*.204,1.47,.146),(s*.149,1.10,.155),.006,"chest")
    for y in [1.18,1.27,1.36,1.44]:
        m.loft("Brass",[(y,.005,.004,0,.16),(y+.009,.005,.004,0,.16)],"chest")
    m.loft("Leather", [(1.038,.201,.147,0,0),(1.105,.192,.148,0,0)],"hips",12)
    m.block("Brass",(.006,1.072,.155),(.075,.07,.013),"hips")
    m.block("Dark",(.006,1.072,.164),(.047,.037,.006),"hips")
    for x in [-.19,.185]:
        m.loft("Leather",[(.895,.061,.041,x,.14),(.925,.079,.049,x,.14),(1.036,.075,.048,x,.12)],"hips",8)
        m.block("LeatherEdge",(x,1.008,.184),(.137,.035,.011),"hips")
        m.block("Brass",(x,.987,.194),(.018,.022,.007),"hips")
    m.loft("Leather",[(1.435,.108,.107,-.283,0),(1.525,.11,.107,-.263,0)],"upper_arm_l",8)
    m.loft("Leather",[(1.435,.108,.107,.283,0),(1.525,.11,.107,.263,0)],"upper_arm_r",8)
    m.loft("SkinShade",[(1.55,.06,.063,0,0),(1.69,.067,.067,0,.013)],"neck",10)
    # Wrapped scarf and a small breast clasp.
    m.loft("CoatShade",[(1.53,.11,.091,0,0),(1.57,.119,.104,0,0),(1.624,.088,.082,0,0)],"neck",10)
    m.block("Brass",(-.105,1.427,.155),(.025,.025,.009),"chest")
    return m


def make_armor():
    m=Model()
    for level in range(3):
        y=1.40+level*.052
        m.loft("Steel",[(y,.111,.116,.292,0),(y+.032,.115,.12,.284,0),(y+.066,.084,.096,.27,0)],"upper_arm_r")
        m.loft("Edge",[(y,.112,.117,.292,0),(y+.009,.114,.119,.290,0)],"upper_arm_r")
    return m


def make_face(role):
    m=Model()
    older=role=="carpenter"
    narrow=role=="porter"
    width=.94 if narrow else (1.035 if older else 1)
    hair="HairLight" if older else "Hair"
    rows=[(1.643,.062,.066,0,.028),(1.666,.09,.083,0,.025),
          (1.713,.115,.096,0,.017),(1.75,.121,.099,0,.011),
          (1.782,.119,.096,0,.011),(1.827,.115,.099,0,.004),
          (1.873,.104,.097,0,-.006),(1.910,.077,.076,0,-.01),(1.924,.012,.014,0,-.01)]
    m.loft("Skin",[(y,rx*width,rz,cx,cz) for y,rx,rz,cx,cz in rows],"head",32)
    for s in [-1,1]:
        # Lower, close-set eyelids, with a small iris rather than a bright white slit.
        m.lock("SkinShade",[(s*.025,1.783,.108),(s*.05,1.788,.105),(s*.079,1.778,.088)], [.003,.009,.003])
        m.quad("EyeWhite",(s*.03,1.772,.109),(s*.071,1.773,.098),(s*.068,1.765,.1),(s*.032,1.764,.111),"head")
        m.loft("Eye",[(1.764,.005,.004,s*.049,.108),(1.776,.0055,.004,s*.049,.108)],"head",16)
        m.lock(hair,[(s*.024,1.793,.111),(s*.05,1.798,.106),(s*.083,1.787,.087)],[.004,.006,.002])
        m.lock("Skin",[(s*.027,1.761,.107),(s*.05,1.758,.104),(s*.072,1.763,.097)],[.002,.004,.002])
        m.loft("Skin",[(1.722,.012,.014,s*.118*width,-.001),(1.749,.020,.028,s*.121*width,-.003),(1.785,.015,.025,s*.117*width,-.007),(1.79,.008,.014,s*.118*width,-.007)],"head")
        m.lock("SkinShade",[(s*.124*width,1.738,.018),(s*.132*width,1.757,.019),(s*.121*width,1.777,.016)],[.003,.004,.001])
        if older:
            m.lock("SkinShade",[(s*.026,1.744,.123),(s*.039,1.723,.116),(s*.049,1.708,.106)],[.001,.002,.001])
    # An actual bridge, tip and nostrils, with softer cheeks around it.
    m.loft("Skin",[(1.721,.011,.008,0,.125),(1.727,.022,.019,0,.131),
                    (1.742,.018,.022,0,.127),(1.773,.012,.014,0,.111),(1.79,.008,.006,0,.103)],"head",20)
    for s in [-1,1]:
        m.loft("SkinShade",[(1.720,.007,.007,s*.015,.139),(1.725,.008,.008,s*.015,.139)],"head")
    m.lock("Lip",[(-.03,1.697,.111),(0,1.700,.121),(.03,1.697,.111)],[.001,.004,.001])
    m.lock("SkinShade",[(-.028,1.695,.112),(0,1.694,.121),(.028,1.695,.112)],[.001,.0018,.001])
    if not narrow:
        beard="HairLight" if older else "Stubble"
        m.panel(beard,[(1.638 if older else 1.645,.046,.044,0,.045),
                      (1.665,.091*width,.085,0,.025),(1.688,.105*width,.092,0,.021)],-1.35,1.35,"head")
        for s in [-1,1]:
            start,end=(.62,1.50) if s>0 else (-1.50,-.62)
            m.panel(beard,[(1.682,.1*width,.089,0,.025),(1.715,.117*width,.098,0,.017),(1.741,.12*width,.1,0,.012)],start,end,"head")
        if older:
            m.lock(hair,[(-.028,1.711,.117),(0,1.708,.122),(.028,1.711,.117)],[.004,.006,.004])
    # Close-cut temples and a swept crown: volumetric, readable from rear camera.
    m.panel(hair,[(1.744,.118,.095,0,-.007),(1.830,.12,.106,0,-.009),(1.884,.105,.101,0,-.014)],.91,2*PI-.91,"head")
    m.loft(hair,[(1.842,.116,.103,0,-.009),(1.906,.108,.102,-.008,-.014),
                 (1.942 if not older else 1.923,.065,.069,-.019,-.02),(1.952 if not older else 1.939,.008,.012,-.02,-.02)],"head",24)
    for i in range(5):
        x=-.082+i*.036
        if narrow:
            m.lock(hair,[(x,1.864,.081),(x*.88,1.93,.025),(x*.65,1.90,-.092)],[.015,.024,.014])
        else:
            m.lock(hair,[(x-.017,(1.881 if older else 1.855)+abs(x)*.22,.083),(x+.01,1.915 if older else 1.902,.089),(x+.029,1.935 if not older else 1.923,.017),(x+.02,1.899,-.073)],[.008,.022,.025,.009])
    if narrow:
        m.lock(hair,[(0,1.865,-.092),(0,1.824,-.137),(0,1.721,-.166),(0,1.67,-.144)],[.035,.038,.028,.004])
        m.loft("LeatherEdge",[(1.797,.034,.025,0,-.142),(1.813,.034,.025,0,-.142)],"head")
    return m


def make_pack():
    m = Model()
    m.loft("Leather",[(1.11,.145,.083,0,-.202),(1.16,.171,.103,0,-.225),
                         (1.39,.175,.106,0,-.225),(1.46,.149,.083,0,-.216)],"chest",8)
    m.loft("LeatherEdge",[(1.354,.18,.113,0,-.226),(1.414,.18,.112,0,-.22),(1.46,.15,.09,0,-.216)],"chest",8)
    for x in [-.096,.096]:
        m.block("LeatherEdge",(x,1.267,-.336),(.027,.272,.017),"chest")
        m.block("Brass",(x,1.264,-.351),(.039,.035,.008),"chest")
    # Cloth roll, rotated from vertical loft to horizontal across the shoulders.
    roll = Model()
    roll.loft("Linen",[(-.225,.083,.083,0,0),(-.202,.10,.10,0,0),(.202,.10,.10,0,0),(.225,.083,.083,0,0)],"chest",10)
    for mat, verts in roll.parts.items():
        for p,n,w in verts:
            m.parts[mat].append(((p[1],1.475-p[0],-.23+p[2]),(n[1],-n[0],n[2]),w))
    for x in [-.125,.125]:
        m.block("Leather",(x,1.475,-.33),(.029,.17,.014),"chest")
    return m


def make_apron():
    m=Model()
    m.panel("Leather",[(.66,.264,.201,0,0),(.92,.223,.182,0,0),(1.10,.199,.171,0,.012),(1.39,.233,.175,0,.011)],-.82,.82,"spine",lambda p: blend_joint(p[1],"hips","chest",1.21,.35))
    m.block("LeatherEdge",(0,.987,.194),(.24,.136,.014),"hips")
    return m


def make_axe():
    m=Model()
    # Grip origin at the palm. Haft points up: the weighted head leads the swing.
    m.loft("Leather",[(-.30,.025,.025,0,0),(.70,.03,.03,0,0)],"hips",8)
    for y in [-.25,-.10,.07,.63]:
        m.loft("Brass" if y>.6 else "LeatherEdge",[(y,.03,.03,0,0),(y+.037,.03,.03,0,0)],"hips",8)
    outline=[(-.06,.60),(.06,.67),(.24,.71),(.33,.81),(.35,.55),(.29,.37),(.16,.46),(.055,.54),(-.06,.54)]
    for z,rev in [(-.031,True),(.031,False)]:
        for i in range(1,len(outline)-1):
            pts=[(outline[k][0],outline[k][1],z) for k in [0,i,i+1]]
            m.tri("Steel",tuple(reversed(pts)) if rev else pts)
    for i in range(len(outline)):
        a,b=outline[i],outline[(i+1)%len(outline)]
        m.quad("Edge" if i in [2,3,4] else "Steel",(a[0],a[1],-.031),(b[0],b[1],-.031),(b[0],b[1],.031),(a[0],a[1],.031))
    return m


def make_hammer():
    m=Model()
    m.loft("Leather",[(-.17,.024,.024,0,0),(.36,.028,.028,0,0)],segments=8)
    m.block("Steel",(0,.35,0),(.27,.12,.12))
    return m


def pose(clip,t):
    p={name:(0,0,0) for name,_,_ in BONES}
    p["upper_arm_l"]=(0,0,-.065)
    p["upper_arm_r"]=(-.09,0,.065)
    p["forearm_r"]=(-.10,0,0)
    lift=0
    if clip in ["Idle","CarryIdle"]:
        p["chest"]=(.013*math.sin(t*2*PI),.012*math.sin(t*2*PI),0)
    if clip in ["Walk","Run","CarryWalk"]:
        run=clip=="Run"
        a=t*2*PI
        stride=.68 if run else .48
        lift=abs(math.sin(a))*(.042 if run else .025)
        for side,phase in [("l",0),("r",PI)]:
            s=math.sin(a+phase)
            p[f"thigh_{side}"]=(stride*s,0,0)
            p[f"shin_{side}"]=(-max(0,-s)*(.95 if run else .57),0,0)
            p[f"foot_{side}"]=(max(0,-s)*.26,0,0)
            p[f"upper_arm_{side}"]=(-stride*s*.58-(.22 if run else 0),0,-.05 if side=="l" else .05)
            p[f"forearm_{side}"]=(-.65 if run else -.14,0,0)
        p["chest"]=(.10 if run else .025,.05*math.sin(a),0)
    if clip.startswith("Carry"):
        p["upper_arm_l"]=(-.68,0,.19)
        p["upper_arm_r"]=(-.68,0,-.19)
        p["forearm_l"]=(-.70,0,0)
        p["forearm_r"]=(-.70,0,0)
    if clip=="Jump":
        p["thigh_l"]=(-.55,0,0); p["shin_l"]=(-.5,0,0)
        p["thigh_r"]=(.35,0,0); p["shin_r"]=(-.5,0,0)
        p["upper_arm_l"]=(-.5,0,-.3);p["upper_arm_r"]=(-.5,0,.3)
    if clip=="Slash":
        # Contact is t=.16/.52, matching CombatRules, followed by recovery.
        if t<.23: twist=-.75*t/.23
        elif t<.48: twist=-.75+1.7*(t-.23)/.25
        else: twist=.95*(1-(t-.48)/.52)
        p["chest"]=(.09,twist*.7,-.09*math.sin(PI*t))
        p["spine"]=(0,twist*.3,0)
        p["upper_arm_r"]=(-1.0*math.sin(PI*min(1,t*1.6)),twist,-.42)
        p["forearm_r"]=(-.40,0,-.12)
        p["hand_r"]=(0,0,-.48*math.sin(PI*t))
        p["upper_arm_l"]=(-.65,0,-.35)
    if clip in ["Slam","WorkHammer"]:
        # Wind-up then impact; global forward rotation turns the blade down.
        if t<.45: a=t/.45
        elif t<.57: a=1-(t-.45)/.12
        else: a=0
        p["upper_arm_r"]=(-.25-2.3*a,0,.18)
        p["forearm_r"]=(-.25-.3*a,0,0)
        p["upper_arm_l"]=(-.1-1.1*a,0,-.15)
        p["chest"]=(-.12*a+.25*math.sin(PI*max(0,t-.45)/.55),0,0)
        p["thigh_l"]=(-.1,0,0);p["shin_l"]=(-.12,0,0)
    if clip=="Dodge":
        p["chest"]=(.55,0,0);p["thigh_l"]=(-.68,0,0);p["shin_l"]=(-.95,0,0)
        p["thigh_r"]=(.5,0,0);p["shin_r"]=(-.45,0,0)
        p["upper_arm_l"]=(.45,0,-.24);p["upper_arm_r"]=(.45,0,.24)
        lift=-.19
    if clip=="Cast":
        wave=math.sin(PI*t)
        p["upper_arm_r"]=(-1.4*wave,0,.12);p["forearm_r"]=(-.3,0,0)
        p["upper_arm_l"]=(-1.1*wave,0,-.3);p["chest"]=(0,-.16*wave,0)
    return p,lift


class GLB:
    def __init__(self):
        self.bin=bytearray()
        self.g={"asset":{"version":"2.0","generator":"Starlantern original adult mesh authoring v2"},"scene":0,
                "scenes":[{"nodes":[0]}],"nodes":[{"name":"ExpeditionAdult","children":[]}],
                "bufferViews":[],"accessors":[],"meshes":[],"materials":[],"animations":[]}
        for name,(color,rough,metal) in PALETTE.items():
            rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
            # glTF baseColorFactor is linear; keep the authored sRGB palette in game.
            rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
            self.g["materials"].append({"name":name,"doubleSided":True,"pbrMetallicRoughness":{
                "baseColorFactor":[*rgb,1],"roughnessFactor":rough,"metallicFactor":metal}})
        for name,parent,world in BONES:
            node={"name":name,"translation":sub(world,REST[parent]) if parent else world,"children":[]}
            idx=len(self.g["nodes"])
            self.g["nodes"].append(node)
            self.g["nodes"][JOINT[parent]+1 if parent else 0]["children"].append(idx)
        mats=[]
        for _,_,p in BONES:
            mats.append([1,0,0,0,0,1,0,0,0,0,1,0,-p[0],-p[1],-p[2],1])
        self.g["skins"]=[{"name":"ExpeditionRig","joints":list(range(1,len(BONES)+1)),"skeleton":1,
                          "inverseBindMatrices":self.access(mats,"MAT4")}]

    def access(self,values,kind,fmt="f"):
        flat=[v for item in values for v in (item if isinstance(item,(tuple,list)) else [item])]
        while len(self.bin)%4:self.bin.append(0)
        offset=len(self.bin)
        raw=struct.pack("<"+fmt*len(flat),*flat)
        self.bin.extend(raw)
        view=len(self.g["bufferViews"])
        self.g["bufferViews"].append({"buffer":0,"byteOffset":offset,"byteLength":len(raw)})
        acc={"bufferView":view,"componentType":5126 if fmt=="f" else 5123,"count":len(values),"type":kind}
        if kind in ("VEC3","SCALAR"):
            rows=values if kind=="VEC3" else [(v,) for v in values]
            acc["min"]=[min(v[i] for v in rows) for i in range(3 if kind=="VEC3" else 1)]
            acc["max"]=[max(v[i] for v in rows) for i in range(3 if kind=="VEC3" else 1)]
        self.g["accessors"].append(acc)
        return len(self.g["accessors"])-1

    def model(self,name,model,skinned=True):
        primitives=[]
        for mat,verts in model.parts.items():
            attrs={"POSITION":self.access([v[0] for v in verts],"VEC3"),"NORMAL":self.access([v[1] for v in verts],"VEC3")}
            if skinned:
                js=[];ws=[]
                for _,_,weight in verts:
                    active=[(JOINT[j],w) for j,w in weight.items() if w>0]
                    js.append([j for j,w in active]+[0]*(4-len(active)))
                    ws.append([w for j,w in active]+[0]*(4-len(active)))
                attrs["JOINTS_0"]=self.access(js,"VEC4","H")
                attrs["WEIGHTS_0"]=self.access(ws,"VEC4")
            primitives.append({"attributes":attrs,"material":list(PALETTE).index(mat),"mode":4})
        mesh=len(self.g["meshes"])
        self.g["meshes"].append({"name":name,"primitives":primitives})
        node={"name":name,"mesh":mesh}
        if skinned:node["skin"]=0
        idx=len(self.g["nodes"])
        self.g["nodes"].append(node)
        self.g["nodes"][0]["children"].append(idx)

    def animations(self):
        for clip,duration in [("Idle",3),("Walk",.85),("Run",.63),("Jump",.8),
                              ("Slash",.52),("Slam",.72),("Dodge",.28),("WorkHammer",.9),
                              ("CarryIdle",3),("CarryWalk",1),("Cast",.8)]:
            samples=33
            poses=[pose(clip,i/(samples-1)) for i in range(samples)]
            times=self.access([duration*i/(samples-1) for i in range(samples)],"SCALAR")
            anim={"name":clip,"channels":[],"samplers":[]}
            for j,(name,_,_) in enumerate(BONES):
                rot=self.access([quat(*p[name]) for p,l in poses],"VEC4")
                si=len(anim["samplers"])
                anim["samplers"].append({"input":times,"output":rot,"interpolation":"LINEAR"})
                anim["channels"].append({"sampler":si,"target":{"node":j+1,"path":"rotation"}})
            translation=self.access([(0,1+l,0) for p,l in poses],"VEC3")
            si=len(anim["samplers"])
            anim["samplers"].append({"input":times,"output":translation,"interpolation":"LINEAR"})
            anim["channels"].append({"sampler":si,"target":{"node":1,"path":"translation"}})
            self.g["animations"].append(anim)

    def save(self,path):
        while len(self.bin)%4:self.bin.append(0)
        self.g["buffers"]=[{"byteLength":len(self.bin)}]
        raw=json.dumps(self.g,separators=(",",":")).encode()
        raw+=b" "*((-len(raw))%4)
        data=struct.pack("<III",0x46546c67,2,28+len(raw)+len(self.bin))
        data+=struct.pack("<II",len(raw),0x4e4f534a)+raw
        data+=struct.pack("<II",len(self.bin),0x004e4942)+self.bin
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(data)
        print(f"Wrote {path.name}: {len(data):,} bytes, {len(BONES)} joints, {len(self.g['animations'])} clips")


if __name__=="__main__":
    glb=GLB()
    glb.model("Outfit",make_body())
    glb.model("HeroArmor",make_armor())
    for role in ["hero","carpenter","porter"]:
        glb.model("Face"+role.title(),make_face(role))
    glb.model("TravelPack",make_pack())
    glb.model("WorkApron",make_apron())
    glb.animations()
    glb.save(OUT)
    for name,model in [("expedition_axe",make_axe()),("carpenter_hammer",make_hammer())]:
        item=GLB()
        item.model(name,model,False)
        # Static tools contain no skeleton or animations; their pivot is the grip.
        item.g["scenes"][0]["nodes"]=[len(item.g["nodes"])-1]
        item.g.pop("skins")
        item.save(OUT.parent.parent/"props"/(name+".glb"))
