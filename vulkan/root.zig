const MAX_FRAMES: u32 = 10;

const VALIDATION_LAYERS: []const [*c]const u8 = &.{
	"VK_LAYER_KHRONOS_validation",
};

const INSTANCE_EXTENSIONS: []const [*c]const u8 = &.{
	"VK_KHR_surface",
	"VK_KHR_wayland_surface",
};

const DEVICE_EXTENSIONS: []const [*c]const u8 = &.{
  "VK_KHR_external_memory_fd",
  "VK_EXT_external_memory_dma_buf",
  "VK_EXT_image_drm_format_modifier",
};

const LibraryPointers = struct {
	vkEnumerateInstanceLayerProperties: @typeInfo(c.PFN_vkEnumerateInstanceLayerProperties).optional.child,
	vkCreateInstance: @typeInfo(c.PFN_vkCreateInstance).optional.child,
	vkGetInstanceProcAddr: @typeInfo(c.PFN_vkGetInstanceProcAddr).optional.child,
};

const InstancePointers = struct {
	vkEnumeratePhysicalDevices: @typeInfo(c.PFN_vkEnumeratePhysicalDevices).optional.child,
	vkGetPhysicalDeviceProperties: @typeInfo(c.PFN_vkGetPhysicalDeviceProperties).optional.child,
	vkGetPhysicalDeviceQueueFamilyProperties: @typeInfo(c.PFN_vkGetPhysicalDeviceQueueFamilyProperties).optional.child,
	vkGetPhysicalDeviceSurfaceSupportKHR: @typeInfo(c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR).optional.child,
	//vkCreateWaylandSurfaceKHR: @typeInfo(c.PFN_vkCreateWaylandSurfaceKHR).optional.child,
	vkGetPhysicalDeviceFeatures2: @typeInfo(c.PFN_vkGetPhysicalDeviceFeatures2).optional.child,
	vkEnumerateDeviceExtensionProperties: @typeInfo(c.PFN_vkEnumerateDeviceExtensionProperties).optional.child,
	vkGetPhysicalDeviceMemoryProperties: @typeInfo(c.PFN_vkGetPhysicalDeviceMemoryProperties).optional.child,
	vkCreateDevice: @typeInfo(c.PFN_vkCreateDevice).optional.child,
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR: @typeInfo(c.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR).optional.child,
	vkGetPhysicalDeviceSurfaceFormatsKHR: @typeInfo(c.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR).optional.child,
	vkGetDeviceProcAddr: @typeInfo(c.PFN_vkGetDeviceProcAddr).optional.child,
	vkGetPhysicalDeviceFormatProperties2: @typeInfo(c.PFN_vkGetPhysicalDeviceFormatProperties2).optional.child,
	vkGetPhysicalDeviceImageFormatProperties2: @typeInfo(c.PFN_vkGetPhysicalDeviceImageFormatProperties2).optional.child,
};

const DevicePointers = struct {
	vkGetDeviceQueue: @typeInfo(c.PFN_vkGetDeviceQueue).optional.child,
	vkDestroyCommandPool: @typeInfo(c.PFN_vkDestroyCommandPool).optional.child,
	vkCreateBuffer: @typeInfo(c.PFN_vkCreateBuffer).optional.child,
	vkGetBufferMemoryRequirements: @typeInfo(c.PFN_vkGetBufferMemoryRequirements).optional.child,
	vkAllocateMemory: @typeInfo(c.PFN_vkAllocateMemory).optional.child,
	vkBindBufferMemory: @typeInfo(c.PFN_vkBindBufferMemory).optional.child,
	vkMapMemory: @typeInfo(c.PFN_vkMapMemory).optional.child,
	vkUnmapMemory: @typeInfo(c.PFN_vkUnmapMemory).optional.child,
	// vkCreateSwapchainKHR: @typeInfo(c.PFN_vkCreateSwapchainKHR).optional.child,
	// vkDestroySwapchainKHR: @typeInfo(c.PFN_vkDestroySwapchainKHR).optional.child,
	// vkGetSwapchainImagesKHR: @typeInfo(c.PFN_vkGetSwapchainImagesKHR).optional.child,
	vkCreateImageView: @typeInfo(c.PFN_vkCreateImageView).optional.child,
	vkDestroyImageView: @typeInfo(c.PFN_vkDestroyImageView).optional.child,
	vkCreatePipelineLayout: @typeInfo(c.PFN_vkCreatePipelineLayout).optional.child,
	vkCreateShaderModule: @typeInfo(c.PFN_vkCreateShaderModule).optional.child,
	vkDestroyShaderModule: @typeInfo(c.PFN_vkDestroyShaderModule).optional.child,
	vkCreateGraphicsPipelines: @typeInfo(c.PFN_vkCreateGraphicsPipelines).optional.child,
	vkCreateCommandPool: @typeInfo(c.PFN_vkCreateCommandPool).optional.child,
	vkAllocateCommandBuffers: @typeInfo(c.PFN_vkAllocateCommandBuffers).optional.child,
	vkCreateFence: @typeInfo(c.PFN_vkCreateFence).optional.child,
	vkCreateSemaphore: @typeInfo(c.PFN_vkCreateSemaphore).optional.child,
	// vkAcquireNextImageKHR: @typeInfo(c.PFN_vkAcquireNextImageKHR).optional.child,
	vkWaitForFences: @typeInfo(c.PFN_vkWaitForFences).optional.child,
	vkResetFences: @typeInfo(c.PFN_vkResetFences).optional.child,
	vkBeginCommandBuffer: @typeInfo(c.PFN_vkBeginCommandBuffer).optional.child,
	vkCmdBeginRendering: @typeInfo(c.PFN_vkCmdBeginRendering).optional.child,
	vkCmdBindPipeline: @typeInfo(c.PFN_vkCmdBindPipeline).optional.child,
	vkCmdSetViewport: @typeInfo(c.PFN_vkCmdSetViewport).optional.child,
	vkCmdSetScissor: @typeInfo(c.PFN_vkCmdSetScissor).optional.child,
	vkCmdBindVertexBuffers: @typeInfo(c.PFN_vkCmdBindVertexBuffers).optional.child,
	vkCmdDraw: @typeInfo(c.PFN_vkCmdDraw).optional.child,
	vkCmdEndRendering: @typeInfo(c.PFN_vkCmdEndRendering).optional.child,
	vkEndCommandBuffer: @typeInfo(c.PFN_vkEndCommandBuffer).optional.child,
	vkQueueSubmit: @typeInfo(c.PFN_vkQueueSubmit).optional.child,
	// vkQueuePresentKHR: @typeInfo(c.PFN_vkQueuePresentKHR).optional.child,
	vkCmdPipelineBarrier2: @typeInfo(c.PFN_vkCmdPipelineBarrier2).optional.child,
	vkQueueWaitIdle: @typeInfo(c.PFN_vkQueueWaitIdle).optional.child,
	vkCmdDrawIndexed: @typeInfo(c.PFN_vkCmdDrawIndexed).optional.child,
	vkCmdBindIndexBuffer: @typeInfo(c.PFN_vkCmdBindIndexBuffer).optional.child,
	vkCreateDescriptorSetLayout: @typeInfo(c.PFN_vkCreateDescriptorSetLayout).optional.child,
	vkCreateDescriptorPool: @typeInfo(c.PFN_vkCreateDescriptorPool).optional.child,
	vkUpdateDescriptorSets: @typeInfo(c.PFN_vkUpdateDescriptorSets).optional.child,
	vkAllocateDescriptorSets: @typeInfo(c.PFN_vkAllocateDescriptorSets).optional.child,
	vkCmdBindDescriptorSets: @typeInfo(c.PFN_vkCmdBindDescriptorSets).optional.child,
	vkWaitSemaphores: @typeInfo(c.PFN_vkWaitSemaphores).optional.child,
};

pub const Library = struct {
	handle: std.DynLib,
	pfn: LibraryPointers = undefined,
	instance: InstancePointers = undefined,
	device: DevicePointers = undefined,

	pub fn init(self: *Library) !void {
		self.handle = std.DynLib.open("libvulkan.so") catch return error.VulkanLibrary;

		inline for (@typeInfo(LibraryPointers).@"struct".fields) |field| {
			if (self.handle.lookup(field.type, field.name)) |ptr| {
				@field(&self.pfn, field.name) = @ptrCast(ptr);
			} else {
				std.debug.print("Missing  symbol: {s}\n", .{field.name});
				return error.LibrarySymbol;
			}
		}
	}

	pub fn load_instance(self: *Library, instance: Instance) !void {
		inline for (@typeInfo(InstancePointers).@"struct".fields) |field| {
			if (self.pfn.vkGetInstanceProcAddr(instance.handle, field.name)) |ptr| {
				@field(&self.instance, field.name) = @ptrCast(ptr);
			} else {
				std.debug.print("Missing  symbol: {s}\n", .{field.name});
				return error.LibrarySymbol;
			}
		}
	}

	pub fn load_device(self: *Library, device: Device) !void {
		inline for (@typeInfo(DevicePointers).@"struct".fields) |field| {
			if (self.instance.vkGetDeviceProcAddr(device.handle, field.name)) |ptr| {
				@field(&self.device, field.name) = @ptrCast(ptr);
			} else {
				std.debug.print("Missing  symbol: {s}\n", .{field.name});
				return error.LibrarySymbol;
			}
		}
	}
};

