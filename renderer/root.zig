pub const Plane = struct {
	offset: usize,
	pitch: usize,
	size: usize,
};

pub const DrmFormat = struct {
	planes: []Plane,
	modifier: u64,
	format: usize,
	fd: i32,
};

pub const Frame = struct {
	drm_format: DrmFormat,
	width: u32,
	height: u32,
};
