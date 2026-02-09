@tool
extends EditorScenePostImport

# --- Shader 路径配置 ---
# 1. 普通卡通材质 (实心物体)
const TOON_SHADER = preload("res://assets/shaders/flexible_toon.gdshader")
# 2. 玻璃/水体材质 (上一轮优化好的透明 Shader)
const GLASS_SHADER = preload("res://assets/shaders/flexible_toon_transparent.gdshader") 
# 3. 描边材质
const OUTLINE_SHADER = preload("res://assets/shaders/outline.gdshader")

# --- 关键词配置 ---
# 如果材质名字里包含这些词，强制识别为透明物体
const TRANSPARENT_KEYWORDS = ["glass", "water", "liquid", "trans", "ice"]

func _post_import(scene):
	iterate(scene)
	return scene

func iterate(node):
	if node is MeshInstance3D:
		apply_toon_to_mesh(node)
	
	for child in node.get_children():
		iterate(child)

func apply_toon_to_mesh(mesh_instance: MeshInstance3D):
	var mesh_resource = mesh_instance.mesh
	if not mesh_resource: return
	
	# 遍历 Mesh 的所有表面 (Surface)
	for i in mesh_resource.get_surface_count():
		# 获取原材质 (优先取 Override，没有则取 Mesh 自带)
		var old_mat = mesh_instance.get_surface_override_material(i)
		if old_mat == null:
			old_mat = mesh_resource.surface_get_material(i)
		
		# 如果没有材质，跳过
		if old_mat == null: continue
		
		# --- 1. 判断是否为透明物体 ---
		var is_transparent = check_is_transparent(old_mat)
		
		# --- 2. 创建新材质 ---
		var new_mat = ShaderMaterial.new()
		
		if is_transparent:
			# >>> 透明流程 <<<
			new_mat.shader = GLASS_SHADER
			
			# 针对玻璃的特殊参数调整
			new_mat.set_shader_parameter("fresnel_power", 2.0)
			new_mat.set_shader_parameter("edge_opacity", 0.8)
			new_mat.set_shader_parameter("center_opacity", 0.1)
			
			# 玻璃不需要黑色描边，通常也不需要 Next Pass，保持清透
			
		else:
			# >>> 实心流程 <<<
			new_mat.shader = TOON_SHADER
			
			# 针对实心物体的描边 (Next Pass)
			var outline_mat = ShaderMaterial.new()
			outline_mat.shader = OUTLINE_SHADER
			outline_mat.set_shader_parameter("outline_width", 0.01) # 甚至可以根据物体大小动态调整
			outline_mat.set_shader_parameter("outline_color", Color(0.0, 0.0, 0.0, 1.0))
			new_mat.next_pass = outline_mat
		
		# --- 3. 通用参数迁移 (Albedo & Texture) ---
		# 无论是玻璃还是实心，都需要基础颜色和贴图
		transfer_parameters(old_mat, new_mat, is_transparent)
		
		# --- 4. 应用回 MeshInstance ---
		# 使用 set_surface_override_material 避免修改原始 Mesh 资源文件
		mesh_instance.set_surface_override_material(i, new_mat)

# 辅助函数：检测材质是否透明
func check_is_transparent(mat: Material) -> bool:
	# 方式 A: 检查材质名称关键词 (最强力控制)
	var mat_name = mat.resource_name.to_lower()
	for kw in TRANSPARENT_KEYWORDS:
		if kw in mat_name:
			return true
	
	# 方式 B: 检查 StandardMaterial3D 的属性
	if mat is StandardMaterial3D:
		# 检查透明模式
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
		# 检查颜色 Alpha 值
		if mat.albedo_color.a < 0.95:
			return true
			
	return false

# 辅助函数：迁移参数
func transfer_parameters(old_mat: Material, new_mat: ShaderMaterial, is_transparent: bool):
	var color = Color.WHITE
	var texture = null
	
	if old_mat is StandardMaterial3D:
		color = old_mat.albedo_color
		texture = old_mat.albedo_texture
		# 迁移顶点颜色开关
		new_mat.set_shader_parameter("use_vertex_color", old_mat.vertex_color_use_as_albedo)
	
	# 或者尝试通用属性获取 (兼容 ORM 材质等)
	else:
		var c = old_mat.get("albedo_color")
		if c: color = c
		var t = old_mat.get("albedo_texture")
		if t: texture = t

	# --- 赋值 ---
	# 如果是玻璃，必须保留 Alpha；如果是实心，Alpha 通常设为 1.0 (除非你想做半透明实心)
	if not is_transparent:
		color.a = 1.0 
	
	new_mat.set_shader_parameter("albedo", color)
	
	if texture:
		new_mat.set_shader_parameter("albedo_texture", texture)