fn check(code: i32) !void {
	if (c.VK_SUCCESS != code) {
		std.debug.print("Code: {d}\n", .{code});
		return error.Failed;
	}
}

pub const Vulkan = struct {
	lib: Library,
	instance: Instance,
	//surface: Surface,
	//device: Device,

	//swapchain: Swapchain,
	//pipeline: Pipeline,
	//command_allocator: Command.Allocator,
	//descriptor_allocator: Descriptor.Allocator,

	//set_layouts: Descriptor.Set.Layouts,

	//semaphores: Semaphores,
	//fences: Fences,

	//render_groups: std.ArrayList(RenderGroup),
	//sets_to_update: std.ArrayList(Descriptor.UpdateInfo),

	pub const Vertex = struct {
		position: [3]f32,
		color: [3]f32,
	};

	pub fn init(allocator: *Allocator, width: usize, height: usize) !*Vulkan {
		_ = width;
		_ = height;

		const self = try allocator.main.create(Vulkan);
		const lib = try allocator.main.create(Library);

		try lib.init();

		const instance = try Instance.init(allocator, lib);
		const device = try Device.init(allocator, instance, lib);
		const drm_modifiers = try get_drm_modifiers(allocator, lib, device);

		for (drm_modifiers) |modifier| {
			std.debug.print("modifier: {}\n", .{modifier});
		}

		return self;

		// cons format = .B8R8G8A8_SRGB;
		// const depth_format = .D32_SFLOAT_S8_UINT;

		// try self.surface.init(self, display, surface);
		// try self.device.init(self);

		// self.semaphores.init();
		// self.fences.init();

		// try self.command_allocator.init(self, 10);
		// try self.swapchain.startup(self, width, height);

		// const input_layouts = [_]Input.Layout{
			// try .init(Vertex, self),
		// };

		// const input = try Input.init(&input_layouts, self.allocator.tmp);

		// const set_layouts = [_]Descriptor.Set.Layout{
			// try .init(self, &.{Descriptor.Set.Layout.Binding.init(.storage, .vertex, 1)}),
			// try .init(self, &.{Descriptor.Set.Layout.Binding.init(.uniform, .vertex, 1)}),
		// };

		// self.set_layouts = try Descriptor.Set.Layouts.init(self, &set_layouts);

		// try self.pipeline.init(self, input, self.set_layouts);

		// const descriptor_sizes = [_]Descriptor.Size{
			// .init(.storage, 10),
			// .init(.uniform, 10),
		// };

		// try self.descriptor_allocator.init(self, &descriptor_sizes, 20);

		// self.sets_to_update = try std.ArrayList(Descriptor.UpdateInfo).initCapacity(self.allocator.main, 10);
		// self.render_groups = try std.ArrayList(RenderGroup).initCapacity(self.allocator.main, 10);
	}

	// pub fn addDescriptorSet(self: *Context, index: usize) !*Descriptor.Set {
		// const descriptor = try self.descriptor_allocator.alloc(self, self.set_layouts.childs[index..]);
// 
		// return &descriptor[0];
	// }
// 
	// pub fn updateDescriptorSet(self: *Context, set: *Descriptor.Set, range: Buffer.Range, binding: u32) void {
		// self.sets_to_update.appendAssumeCapacity(.{
			// .set = set,
			// .binding = binding,
			// .range = range,
		// });
	// }
// 
	// pub fn addPublicBuffer(self: *Context, T: type, kind: Buffer.Usage.Kind, capacity: usize) !Buffer {
		// return try Buffer.init(
			// T,
			// self,
			// .init(&.{kind}),
			// .init(&.{ .host_visible, .host_coherent }),
			// .exclusive,
			// capacity,
		// );
	// }
// 
	// pub fn addRenderGroup(self: *Context, vertices: []Vertex, indices: []u16, sets: []const *Descriptor.Set) !*RenderGroup {
		// var vert = try Buffer.init(Vertex, self, .init(&.{.vertex}), .init(&.{ .host_visible, .host_coherent }), .exclusive, vertices.len);
		// var ind = try Buffer.init(u16, self, .init(&.{.index}), .init(&.{ .host_visible, .host_coherent }), .exclusive, indices.len);
// 
		// try vert.append(Vertex, self, vertices);
		// try ind.append(u16, self, indices);
// 
		// const render = try self.render_groups.addOne(self.allocator.main);
		// try render.init(self, vert, ind, sets);
// 
		// return render;
	// }
// 
	// pub fn changeRenderSize(self: *Context, width: u32, height: u32) !void {
		// try self.swapchain.new(self, width, height);
	// }
// 
	// pub fn renderFrame(self: *Context) !void {
		// const image = try self.swapchain.nextImage(self);
		// const command_buffer = &self.swapchain.command_buffers[image];
		// const swapchain_semaphore = self.swapchain.semaphores[image];
		// const extent = self.swapchain.extent;
// 
		// for (self.sets_to_update.items) |update| {
			// try update.set.update(self, update.range, update.binding);
		// }
// 
		// self.sets_to_update.clearRetainingCapacity();
// 
		// const begin_info = c.VkCommandBufferBeginInfo{
			// .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
			// .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
		// };
// 
		// const background_color = .{ 0.0, 0.0, 0.0, 1.0 };
// 
		// const clear_color = c.VkClearValue{
			// .color = .{ .float32 = background_color },
		// };
// 
		// const color_attachment = c.VkRenderingAttachmentInfo{
			// .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
			// .imageView = self.swapchain.image_views[image],
			// .imageLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			// .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
			// .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
			// .clearValue = clear_color,
		// };
// 
		// const rendering_info = c.VkRenderingInfo{
			// .sType = c.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
			// .layerCount = 1,
			// .colorAttachmentCount = 1,
			// .pColorAttachments = &color_attachment,
			// .renderArea = .{
				// .offset = .{ .x = 0, .y = 0 },
				// .extent = extent,
			// },
		// };
// 
		// const viewport = c.VkViewport{
			// .width = @floatFromInt(extent.width),
			// .height = @floatFromInt(extent.height),
			// .minDepth = 0.0,
			// .maxDepth = 1.0,
		// };
// 
		// const scissor = c.VkRect2D{
			// .extent = extent,
		// };
// 
		// const offset = [_]c.VkDeviceSize{0};
// 
		// if (c.VK_SUCCESS != self.lib.device.vkBeginCommandBuffer(command_buffer.handle, &begin_info)) return error.BeginCommandBuffer;
// 
		// transitionImage(
			// self,
			// command_buffer,
			// self.swapchain.images[image],
			// c.VK_IMAGE_LAYOUT_UNDEFINED,
			// c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			// c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
			// c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
			// 0,
			// c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
		// );
// 
		// self.lib.device.vkCmdBeginRendering(command_buffer.handle, &rendering_info);
		// self.lib.device.vkCmdBindPipeline(command_buffer.handle, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline.handle);
		// self.lib.device.vkCmdSetViewport(command_buffer.handle, 0, 1, &viewport);
		// self.lib.device.vkCmdSetScissor(command_buffer.handle, 0, 1, &scissor);
// 
		// for (0..self.render_groups.items.len) |i| {
			// const r = self.render_groups.items[i];
// 
			// const sets = try self.allocator.tmp.alloc(c.VkDescriptorSet, r.sets.len);
// 
			// for (0..sets.len) |j| {
				// sets[j] = r.sets[j].handle;
			// }
// 
			// self.lib.device.vkCmdBindVertexBuffers(command_buffer.handle, 0, 1, &r.vertices.handle, &offset);
			// self.lib.device.vkCmdBindIndexBuffer(command_buffer.handle, r.indices.handle, 0, c.VK_INDEX_TYPE_UINT16);
			// self.lib.device.vkCmdBindDescriptorSets(command_buffer.handle, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline.layout, 0, @intCast(sets.len), sets.ptr, 0, null);
			// self.lib.device.vkCmdDrawIndexed(command_buffer.handle, r.indices.len, @intCast(sets.len), 0, 0, 0);
		// }
// 
		// self.lib.device.vkCmdEndRendering(command_buffer.handle);
// 
		// transitionImage(
			// self,
			// command_buffer,
			// self.swapchain.images[image],
			// c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
			// c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
			// c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
			// c.VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT,
			// c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
			// 0,
		// );
// 
		// if (c.VK_SUCCESS != self.lib.device.vkEndCommandBuffer(command_buffer.handle)) return error.EndCommandBuffer;
// 
		// const wait = [_]c.VkPipelineStageFlags{
			// c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
		// };
// 
		// const semaphores: []const c.VkSemaphore = &.{ swapchain_semaphore.handle, command_buffer.semaphore.handle };
// 
		// const info = c.VkSubmitInfo{
			// .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
			// .waitSemaphoreCount = 1,
			// .pWaitSemaphores = semaphores.ptr,
			// .pWaitDstStageMask = &wait,
			// .commandBufferCount = 1,
			// .pCommandBuffers = &command_buffer.handle,
			// .signalSemaphoreCount = 1,
			// .pSignalSemaphores = &command_buffer.semaphore.handle,
		// };
// 
		// const swapchain_fence = self.swapchain.fences[image];
// 
		// if (c.VK_SUCCESS != self.lib.device.vkQueueSubmit(self.device.queue, 1, &info, swapchain_fence.handle)) return error.SubmitQueue;
// 
		// const present_info = c.VkPresentInfoKHR{
			// .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
			// .waitSemaphoreCount = 1,
			// .pWaitSemaphores = &command_buffer.semaphore.handle,
			// .swapchainCount = 1,
			// .pSwapchains = &self.swapchain.handle,
			// .pImageIndices = &image,
		// };
// 
		// if (c.VK_SUCCESS != self.lib.device.vkQueuePresentKHR(self.device.queue, &present_info)) return error.PresentQueue;
	// }
};

