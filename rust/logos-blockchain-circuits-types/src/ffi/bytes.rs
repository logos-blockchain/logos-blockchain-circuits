use libc::free;

mod inner {
    #[repr(C)]
    pub struct Buffer<T> {
        pub data: T,
        pub size: usize,
    }
}

pub type Bytes = inner::Buffer<*mut u8>;
pub type ConstBytes = inner::Buffer<*const u8>;

/// Frees the data buffer inside a [`Bytes`] struct allocated by the C API.
///
/// Only the inner data buffer is freed, not the struct itself, since the latter is managed by the
/// caller.
///
/// # Arguments
///
/// - `bytes`: A pointer to a [`Bytes`] struct whose data buffer was allocated by the C API and
/// needs to be freed.
///
/// # Safety
///
/// Dereferences raw pointers. The caller must ensure that the pointer is valid.
pub unsafe fn free_bytes(bytes: *mut Bytes) {
    if bytes.is_null() {
        return;
    }

    let bytes = unsafe { &mut *bytes };
    if !bytes.data.is_null() {
        unsafe { free(bytes.data as *mut libc::c_void) };
    }
    bytes.data = std::ptr::null_mut();
    bytes.size = 0;
}
