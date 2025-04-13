package main

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"

// main :: proc() {
// 	mesh: Mesh
// 	err: Error

// 	if mesh, err = gltf_from_file("assets/cube.gltf", context.temp_allocator); err != nil {
// 		fmt.println("Failed to read gltf file", err)
// 	}

// 	fmt.println("Position", mesh.position)
// 	fmt.println("Normal", mesh.normal)
// 	fmt.println("Texture", mesh.texture)
// 	fmt.println("Indice", mesh.indice)
// }

@(private = "file")
GltfBuffer :: struct {
	fd:  os.Handle,
	len: u32,
}

Attribute :: union {
	[][3]f32,
	[][2]f32,
	[]u16,
	[]u32,
	[]i32,
	[]u8,
	[]i8,
	[]i16,
}

Mesh :: struct {
	position: Attribute,
	normal:   Attribute,
	texture:  Attribute,
	indice:   Attribute,
}

gltf_from_file :: proc(path: string, allocator: runtime.Allocator) -> (mesh: Mesh, err: Error) {
	value: json.Value
	j_err: json.Error
	bytes: []u8
	ok: bool
	os_err: os.Error

	if bytes, ok = os.read_entire_file(path); !ok do return mesh, .FileNotFound
	if value, j_err = json.parse(bytes, allocator = allocator); j_err != nil do return mesh, .GltfLoadFailed
	dir := filepath.dir(path, allocator)

	obj := value.(json.Object)
	if obj["asset"].(json.Object)["version"].(string) != "2.0" do return mesh, .GltfLoadFailed

	accessors := obj["accessors"].(json.Array)
	meshes := obj["meshes"].(json.Array)
	buffer_views := obj["bufferViews"].(json.Array)
	raw_buffers := obj["buffers"].(json.Array)

	buffers := make([]GltfBuffer, len(raw_buffers), allocator)

	for i in 0 ..< len(raw_buffers) {
		buffer := &buffers[i]
		raw := &raw_buffers[i].(json.Object)

		uri_array := [?]string{dir, raw["uri"].(string)}
		uri := filepath.join(uri_array[:], allocator)

		if buffer.fd, os_err = os.open(uri); os_err != nil do return mesh, .FileNotFound
		buffer.len = u32(raw["byteLength"].(f64))
	}

	for m in meshes {
		primitives := m.(json.Object)["primitives"].(json.Array)
		if len(primitives) > 1 do return mesh, .GltfLoadFailed

		primitive := primitives[0].(json.Object)
		attributes := primitive["attributes"].(json.Object)

		mesh.position = read_attribute(
			u32(attributes["POSITION"].(f64)),
			accessors,
			buffer_views,
			buffers,
			allocator,
		) or_return

		mesh.normal = read_attribute(
			u32(attributes["NORMAL"].(f64)),
			accessors,
			buffer_views,
			buffers,
			allocator,
		) or_return

		mesh.texture = read_attribute(
			u32(attributes["TEXCOORD_0"].(f64)),
			accessors,
			buffer_views,
			buffers,
			allocator,
		) or_return

		mesh.indice = read_attribute(
			u32(primitive["indices"].(f64)),
			accessors,
			buffer_views,
			buffers,
			allocator,
		) or_return
	}

	for buffer in buffers {
		if os.close(buffer.fd) != nil do return mesh, .FileNotFound
	}

	return mesh, nil
}

@(private = "file")
read_attribute :: proc(
	index: u32,
	accessors: json.Array,
	views: json.Array,
	buffers: []GltfBuffer,
	allocator: runtime.Allocator,
) -> (
	attribute: Attribute,
	err: Error,
) {
	accessor := accessors[index].(json.Object)
	view := views[u32(accessor["bufferView"].(f64))].(json.Object)
	data := read_buffer(view, buffers, allocator) or_return

	count := u32(accessor["count"].(f64))
	kind := accessor["type"].(string)

	switch u32(accessor["componentType"].(f64)) {
	case 5126:
		switch kind {
		case "VEC3":
			return ([^][3]f32)(&data[0])[0:count], nil
		case "VEC2":
			return ([^][2]f32)(&data[0])[0:count], nil
		}
	case 5123:
		switch kind {
		case "SCALAR":
			return ([^]u16)(&data[0])[0:count], nil
		}
	}

	return nil, .AttributeKindNotFound
}

@(private = "file")
read_buffer := proc(
	view: json.Object,
	buffers: []GltfBuffer,
	allocator: runtime.Allocator,
) -> (
	[]u8,
	Error,
) {
	index := u32(view["buffer"].(f64))
	offset := i64(view["byteOffset"].(f64))
	length := u32(view["byteLength"].(f64))
	buffer := buffers[index]

	i: i64
	err: os.Error
	data := make([]u8, length, allocator)
	if i, err = os.seek(buffer.fd, offset, os.SEEK_SET); err != nil do return nil, .FileNotFound

	read: int
	if read, err = os.read(buffer.fd, data); err != nil do return nil, .ReadFileFailed
	if read != int(length) do return nil, .ReadFileFailed

	return data, nil
}

// Error :: enum {
// 	OutOfMemory,
// 	FileNotFound,
// 	AttributeKindNotFound,
// 	ReadFileFailed,
// 	NumberParseFailed,
// 	CreateInstanceFailed,
// 	CreateBuffer,
// 	BeginCommandBufferFailed,
// 	EndCommandBufferFailed,
// 	AllocateCommandBufferFailed,
// 	VulkanLib,
// 	LayerNotFound,
// 	PhysicalDeviceNotFound,
// 	FamilyIndiceNotComplete,
// 	MemoryNotFound,
// 	EnviromentVariablesNotSet,
// 	WaylandSocketNotAvaiable,
// 	SendMessageFailed,
// 	BufferNotReleased,
// 	CreateDescriptorSetLayoutFailed,
// 	CreatePipelineFailed,
// 	GetImageModifier,
// 	AllocateDeviceMemory,
// 	CreateImageFailed,
// 	WaitFencesFailed,
// 	QueueSubmitFailed,
// 	CreateImageViewFailed,
// 	CreatePipelineLayouFailed,
// 	CreateDescriptorPoolFailed,
// 	CreateFramebufferFailed,
// 	GetFdFailed,
// 	SizeNotMatch,
// 	CreateShaderModuleFailed,
// 	AllocateDescriptorSetFailed,
// 	ExtensionNotFound,
// 	CreateDeviceFailed,
// 	CreateRenderPassFailed,
// 	CreateSemaphoreFailed,
// 	CreateFenceFailed,
// 	CreateCommandPoolFailed,
// 	SocketConnectFailed,
// 	GltfLoadFailed,
// }