pub const Instance = struct {
	handle: c.VkInstance,

	pub fn init(allocator: *Allocator, lib: *Library) !Instance {
		var self: Instance = undefined;
		var layer_count: u32 = 0;

		if (c.VK_SUCCESS != lib.pfn.vkEnumerateInstanceLayerProperties(&layer_count, null)) return error.EnumerateInstanceLayerProperties;
		const layers = try allocator.tmp.alloc(c.VkLayerProperties, layer_count);
		if (c.VK_SUCCESS != lib.pfn.vkEnumerateInstanceLayerProperties(&layer_count, layers.ptr)) return error.EnumerateInstanceLayerProperties;

		for (VALIDATION_LAYERS) |required| {
			for (layers) |layer| {
				const name = @as([*c]const u8, &layer.layerName);
				if (std.mem.eql(u8, std.mem.span(required), std.mem.span(name))) break;
			} else return error.ValidationLayer;
		}

		const application_info = c.VkApplicationInfo{
			.sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
			.pApplicationName = "Hello triangle",
			.applicationVersion = c.VK_MAKE_VERSION(0, 0, 1),
			.pEngineName = "No Engine",
			.engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
			.apiVersion = c.VK_MAKE_VERSION(1, 4, 3),
		};

		const create_info = c.VkInstanceCreateInfo{
			.sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
			.pApplicationInfo = &application_info,
			.enabledLayerCount = @intCast(VALIDATION_LAYERS.len),
			.ppEnabledLayerNames = &VALIDATION_LAYERS[0],
			.enabledExtensionCount = @intCast(INSTANCE_EXTENSIONS.len),
			.ppEnabledExtensionNames = &INSTANCE_EXTENSIONS[0],
		};

		try check(lib.pfn.vkCreateInstance(&create_info, null, &self.handle));
		try lib.load_instance(self);

		return self;
	}
};

pub const Device = struct {
	handle: c.VkDevice,
	physical: c.VkPhysicalDevice,
	family_index: u32,
	queue: c.VkQueue,
	memory_properties: c.VkPhysicalDeviceMemoryProperties,

	pub fn init(allocator: *Allocator, instance: Instance, lib: *Library) !Device {
		var self: Device = undefined;

		var device_count: u32 = 0;
		try check(lib.instance.vkEnumeratePhysicalDevices(instance.handle, &device_count, null));

		const devices = try allocator.tmp.alloc(c.VkPhysicalDevice, device_count);
		defer allocator.tmp.free(devices);

		try check(lib.instance.vkEnumeratePhysicalDevices(instance.handle, &device_count, devices.ptr));

		var query_device_dynamic_state = c.VkPhysicalDeviceExtendedDynamicStateFeaturesEXT{
			.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT,
		};

		var query_device_features_1_3 = c.VkPhysicalDeviceVulkan13Features{
			.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
			.pNext = &query_device_dynamic_state,
		};

		var query_device_features = c.VkPhysicalDeviceFeatures2{
			.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
			.pNext = &query_device_features_1_3,
		};

		var physical_device_points: u8 = 0;

		outer: for (devices) |device| {
			var properties: c.VkPhysicalDeviceProperties = undefined;
			lib.instance.vkGetPhysicalDeviceProperties(device, &properties);

			if (properties.apiVersion < c.VK_API_VERSION_1_3) {
				continue;
			}

			lib.instance.vkGetPhysicalDeviceFeatures2(device, &query_device_features);

			if (query_device_features_1_3.dynamicRendering != c.VK_TRUE) continue :outer;
			if (query_device_features_1_3.synchronization2 != c.VK_TRUE) continue :outer;
			if (query_device_dynamic_state.extendedDynamicState != c.VK_TRUE) continue :outer;

			var extension_count: u32 = 0;
			try check(lib.instance.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, null));

			const extensions = try allocator.tmp.alloc(c.VkExtensionProperties, extension_count);
			defer allocator.tmp.free(extensions);

			try check(lib.instance.vkEnumerateDeviceExtensionProperties(device, null, &extension_count, extensions.ptr));

			for (DEVICE_EXTENSIONS) |required| {
				for (extensions) |extension| {
					const ext = @as([*c]const u8, &extension.extensionName);
					if (std.mem.eql(u8, std.mem.span(required), std.mem.span(ext))) break;
				} else continue :outer;
			}

			var family_count: u32 = 0;
			lib.instance.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, null);

			const family_properties = try allocator.tmp.alloc(c.VkQueueFamilyProperties, family_count);
			defer allocator.tmp.free(family_properties);

			lib.instance.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, family_properties.ptr);

			var index: u32 = 0;
			for (family_properties, 0..) |property, i| {
				if (property.queueFlags & c.VK_QUEUE_TRANSFER_BIT == 0) continue;
				if (property.queueFlags & c.VK_QUEUE_GRAPHICS_BIT == 0) continue;

				index = @intCast(i);

				break;
			} else continue :outer;

			const points: u8 = switch (properties.deviceType) {
				c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => 5,
				c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => 4,
				c.VK_PHYSICAL_DEVICE_TYPE_CPU => 3,
				c.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => 2,
				else => 1,
			};

			if (points > physical_device_points) {
				physical_device_points = points;
				self.physical = device;
				self.family_index = index;
			}
		}

		lib.instance.vkGetPhysicalDeviceMemoryProperties(self.physical, &self.memory_properties);

		query_device_features_1_3 = .{
			.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
			.pNext = &query_device_dynamic_state,
			.synchronization2 = c.VK_TRUE,
			.dynamicRendering = c.VK_TRUE,
		};

		const queue_priority: f32 = 1.0;

		const queue_info = c.VkDeviceQueueCreateInfo{
			.sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
			.queueFamilyIndex = self.family_index,
			.queueCount = 1,
			.pQueuePriorities = &queue_priority,
		};

		const info = c.VkDeviceCreateInfo{
			.sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
			.pNext = &query_device_features,
			.queueCreateInfoCount = 1,
			.pQueueCreateInfos = &queue_info,
			.ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0],
			.enabledExtensionCount = DEVICE_EXTENSIONS.len,
		};

		try check(lib.instance.vkCreateDevice(self.physical, &info, null, &self.handle));
		try lib.load_device(self);

		lib.device.vkGetDeviceQueue(self.handle, self.family_index, 0, &self.queue);

		return self;
	}
};

