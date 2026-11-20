use std::io::Write as _;

/// Returns a temp file that contains `contents`.
/// The file is deleted when the returned value is dropped.
#[must_use]
pub fn temp_file(contents: &str) -> tempfile::NamedTempFile {
    let mut file = tempfile::NamedTempFile::new().expect("Failed to create the temp file.");
    file.write_all(contents.as_bytes())
        .expect("Failed to write the temp file.");
    file
}
