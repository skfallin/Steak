"""Create the editable Steak brand model and transparent product render."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

OUT = Path('/Users/fra/Documents/iphone_lock/Art/SteakLogo')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    return mat

fat = material('Warm ivory fat', (0.96, 0.79, 0.64), 0.32)
meat = material('Ruby red meat', (0.62, 0.015, 0.034), 0.3)
vein = material('Cream marbling', (1.0, 0.88, 0.76), 0.36)
side = material('Deep red cut', (0.34, 0.008, 0.018), 0.38)

# A rounded ribeye silhouette, with a subtle notch on the left.
control = [(-1.53,-0.45),(-1.4,-0.91),(-0.78,-1.03),(-0.1,-0.86),(0.65,-0.77),(1.3,-0.35),(1.49,0.29),(1.22,0.83),(0.64,1.04),(-0.06,0.93),(-0.66,0.65),(-1.2,0.43),(-1.27,0.04)]

def smooth_loop(points, steps=10):
    result=[]
    for i,p in enumerate(points):
        a,b,c,d=[Vector(points[j % len(points)]) for j in (i-1,i,i+1,i+2)]
        for k in range(steps):
            t=k/steps
            v=0.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
            result.append(tuple(v))
    return result

outline=smooth_loop(control)
def slab(name, scale, low, high, mat, bevel):
    coords=[(x*scale,y*scale,z) for z in (low,high) for x,y in outline]
    n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(coords,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    mod=obj.modifiers.new('Soft cut edge','BEVEL');mod.width=bevel;mod.segments=4
    normal=obj.modifiers.new('Surface normals','WEIGHTED_NORMAL')
    return obj

slab('Ribeye fat rim',1,0,0.43,fat,0.085)
slab('Meat cut body',0.94,0.018,0.405,side,0.065)
slab('Ribeye red face',0.905,0.34,0.469,meat,0.047)

def line(name, points, radius, mat):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D'
    curve.bevel_depth=radius;curve.bevel_resolution=3;curve.resolution_u=16
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
    for p,co in zip(spline.bezier_points,points):
        p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.scale.z = 0.16
    obj.location.z = 0.473 * 0.84
    spline.bezier_points[0].radius = 0.5
    spline.bezier_points[-1].radius = 0.5
    return obj

# Three broad lobes share one continuous seam and a single connected branch.
line('Central fat seam', [
    (-0.9, -0.77, 0.473),
    (-0.53, -0.46, 0.473),
    (-0.07, -0.25, 0.473),
    (0.18, 0.17, 0.473),
    (0.07, 0.55, 0.473),
    (-0.2, 0.81, 0.473),
], 0.055, vein)
branch = line('Ribeye cap seam', [
    (0.18, 0.17, 0.473),
    (0.57, 0.39, 0.473),
    (1.03, 0.68, 0.473),
], 0.044, vein)
branch.data.splines[0].bezier_points[0].radius = 1.0

models=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
root=bpy.data.objects.new('Steak Logo',None);bpy.context.collection.objects.link(root)
for obj in models:obj.parent=root
root.rotation_euler[2]=math.radians(24)

scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_x=1024;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.world.color=(0.25,0.25,0.25)

def aim(obj, target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3,-5.5,7.3))
camera=bpy.context.object;camera.name='Logo orthographic camera';camera.data.type='ORTHO';camera.data.ortho_scale=3.9
scene.camera=camera;aim(camera,(0,0,.2))
for name,loc,power,size in [('Key softbox',(-3,-4,7),650,5),('Fill softbox',(4,-1,4),350,4),('Rim softbox',(0,4,5),850,3)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object;light.name=name;light.data.energy=power;light.data.shape='DISK';light.data.size=size;aim(light,(0,0,0))
scene.view_settings.view_transform='Standard'
scene.view_settings.exposure=-0.8
bpy.ops.object.select_all(action='DESELECT')
for obj in models:obj.select_set(True)
bpy.context.view_layer.objects.active=models[0]
# Export actual geometry so the marbling survives in mobile viewers.
bpy.ops.object.convert(target='MESH')
bpy.ops.export_scene.gltf(filepath=str(OUT/'SteakLogo.glb'),export_format='GLB',use_selection=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
scene.render.filepath=str(OUT/'SteakLogo.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'SteakLogo.blend'))
bpy.ops.render.render(write_still=True)
(OUT/'complete.txt').write_text('Blender scene, GLB and transparent render generated.\n')