fn get_drm_modifiers(allocator: *Allocator, lib: *Library, device: Device) ![]c.VkDrmFormatModifierPropertiesEXT {
	const render_features: c.VkFormatFeatureFlags = c.VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BIT | c.VK_FORMAT_FEATURE_COLOR_ATTACHMENT_BLEND_BIT;

	const texture_features: c.VkFormatFeatureFlags = c.VK_FORMAT_FEATURE_SAMPLED_IMAGE_BIT | c.VK_FORMAT_FEATURE_SAMPLED_IMAGE_FILTER_LINEAR_BIT;

	var modifier_property_list: c.VkDrmFormatModifierPropertiesListEXT = .{
		.sType = c.VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
	};

	var properties: c.VkFormatProperties2 = .{
		.sType = c.VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2,
		.pNext = &modifier_property_list,
	};

	const format = c.VK_FORMAT_B8G8R8A8_SRGB;

	lib.instance.vkGetPhysicalDeviceFormatProperties2(device.physical, format, &properties);

	const count = modifier_property_list.drmFormatModifierCount;

	const modifiers = try allocator.tmp.alloc(c.VkDrmFormatModifierPropertiesEXT, count);
	modifier_property_list.pDrmFormatModifierProperties = modifiers.ptr;

	lib.instance.vkGetPhysicalDeviceFormatProperties2(device.physical, format, &properties);

	const image_modifier_info: c.VkPhysicalDeviceImageDrmFormatModifierInfoEXT = .{
		.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT,
		.sharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
	};

	const external_image_info: c.VkPhysicalDeviceExternalImageFormatInfo = .{
		.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
		.pNext = &image_modifier_info,
		.handleType = c.VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT,
	};

	const image_info: c.VkPhysicalDeviceImageFormatInfo2 = .{
		.sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
		.pNext = &external_image_info,
		.format = format,
		.usage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
		.type = c.VK_IMAGE_TYPE_2D,
		.tiling = c.VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT,
	};

	var external_image_properties: c.VkExternalImageFormatProperties = .{
		.sType = c.VK_STRUCTURE_TYPE_EXTERNAL_IMAGE_FORMAT_PROPERTIES,
	};

	var image_properties: c.VkImageFormatProperties2 = .{
		.sType = c.VK_STRUCTURE_TYPE_IMAGE_FORMAT_PROPERTIES_2,
		.pNext = &external_image_properties,
	};

	try check(lib.instance.vkGetPhysicalDeviceImageFormatProperties2(device.physical, &image_info, &image_properties));

	const memory_features = external_image_properties.externalMemoryProperties.externalMemoryFeatures;
	if (memory_features & c.VK_EXTERNAL_MEMORY_FEATURE_IMPORTABLE_BIT_NV == 0) return error.MissingImport;
	if (memory_features & c.VK_EXTERNAL_MEMORY_FEATURE_EXPORTABLE_BIT_NV == 0) return error.MissingExport;

	var valid_modifiers = try std.ArrayList(c.VkDrmFormatModifierPropertiesEXT).initCapacity(allocator.main, count);

	for (modifiers) |modifier| {
		if (modifier.drmFormatModifierTilingFeatures & render_features == 0) continue;
		if (modifier.drmFormatModifierTilingFeatures & texture_features == 0) continue;

		try valid_modifiers.appendBounded(modifier);
	}

	return valid_modifiers.items;
}

//
// pub const Manager = struct {
//     fences: []c.VkFence,
//     acquire_semaphores: []c.VkSemaphore,
//     release_semaphores: []c.VkSemaphore,
//
//     descriptor_pool: c.VkDescriptorPool,
//     descriptor_sets: []DescriptorSet,
//     descriptor_set_count: u32,
//
//     pub fn init(self: *Manager, library: *Library, device: Device, allocator: *Allocator) !void {
//       const fence_info = c.VkFenceCreateInfo{
//         .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
//         .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
//       };
//
//       const command_info = c.VkCommandBufferAllocateInfo{
//         .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
//         .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
//         .commandPool = self.command_pool,
//         .commandBufferCount = MAX_FRAMES,
//       };
//
//       const semaphore_info = c.VkSemaphoreCreateInfo{
//         .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
//       };
//
//       self.fences = try allocator.main.alloc(c.VkFence, MAX_FRAMES);
//       self.acquire_semaphores = try allocator.main.alloc(c.VkSemaphore, MAX_FRAMES + 1);
//       self.release_semaphores = try allocator.main.alloc(c.VkSemaphore, MAX_FRAMES);
//
//       for (0..MAX_FRAMES) |i| {
//         if (c.VK_SUCCESS != library.device.vkCreateFence(device.handle, &fence_info, null, &self.fences[i])) return error.Fence;
//         if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.acquire_semaphores[i])) return error.Semaphore;
//         if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.release_semaphores[i])) return error.Semaphore;
//       }
//
//       if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.acquire_semaphores[MAX_FRAMES])) return error.Semaphore;
//
//       const descriptor_count: u32 = 10;
//       self.descriptor_sets = try allocator.main.alloc(DescriptorSet, descriptor_count);
//       self.descriptor_set_count = 0;
//
//       const descriptor_pool_sizes = &[_]c.VkDescriptorPoolSize{
//         .{
//           .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
//           .descriptorCount = descriptor_count,
//         },
//         .{
//           .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
//           .descriptorCount = descriptor_count,
//         },
//       };
//
//       const descriptor_pool_info = c.VkDescriptorPoolCreateInfo{
//         .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
//         .poolSizeCount = @intCast(descriptor_pool_sizes.len),
//         .pPoolSizes = descriptor_pool_sizes.ptr,
//         .maxSets = 10,
//       };
//
//       self.descriptor_pool = undefined;
//
//       if (c.VK_SUCCESS != library.device.vkCreateDescriptorPool(device.handle, &descriptor_pool_info, null, &self.descriptor_pool)) return error.DescriptorPool;
//     }
//
//     pub fn addDescriptorSet(self: *Manager, library: *Library, device: Device, layout: DescriptorSetLayout) !u32 {
//       if (self.descriptor_set_count >= 10) return error.OutOfDescriptors;
//       defer self.descriptor_set_count += 1;
//
//       const index = self.descriptor_set_count;
//       const descriptor_set = &self.descriptor_sets[index];
//       const allocate_info = c.VkDescriptorSetAllocateInfo{
//         .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
//         .descriptorPool = self.descriptor_pool,
//         .descriptorSetCount = 1,
//         .pSetLayouts = &layout.handle,
//       };
//
//       descriptor_set.layout = layout;
//       if (c.VK_SUCCESS != library.device.vkAllocateDescriptorSets(device.handle, &allocate_info, &descriptor_set.handle)) return error.OutOfDescriptors;
//
//       return index;
//     }
//
//     pub fn updateDescriptorSet(self: *Manager, library: *Library, device: Device, index: u32, binding: u32, range: Buffer.Range) !void {
//       const buffer_info = c.VkDescriptorBufferInfo{
//         .buffer = range.handle,
//         .range = range.size,
//         .offset = range.offset,
//       };
//
//       const set = self.descriptor_sets[index];
//       const write_set = c.VkWriteDescriptorSet{
//         .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
//         .dstSet = set.handle,
//         .dstBinding = binding,
//         .descriptorCount = 1,
//         .descriptorType = set.layout.bindings[binding].descriptorType,
//         .pBufferInfo = &buffer_info,
//       };
//
//       library.device.vkUpdateDescriptorSets(device.handle, 1, &write_set, 0, null);
//     }
// };
//
// fn transitionImage(context: *Context, command_buffer: *Command.Buffer, image: c.VkImage, old_layout: c.VkImageLayout, new_layout: c.VkImageLayout, src_stage: c.VkPipelineStageFlags2, dst_stage: c.VkPipelineStageFlags2, src_access: c.VkAccessFlags2, dst_access: c.VkAccessFlags2) void {
	// const barrier = c.VkImageMemoryBarrier2{
		// .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
		// .srcStageMask = src_stage,
		// .dstStageMask = dst_stage,
		// .srcAccessMask = src_access,
		// .dstAccessMask = dst_access,
		// .oldLayout = old_layout,
		// .newLayout = new_layout,
		// .image = image,
		// .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
		// .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
		// .subresourceRange = .{
			// .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
			// .baseMipLevel = 0,
			// .levelCount = 1,
			// .baseArrayLayer = 0,
			// .layerCount = 1,
		// },
	// };
// 
	// const dependency_info = c.VkDependencyInfo{
		// .sType = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
		// .dependencyFlags = 0,
		// .imageMemoryBarrierCount = 1,
		// .pImageMemoryBarriers = &barrier,
	// };
// 
	// context.lib.device.vkCmdPipelineBarrier2(command_buffer.handle, &dependency_info);
// }

// 
// pub const Pipeline = struct {
	// handle: c.VkPipeline,
	// layout: c.VkPipelineLayout,
// 
	// pub fn init(self: *Pipeline, context: *Context, input: Input, set_layouts: Descriptor.Set.Layouts) !void {
		// const layouts = try set_layouts.build(context);
// 
		// const layout_info = c.VkPipelineLayoutCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
			// .setLayoutCount = @intCast(layouts.handles.len),
			// .pSetLayouts = layouts.handles.ptr,
		// };
// 
		// if (c.VK_SUCCESS != context.lib.device.vkCreatePipelineLayout(context.device.handle, &layout_info, null, &self.layout)) return error.PipelineLayout;
// 
		// const input_description = try input.build(context.allocator.tmp);
// 
		// const vertex_input = c.VkPipelineVertexInputStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
			// .vertexBindingDescriptionCount = @intCast(input_description.bindings.len),
			// .pVertexBindingDescriptions = input_description.bindings.ptr,
			// .vertexAttributeDescriptionCount = @intCast(input_description.attributes.len),
			// .pVertexAttributeDescriptions = input_description.attributes.ptr,
		// };
// 
		// const input_assembly = c.VkPipelineInputAssemblyStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
			// .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
			// .primitiveRestartEnable = c.VK_FALSE,
		// };
// 
		// const viewport = c.VkPipelineViewportStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
			// .viewportCount = 1,
			// .scissorCount = 1,
		// };
// 
		// const rasterization = c.VkPipelineRasterizationStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
			// .depthClampEnable = c.VK_FALSE,
			// .rasterizerDiscardEnable = c.VK_FALSE,
			// .polygonMode = c.VK_POLYGON_MODE_FILL,
			// .depthBiasEnable = c.VK_FALSE,
			// .lineWidth = 1.0,
		// };
// 
		// const blend_attachments = &[_]c.VkPipelineColorBlendAttachmentState{
			// .{
				// .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
			// },
		// };
// 
		// const blend = c.VkPipelineColorBlendStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
			// .attachmentCount = @intCast(blend_attachments.len),
			// .pAttachments = blend_attachments.ptr,
		// };
// 
		// const depth_stencil = c.VkPipelineDepthStencilStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
			// .depthCompareOp = c.VK_COMPARE_OP_ALWAYS,
		// };
// 
		// const multisample = c.VkPipelineMultisampleStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
			// .rasterizationSamples = 1,
		// };
// 
		// const dynamic_states = &[_]c.VkDynamicState{
			// c.VK_DYNAMIC_STATE_VIEWPORT,
			// c.VK_DYNAMIC_STATE_SCISSOR,
		// };
// 
		// const dynamic_state = c.VkPipelineDynamicStateCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
			// .dynamicStateCount = @intCast(dynamic_states.len),
			// .pDynamicStates = dynamic_states.ptr,
		// };
// 
		// const vertex_shader = try Module.init(context, "Asset/Shader/VertexShader.spv");
		// defer vertex_shader.deinit(context);
// 
		// const fragment_shader = try Module.init(context, "Asset/Shader/FragmentShader.spv");
		// defer fragment_shader.deinit(context);
// 
		// const shader = &[_]c.VkPipelineShaderStageCreateInfo{
			// .{
				// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
				// .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
				// .module = vertex_shader.handle,
				// .pName = "main",
			// },
			// .{
				// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
				// .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
				// .module = fragment_shader.handle,
				// .pName = "main",
			// },
		// };
// 
		// const pipeline_rendering = c.VkPipelineRenderingCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
			// .colorAttachmentCount = 1,
			// .pColorAttachmentFormats = &context.swapchain.surface_format.format,
		// };
// 
		// const info = c.VkGraphicsPipelineCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
			// .pNext = &pipeline_rendering,
			// .stageCount = @intCast(shader.len),
			// .pStages = shader.ptr,
			// .pVertexInputState = &vertex_input,
			// .pInputAssemblyState = &input_assembly,
			// .pViewportState = &viewport,
			// .pRasterizationState = &rasterization,
			// .pMultisampleState = &multisample,
			// .pDepthStencilState = &depth_stencil,
			// .pColorBlendState = &blend,
			// .pDynamicState = &dynamic_state,
			// .layout = self.layout,
			// .renderPass = null,
			// .subpass = 0,
		// };
// 
		// if (c.VK_SUCCESS != context.lib.device.vkCreateGraphicsPipelines(context.device.handle, null, 1, &info, null, &self.handle)) return error.PipelineCreate;
	// }
// };
// 
// 
// pub const Buffer = struct {
	// handle: c.VkBuffer,
	// memory: c.VkDeviceMemory,
	// capacity: u32,
	// len: u32,
	// type_size: u32,
// 
	// properties: MemoryProperties,
// 
	// pub const Range = struct {
		// handle: c.VkBuffer,
		// offset: u32,
		// length: u32,
	// };
// 
	// pub const Usage = struct {
		// usage: std.EnumSet(Kind),
// 
		// pub const Kind = enum {
			// storage,
			// uniform,
			// vertex,
			// index,
// 
			// pub fn into(self: Kind) u32 {
				// return switch (self) {
					// .storage => c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
					// .uniform => c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
					// .vertex => c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
					// .index => c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
				// };
			// }
		// };
// 
		// pub fn into(self: Usage) c.VkBufferUsageFlagBits {
			// return enum_set_into(Kind, self.usage);
		// }
// 
		// pub fn init(kinds: []const Kind) Usage {
			// return .{
				// .usage = std.EnumSet(Kind).initMany(kinds),
			// };
		// }
	// };
// 
	// pub const Sharing = enum {
		// exclusive,
// 
		// pub fn into(self: Sharing) c.VkSharingMode {
			// return switch (self) {
				// .exclusive => c.VK_SHARING_MODE_EXCLUSIVE,
			// };
		// }
	// };
// 
	// pub const MemoryProperties = struct {
		// properties: std.EnumSet(Kind),
// 
		// pub const Kind = enum {
			// host_visible,
			// host_coherent,
// 
			// pub fn into(self: Kind) u32 {
				// return switch (self) {
					// .host_visible => c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
					// .host_coherent => c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
				// };
			// }
		// };
// 
		// pub fn init(properties: []const Kind) MemoryProperties {
			// return .{
				// .properties = .initMany(properties),
			// };
		// }
// 
		// pub fn into(self: MemoryProperties) c.VkMemoryPropertyFlagBits {
			// return enum_set_into(Kind, self.properties);
		// }
	// };
// 
	// pub fn init(T: type, context: *Context, usage: Usage, properties: MemoryProperties, sharing: Sharing, capacity: usize) !Buffer {
		// var self: Buffer = undefined;
// 
		// self.len = 0;
		// self.capacity = @intCast(capacity);
		// self.properties = properties;
		// self.type_size = @sizeOf(T);
// 
		// const total_size = self.capacity * self.type_size;
// 
		// const info = c.VkBufferCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
			// .flags = 0,
			// .size = total_size,
			// .usage = usage.into(),
			// .sharingMode = sharing.into(),
		// };
// 
		// if (c.VK_SUCCESS != context.lib.device.vkCreateBuffer(context.device.handle, &info, null, &self.handle)) return error.CreateBuffer;
// 
		// var requirements: c.VkMemoryRequirements = undefined;
		// context.lib.device.vkGetBufferMemoryRequirements(context.device.handle, self.handle, &requirements);
// 
		// const index = try findMemory(
			// context,
			// requirements.memoryTypeBits,
			// properties,
		// );
// 
		// const alloc_info = c.VkMemoryAllocateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
			// .allocationSize = requirements.size,
			// .memoryTypeIndex = index,
		// };
// 
		// if (c.VK_SUCCESS != context.lib.device.vkAllocateMemory(context.device.handle, &alloc_info, null, &self.memory)) return error.AllocateMemory;
		// if (c.VK_SUCCESS != context.lib.device.vkBindBufferMemory(context.device.handle, self.handle, self.memory, 0)) return error.BindBuffer;
// 
		// return self;
	// }
// 
	// pub fn range(self: *Buffer, offset: u32, count: ?u32) !Range {
		// const length = count orelse self.capacity - offset;
// 
		// if (offset + length > self.capacity) return error.OutOfBounds;
// 
		// const size = self.type_size;
// 
		// return Range{
			// .handle = self.handle,
			// .offset = size * offset,
			// .length = size * length,
		// };
	// }
// 
	// pub fn append(
		// self: *Buffer,
		// T: type,
		// context: *Context,
		// data: []const T,
	// ) !void {
		// if (self.type_size != @sizeOf(T)) return error.MissmatchTypeSize;
		//if (!(self.properties.properties.contains(.host_coherent) and self.properties.properties.contains(.host_visible))) return error.NotVisibleToHost; // TODO: copy from staging buffer
		// if (self.len + data.len > self.capacity) return error.OutOfMemory;
// 
		// const remap = try self.map(T, context, self.len, @intCast(data.len));
		// @memcpy(remap, data);
// 
		// self.len += @intCast(data.len);
// 
		// self.unmap(context);
	// }
// 
	// pub fn map(
		// self: *Buffer,
		// T: type,
		// context: *Context,
		// offset: u32,
		// count: u32,
	// ) ![]T {
		// var data: []T = undefined;
// 
		// if (c.VK_SUCCESS != context.lib.device.vkMapMemory(context.device.handle, self.memory, offset * @sizeOf(T), count * @sizeOf(T), 0, @ptrCast(&data.ptr))) return error.MapMemory;
// 
		// data.len = count;
// 
		// return data;
	// }
// 
	// pub fn unmap(self: *Buffer, context: *Context) void {
		// context.lib.device.vkUnmapMemory(context.device.handle, self.memory);
	// }
// 
	// fn findMemory(context: *Context, type_filter: u32, memory_properties: MemoryProperties) !u32 {
		// const properties = memory_properties.into();
// 
		// for (0..context.device.memory_properties.memoryTypeCount) |i| {
			// const index: u5 = @intCast(i);
			// const base: u32 = 1;
// 
			// if (type_filter & (base << index) > 0) {
				// if (context.device.memory_properties.memoryTypes[i].propertyFlags & properties == properties) {
					// return index;
				// }
			// }
		// }
// 
		// return error.MemoryTypeIndex;
	// }
// 
	// pub fn clear(self: *Buffer) void {
		// self.len = 0;
	// }
// };
// 
// fn enum_set_into(T: type, set: std.EnumSet(T)) u32 {
	// var iterator = set.iterator();
	// var flag: u32 = 0;
// 
	// while (iterator.next()) |key| {
		// flag |= key.into();
	// }
// 
	// return flag;
// }
// 
// 
// pub const Swapchain = struct {
	// handle: c.VkSwapchainKHR,
	// images: []c.VkImage,
	// image_views: []c.VkImageView,
	// image_count: u32,
	// command_buffers: []Command.Buffer,
	// surface_format: c.VkSurfaceFormatKHR,
	// present_mode: c.VkPresentModeKHR,
	// extent: c.VkExtent2D,
	// suboptimal: bool,
// 
	// semaphores: []*Semaphore,
	// fences: []*Fence,
	// extra_semaphore: *Semaphore,
// 
	// const INITIAL_SIZE: u32 = 10;
// 
	// pub fn startup(self: *Swapchain, context: *Context, width: u32, height: u32) !void {
		// self.images = try context.allocator.main.alloc(c.VkImage, INITIAL_SIZE);
		// self.image_views = try context.allocator.main.alloc(c.VkImageView, INITIAL_SIZE);
// 
		// self.semaphores = try context.allocator.main.alloc(*Semaphore, INITIAL_SIZE);
		// self.fences = try context.allocator.main.alloc(*Fence, INITIAL_SIZE);
// 
		// self.suboptimal = false;
// 
		// @memset(self.images, null);
		// @memset(self.image_views, null);
// 
		// for (0..INITIAL_SIZE) |i| {
			// self.semaphores[i] = try context.semaphores.add(context);
			// self.fences[i] = try context.fences.add(context);
		// }
// 
		// self.extra_semaphore = try context.semaphores.add(context);
// 
		// self.handle = null;
		// self.present_mode = c.VK_PRESENT_MODE_FIFO_KHR;
		// self.extent.width = 0;
		// self.extent.height = 0;
// 
		// var format_count: u32 = 0;
// 
		// if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(context.device.physical, context.surface.handle, &format_count, null)) return error.SurfaceFormats;
// 
		// const formats = try context.allocator.tmp.alloc(c.VkSurfaceFormatKHR, format_count);
		// defer context.allocator.tmp.free(formats);
// 
		// if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(context.device.physical, context.surface.handle, &format_count, formats.ptr)) return error.SurfaceFormats;
// 
		// const preferreds: []const c.VkFormat = &.{
			// c.VK_FORMAT_R8G8B8A8_SRGB,
		// };
// 
		// self.surface_format = outer: for (preferreds) |preferred| {
			// for (formats) |format| {
				// if (preferred == format.format) break :outer format;
			// }
		// } else return error.SurfaceFormat;
// 
		// try self.new(context, width, height);
	// }
// 
	// pub fn new(self: *Swapchain, context: *Context, width: u32, height: u32) !void {
		// self.extent = c.VkExtent2D{
			// .width = width,
			// .height = height,
		// };
// 
		// var surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
		// if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(context.device.physical, context.surface.handle, &surface_capabilities)) return error.SurfaceCapabilities;
// 
		// const image_exced = surface_capabilities.maxImageCount > 0 and self.image_count > surface_capabilities.maxImageCount;
		// self.image_count = if (image_exced) surface_capabilities.maxImageCount + 1 else surface_capabilities.minImageCount + 1;
// 
		// const transform = switch (surface_capabilities.supportedTransforms & c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR) {
			// 0 => surface_capabilities.currentTransform,
			// else => c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
		// };
// 
		// var composite: c.VkCompositeAlphaFlagBitsKHR = 0;
// 
		// if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR != 0) {
			// composite = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
		// } else if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR != 0) {
			// composite = c.VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
		// } else if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR != 0) {
			// composite = c.VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR;
		// } else if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR != 0) {
			// composite = c.VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR;
		// }
// 
		// const old_handle = self.handle;
		// const info = c.VkSwapchainCreateInfoKHR{
			// .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
			// .surface = context.surface.handle,
			// .minImageCount = self.image_count,
			// .imageFormat = self.surface_format.format,
			// .imageColorSpace = self.surface_format.colorSpace,
			// .imageExtent = self.extent,
			// .presentMode = self.present_mode,
			// .imageArrayLayers = 1,
			// .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
			// .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
			// .preTransform = transform,
			// .compositeAlpha = composite,
			// .clipped = c.VK_TRUE,
			// .oldSwapchain = old_handle,
		// };
// 
		// for (0..INITIAL_SIZE) |i| {
			// if (self.image_views[i] == null) continue;
// 
			// context.lib.device.vkDestroyImageView(context.device.handle, self.image_views[i], null);
		// }
// 
		// @memset(self.images, null);
		// @memset(self.image_views, null);
// 
		// if (c.VK_SUCCESS != context.lib.device.vkCreateSwapchainKHR(context.device.handle, &info, null, &self.handle)) return error.SwapchainCreate;
// 
		// if (c.VK_SUCCESS != context.lib.device.vkGetSwapchainImagesKHR(context.device.handle, self.handle, &self.image_count, self.images.ptr)) return error.SwapchainImage;
// 
		// for (0..self.image_count) |i| {
			// const subresource = c.VkImageSubresourceRange{
				// .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
				// .baseMipLevel = 0,
				// .levelCount = 1,
				// .baseArrayLayer = 0,
				// .layerCount = 1,
			// };
// 
			// const view_info = c.VkImageViewCreateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
				// .image = self.images[i],
				// .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
				// .format = self.surface_format.format,
				// .subresourceRange = subresource,
			// };
// 
			// if (c.VK_SUCCESS != context.lib.device.vkCreateImageView(context.device.handle, &view_info, null, &self.image_views[i])) return error.CreateImageView;
		// }
// 
		// self.command_buffers = try context.command_allocator.alloc(context, self.image_count);
// 
		// if (old_handle != null) {
			// if (c.VK_SUCCESS != context.lib.device.vkQueueWaitIdle(context.device.queue)) return error.WaitQueue;
			// context.lib.device.vkDestroySwapchainKHR(context.device.handle, old_handle, null);
		// }
	// }
// 
	// pub fn nextImage(self: *Swapchain, context: *Context) !u32 {
		// if (self.suboptimal) {
			// try self.new(context, self.extent.width, self.extent.height);
		// }
// 
		// var image: u32 = 0;
		// const semaphore = self.extra_semaphore;
// 
		// const result = context.lib.device.vkAcquireNextImageKHR(context.device.handle, self.handle, 1000000, semaphore.handle, null, &image);
// 
		// switch (result) {
			// c.VK_SUCCESS => {},
			// c.VK_SUBOPTIMAL_KHR => self.suboptimal = true,
			// else => return error.AcquireImage,
		// }
// 
		// self.extra_semaphore = self.semaphores[image];
		// self.semaphores[image] = semaphore;
// 
		// const fence = self.fences[image];
// 
		// if (c.VK_SUCCESS != context.lib.device.vkWaitForFences(context.device.handle, 1, &fence.handle, c.VK_TRUE, 1000000)) return error.FenceWait;
		// if (c.VK_SUCCESS != context.lib.device.vkResetFences(context.device.handle, 1, &fence.handle)) return error.FenceReset;
// 
		// return image;
	// }
// };
// 
// pub const Command = struct {
	// pub const Buffer = struct {
		// handle: c.VkCommandBuffer,
		// semaphore: *Semaphores.Child,
	// };
// 
	// pub const Allocator = struct {
		// pools: std.ArrayList(Pool),
		// pool_sizes: u32,
// 
		// pub fn init(self: *Allocator, context: *Context, sizes: u32) !void {
			// self.pools = try std.ArrayList(Pool).initCapacity(context.allocator.main, 10);
			// self.pool_sizes = sizes;
		// }
// 
		// pub fn alloc(self: *Allocator, context: *Context, count: u32) ![]Buffer {
			// var index: u32 = 0;
// 
			// while (true) {
				// defer index += 1;
// 
				// if (index >= self.pools.items.len) {
					// const pool = try self.pools.addOne(context.allocator.main);
					// try pool.init(context, self.pool_sizes);
// 
					// return try pool.alloc(context, count);
				// } else {
					// return self.pools.items[index].alloc(context, count) catch continue;
				// }
			// }
// 
			// return error.OutOfMemory;
		// }
	// };
// 
	// pub const Pool = struct {
		// handle: c.VkCommandPool,
		// childs: std.ArrayList(Buffer),
// 
		// pub fn init(self: *Pool, context: *Context, size: u32) !void {
			// self.childs = try std.ArrayList(Buffer).initCapacity(context.allocator.main, size);
// 
			// const pool_info = c.VkCommandPoolCreateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
				// .flags = c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
				// .queueFamilyIndex = context.device.family_index,
			// };
// 
			// if (c.VK_SUCCESS != context.lib.device.vkCreateCommandPool(context.device.handle, &pool_info, null, &self.handle)) return error.CommandPool;
		// }
// 
		// pub fn alloc(self: *Pool, context: *Context, count: u32) ![]Buffer {
			// if (self.childs.items.len + count > self.childs.capacity) return error.OutOfMemory;
// 
			// const info = c.VkCommandBufferAllocateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
				// .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
				// .commandPool = self.handle,
				// .commandBufferCount = count,
			// };
// 
			// const buffer_raws = try context.allocator.tmp.alloc(c.VkCommandBuffer, count);
// 
			// if (c.VK_SUCCESS != context.lib.device.vkAllocateCommandBuffers(context.device.handle, &info, buffer_raws.ptr)) return error.AllocateCommandBuffer;
// 
			// const buffers = self.childs.addManyAsSliceAssumeCapacity(count);
// 
			// for (buffer_raws, 0..) |buffer, i| {
				// buffers[i].handle = buffer;
				// buffers[i].semaphore = try context.semaphores.add(context);
			// }
// 
			// return buffers;
		// }
	// };
// };
// 
// pub const Module = struct {
	// handle: c.VkShaderModule,
// 
	// pub fn init(context: *Context, path: []const u8) !Module {
		// var self: Module = undefined;
// 
		// const base_dir = try std.fs.selfExeDirPathAlloc(context.allocator.tmp);
		// const file_path = try std.fs.path.join(context.allocator.tmp, &.{ base_dir, "../", path });
		// const file = try std.fs.openFileAbsolute(file_path, .{});
		// const size = try file.getEndPos();
		// const buffer = try context.allocator.tmp.alloc(u32, (size + 3) / @sizeOf(u32));
// 
		// const bytes: [*]u8 = @ptrCast(@alignCast(buffer.ptr));
		// const len = try file.readAll(bytes[0..size]);
// 
		// if (len != size) return error.ReadFile;
// 
		// const info = c.VkShaderModuleCreateInfo{
			// .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
			// .codeSize = @intCast(size),
			// .pCode = buffer.ptr,
		// };
// 
		// if (c.VK_SUCCESS != context.lib.device.vkCreateShaderModule(context.device.handle, &info, null, &self.handle)) return error.ShaderModule;
// 
		// return self;
	// }
// 
	// pub fn deinit(self: *const Module, context: *Context) void {
		// context.lib.device.vkDestroyShaderModule(context.device.handle, self.handle, null);
	// }
// };
// 
// pub const Input = struct {
	// singles: []Layout,
// 
	// pub const Attribute = struct {
		// format: c.VkFormat,
		// offset: u32,
		// location: u32,
	// };
// 
	// pub const Build = struct {
		// bindings: []c.VkVertexInputBindingDescription,
		// attributes: []c.VkVertexInputAttributeDescription,
	// };
// 
	// pub const Layout = struct {
		// size: u32,
		// attributes: []Attribute,
// 
		// pub fn init(T: type, context: *Context) !Layout {
			// const FIELDS = @typeInfo(T).@"struct".fields;
			// const count = FIELDS.len;
// 
			// var self = Layout{
				// .size = @sizeOf(T),
				// .attributes = try context.allocator.tmp.alloc(Attribute, count),
			// };
// 
			// var offset: u32 = 0;
			// inline for (FIELDS, 0..) |field, i| {
				// self.attributes[i] = .{
					// .format = getFormat(field.type),
					// .offset = offset,
					// .location = i,
				// };
// 
				// offset += @sizeOf(field.type);
			// }
// 
			// return self;
		// }
// 
		// fn getSize(T: type) u32 {
			// switch (@typeInfo(T)) {
				// .float => |f| {
					// std.debug.assert(f.bits == 32);
					// return 4;
				// },
				// else => @panic("NOT SUPPORTED"),
			// }
		// }
// 
		// fn getFormat(T: type) c.VkFormat {
			// switch (@typeInfo(T)) {
				// .array => |a| {
					// const size = getSize(a.child);
					// _ = size;
// 
					// switch (a.len) {
						// 1 => return c.VK_FORMAT_R32_SFLOAT,
						// 2 => return c.VK_FORMAT_R32G32_SFLOAT,
						// 3 => return c.VK_FORMAT_R32G32B32_SFLOAT,
						// 4 => return c.VK_FORMAT_R32G32B32A32_SFLOAT,
						// else => @panic("NOT SUPPORTED"),
					// }
				// },
				// else => @panic("NOT SUPPORTED"),
			// }
// 
			// @panic("NOT SUPPORTED");
		// }
	// };
// 
	// pub fn init(singles: []const Layout, allocator: std.mem.Allocator) !Input {
		// var self: Input = undefined;
// 
		// self.singles = try allocator.alloc(Layout, singles.len);
		// @memcpy(self.singles, singles);
// 
		// return self;
	// }
// 
	// pub fn build(self: Input, allocator: std.mem.Allocator) !Build {
		// var bindings = try std.ArrayList(c.VkVertexInputBindingDescription).initCapacity(allocator, self.singles.len);
		// var attributes = try std.ArrayList(c.VkVertexInputAttributeDescription).initCapacity(allocator, 10);
// 
		// for (self.singles, 0..) |single, i| {
			// try bindings.append(allocator, .{
				// .binding = @intCast(i),
				// .stride = single.size,
				// .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
			// });
// 
			// for (single.attributes) |att| {
				// try attributes.append(allocator, .{
					// .binding = @intCast(i),
					// .location = att.location,
					// .format = att.format,
					// .offset = att.offset,
				// });
			// }
		// }
// 
		// return .{
			// .bindings = bindings.items,
			// .attributes = attributes.items,
		// };
	// }
// };
// 
// pub const Descriptor = struct {
	// pub const Allocator = struct {
		// pools: std.ArrayList(Pool),
		// sizes: []Size,
		// max: u32,
// 
		// pub fn init(self: *Allocator, context: *Context, sizes: []const Size, max: u32) !void {
			// self.pools = try std.ArrayList(Pool).initCapacity(context.allocator.main, 10);
			// self.max = max;
			// self.sizes = try context.allocator.main.alloc(Size, sizes.len);
// 
			// @memcpy(self.sizes, sizes);
		// }
// 
		// pub fn alloc(self: *Allocator, context: *Context, layouts: []Descriptor.Set.Layout) ![]Set {
			// var index: u32 = 0;
// 
			// while (true) {
				// defer index += 1;
// 
				// if (index >= self.pools.items.len) {
					// const pool = try self.pools.addOne(context.allocator.main);
					// try pool.init(context, self.sizes, self.max);
// 
					// return try pool.alloc(context, layouts);
				// } else {
					// return self.pools.items[index].alloc(context, layouts) catch continue;
				// }
			// }
// 
			// return error.OutOfMemory;
		// }
	// };
// 
	// pub const Size = struct {
		// kind: Kind,
		// count: u32,
// 
		// pub const Kind = enum {
			// storage,
			// uniform,
// 
			// pub fn into(self: Kind) u32 {
				// return switch (self) {
					// .storage => c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
					// .uniform => c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
				// };
			// }
		// };
// 
		// pub fn init(kind: Kind, count: u32) Size {
			// return .{
				// .count = count,
				// .kind = kind,
			// };
		// }
	// };
// 
	// pub const Pool = struct {
		// handle: c.VkDescriptorPool,
		// childs: std.ArrayList(Set),
// 
		// pub fn init(self: *Pool, context: *Context, sizes: []Size, max: u32) !void {
			// const pool_sizes = try context.allocator.tmp.alloc(c.VkDescriptorPoolSize, sizes.len);
			// self.childs = try std.ArrayList(Set).initCapacity(context.allocator.main, max);
// 
			// for (sizes, 0..) |size, i| {
				// pool_sizes[i] = .{
					// .type = size.kind.into(),
					// .descriptorCount = size.count,
				// };
			// }
// 
			// const descriptor_pool_info = c.VkDescriptorPoolCreateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
				// .poolSizeCount = @intCast(pool_sizes.len),
				// .pPoolSizes = pool_sizes.ptr,
				// .maxSets = max,
			// };
// 
			// if (c.VK_SUCCESS != context.lib.device.vkCreateDescriptorPool(context.device.handle, &descriptor_pool_info, null, &self.handle)) return error.DescriptorPool;
		// }
// 
		// pub fn alloc(self: *Pool, context: *Context, layouts: []Descriptor.Set.Layout) ![]Set {
			// const count: u32 = @intCast(layouts.len);
// 
			// if (self.childs.items.len + count > self.childs.capacity) return error.OutOfDescriptors;
// 
			// const raw_layouts = try context.allocator.tmp.alloc(c.VkDescriptorSetLayout, count);
			// for (0..count) |i| {
				// raw_layouts[i] = layouts[i].handle;
			// }
// 
			// const allocate_info = c.VkDescriptorSetAllocateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
				// .descriptorPool = self.handle,
				// .descriptorSetCount = count,
				// .pSetLayouts = raw_layouts.ptr,
			// };
// 
			// const handles = try context.allocator.tmp.alloc(c.VkDescriptorSet, count);
			// if (c.VK_SUCCESS != context.lib.device.vkAllocateDescriptorSets(context.device.handle, &allocate_info, handles.ptr)) return error.OutOfDescriptors;
// 
			// const sets = self.childs.addManyAsSliceAssumeCapacity(count);
			// for (0..count) |i| {
				// sets[i] = .{
					// .handle = handles[i],
					// .layout = layouts[i],
				// };
			// }
// 
			// return sets;
		// }
	// };
// 
	// pub const UpdateInfo = struct {
		// set: *Set,
		// range: ?Buffer.Range,
		// binding: u32,
	// };
// 
	// pub const Set = struct {
		// handle: c.VkDescriptorSet,
		// layout: Layout,
// 
		// pub const Layouts = struct {
			// childs: []Layout,
// 
			// pub const Build = struct {
				// handles: []c.VkDescriptorSetLayout,
			// };
// 
			// pub fn init(context: *Context, childs: []const Layout) !Layouts {
				// var self: Layouts = undefined;
// 
				// self.childs = try context.allocator.main.alloc(Layout, childs.len);
				// @memcpy(self.childs, childs);
// 
				// return self;
			// }
// 
			// pub fn build(self: Layouts, context: *Context) !Build {
				// var result: Build = undefined;
				// result.handles = try context.allocator.tmp.alloc(c.VkDescriptorSetLayout, self.childs.len);
// 
				// for (self.childs, 0..) |child, i| {
					// result.handles[i] = child.handle;
				// }
// 
				// return result;
			// }
		// };
// 
		// pub const Layout = struct {
			// handle: c.VkDescriptorSetLayout,
			// bindings: []Binding,
// 
			// pub const Binding = struct {
				// kind: Kind,
				// stage: Stage,
				// count: u32,
// 
				// pub const Kind = enum {
					// storage,
					// uniform,
// 
					// fn into(self: Kind) u32 {
						// return switch (self) {
							// .storage => c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
							// .uniform => c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
						// };
					// }
				// };
// 
				// pub const Stage = enum {
					// vertex,
					// fragment,
// 
					// fn into(self: Stage) u32 {
						// return switch (self) {
							// .vertex => c.VK_SHADER_STAGE_VERTEX_BIT,
							// .fragment => c.VK_SHADER_STAGE_FRAGMENT_BIT,
						// };
					// }
				// };
// 
				// pub fn init(kind: Kind, stage: Stage, count: u32) Binding {
					// return .{
						// .kind = kind,
						// .stage = stage,
						// .count = count,
					// };
				// }
			// };
// 
			// pub fn init(context: *Context, binds: []const Binding) !Layout {
				// var self: Layout = undefined;
// 
				// self.bindings = try context.allocator.main.alloc(Binding, binds.len);
				// @memcpy(self.bindings, binds);
// 
				// const bindings = try context.allocator.tmp.alloc(c.VkDescriptorSetLayoutBinding, self.bindings.len);
// 
				// for (self.bindings, 0..) |binding, i| {
					// bindings[i] = .{
						// .binding = @intCast(i),
						// .descriptorType = binding.kind.into(),
						// .stageFlags = binding.stage.into(),
						// .descriptorCount = binding.count,
					// };
				// }
// 
				// const info = c.VkDescriptorSetLayoutCreateInfo{
					// .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
					// .bindingCount = @intCast(bindings.len),
					// .pBindings = bindings.ptr,
				// };
// 
				// if (c.VK_SUCCESS != context.lib.device.vkCreateDescriptorSetLayout(context.device.handle, &info, null, &self.handle)) return error.DescriptorSetLayout;
// 
				// return self;
			// }
		// };
// 
		// pub fn update(self: *Set, context: *Context, range: ?Buffer.Range, binding: u32) !void {
			// if (range) |r| {
				// const buffer_info = c.VkDescriptorBufferInfo{
					// .buffer = r.handle,
					// .range = r.length,
					// .offset = r.offset,
				// };
// 
				// const write_set = c.VkWriteDescriptorSet{
					// .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
					// .dstSet = self.handle,
					// .dstBinding = binding,
					// .descriptorCount = 1,
					// .descriptorType = self.layout.bindings[binding].kind.into(),
					// .pBufferInfo = &buffer_info,
				// };
// 
				// context.lib.device.vkUpdateDescriptorSets(context.device.handle, 1, &write_set, 0, null);
			// }
		// }
	// };
// };
// 
// pub const Fences = struct {
	// childs: DoubleList(Child),
// 
	// pub const Child = struct {
		// handle: c.VkFence,
		// node: std.DoublyLinkedList.Node,
// 
		// pub fn init(self: *Child, context: *Context) !void {
			// const info = c.VkFenceCreateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
				// .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
			// };
// 
			// if (c.VK_SUCCESS != context.lib.device.vkCreateFence(context.device.handle, &info, null, &self.handle)) return error.Fence;
		// }
	// };
// 
	// pub fn init(self: *Fences) void {
		// self.childs.init();
	// }
// 
	// pub fn add(self: *Fences, context: *Context) !*Child {
		// if (self.childs.add()) |ch| {
			// return ch;
		// } else {
			// const child = try self.childs.create(context.allocator.main);
			// try child.init(context);
			// return child;
		// }
	// }
// };
// 
// pub const Semaphores = struct {
	// childs: DoubleList(Child),
// 
	// pub const Child = struct {
		// handle: c.VkSemaphore,
		// node: std.DoublyLinkedList.Node,
// 
		// pub fn init(self: *Child, context: *Context) !void {
			// const info = c.VkSemaphoreCreateInfo{
				// .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
			// };
// 
			// if (c.VK_SUCCESS != context.lib.device.vkCreateSemaphore(context.device.handle, &info, null, &self.handle)) return error.Semaphore;
		// }
	// };
// 
	// pub fn init(self: *Semaphores) void {
		// self.childs.init();
	// }
// 
	// pub fn add(self: *Semaphores, context: *Context) !*Child {
		// if (self.childs.add()) |ch| {
			// return ch;
		// } else {
			// const child = try self.childs.create(context.allocator.main);
			// try child.init(context);
			// return child;
		// }
	// }
// };
// 
// pub const RenderGroup = struct {
	// vertices: Buffer,
	// indices: Buffer,
	// sets: []*Descriptor.Set,
// 
	// pub fn init(
		// self: *RenderGroup,
		// context: *Context,
		// vertices: Buffer,
		// indices: Buffer,
		// sets: []const *Descriptor.Set,
	// ) !void {
		// self.vertices = vertices;
		// self.indices = indices;
// 
		// self.sets = try context.allocator.main.alloc(*Descriptor.Set, sets.len);
		// @memcpy(self.sets, sets);
// 
		// self.descriptor_sets = try allocator.main.alloc(u32, set_buffers.len);
		// try self.update(library, device, pipeline, manager, set_buffers);
	// }
// 
	// fn update(self: *Render, buffers: []Buffer) !void {
	//     _ = self;
	//     for (0..buffers.len) |i| {
	//         _ = i;
	// self.descriptor_sets[i] = try manager.addDescriptorSet(
	//     library,
	//     device,
	//     pipeline.set_layouts[i],
	// );
// 
	// try manager.updateDescriptorSet(
	//     library,
	//     device,
	//     self.descriptor_sets[i],
	//     0,
	//     try set_buffers[i].getRange(0, set_buffers[i].count),
	// );
	// }
	// }
// };

const std = @import("std");
const c = @import("util").c;

const Allocator = @import("util").Allocator;
const Matrix = @import("util").Matrix(4);
const DoubleList = @import("util").List;

// pub const Instance = @import("Instance.zig").Instance;
// pub const Pipeline = @import("Pipeline.zig").Pipeline;
// pub const Surface = @import("Surface.zig").Surface;
// pub const Buffer = @import("Buffer.zig").Buffer;
// pub const Device = @import("Device.zig").Device;
// pub const Swapchain = @import("Swapchain.zig").Swapchain;
// pub const Command = @import("Command.zig").Command;
// pub const Input = @import("Shader.zig").Input;
// pub const Semaphores = @import("Sync.zig").Semaphores;
// pub const Fences = @import("Sync.zig").Fences;
// pub const Descriptor = @import("Shader.zig").Descriptor;
// pub const RenderGroup = @import("Render.zig").RenderGroup;
