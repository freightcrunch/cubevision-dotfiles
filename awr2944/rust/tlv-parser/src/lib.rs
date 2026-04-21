//! Zero-copy parser for the TI mmWave "MMW demo" TLV frame format emitted on
//! the AWR2944 data UART (default 921 600 bps). The frame format is documented
//! in the MMWAVE-MCUPLUS-SDK user guide, section "Output packet format" — in
//! short:
//!
//! ```text
//!  ┌─────────────┬───────────────┬──────────┬─────────────────────────────┐
//!  │ Magic Word  │ Frame Header  │   TLVs   │ Padding (to 32-byte align)  │
//!  │  8 bytes    │   36 bytes    │   var    │           var               │
//!  └─────────────┴───────────────┴──────────┴─────────────────────────────┘
//! ```
//!
//! Keeping the parser `#![no_std]` means the same code runs on the host
//! (`host-capture`) and inside firmware (`firmware-r5f`) — so the byte layout
//! is defined exactly once and verified by the type system on both ends.

// `no_std` whenever we're not building with the `std` feature AND we aren't
// building the test harness (which pulls in std unconditionally).
#![cfg_attr(all(not(feature = "std"), not(test)), no_std)]
#![forbid(unsafe_op_in_unsafe_fn)]
#![warn(missing_docs)]

/// Magic word emitted by the mmW demo: `02 01 04 03 06 05 08 07`.
pub const MAGIC_WORD: [u8; 8] = [0x02, 0x01, 0x04, 0x03, 0x06, 0x05, 0x08, 0x07];

/// Size of the frame header that follows the magic word.
pub const FRAME_HEADER_LEN: usize = 36;

/// Known TLV types emitted by the AWR2944 mmW demo (non-exhaustive; additional
/// types are defined per-application in `mmw_output.h`).
#[repr(u32)]
#[derive(Debug, Copy, Clone, Eq, PartialEq)]
pub enum TlvType {
    /// Detected point cloud (x, y, z, doppler) — type id 1.
    DetectedPoints = 1,
    /// Range profile (log magnitude per range bin).
    RangeProfile = 2,
    /// Noise profile.
    NoiseProfile = 3,
    /// Azimuth static heatmap.
    AzimuthStaticHeatmap = 4,
    /// Range-Doppler heatmap.
    RangeDopplerHeatmap = 5,
    /// Stats block (inter-frame processing time, etc.).
    Stats = 6,
    /// Side info (SNR, noise) per detected point.
    SideInfo = 7,
    /// Unknown / application-specific TLV.
    Unknown = 0xFFFF_FFFF,
}

impl TlvType {
    /// Look up a TLV type from its wire-format u32. Unknown values fold into
    /// [`TlvType::Unknown`] so downstream code can still walk the stream.
    pub fn from_u32(v: u32) -> Self {
        match v {
            1 => Self::DetectedPoints,
            2 => Self::RangeProfile,
            3 => Self::NoiseProfile,
            4 => Self::AzimuthStaticHeatmap,
            5 => Self::RangeDopplerHeatmap,
            6 => Self::Stats,
            7 => Self::SideInfo,
            _ => Self::Unknown,
        }
    }
}

/// Fixed 36-byte header that follows the magic word in every frame.
#[derive(Debug, Copy, Clone)]
pub struct FrameHeader {
    /// SDK version, packed as u32 per the mmW demo.
    pub version: u32,
    /// Total packet length (including magic word + header + TLVs + padding).
    pub total_packet_len: u32,
    /// Platform identifier (`0x000A2944` for AWR2944).
    pub platform: u32,
    /// Monotonic frame counter.
    pub frame_number: u32,
    /// CPU cycles the DSS / HWA spent on this frame.
    pub time_cpu_cycles: u32,
    /// Number of detected objects in the point-cloud TLV.
    pub num_detected_obj: u32,
    /// Number of TLVs that follow this header.
    pub num_tlvs: u32,
    /// Subframe number (0 for single-subframe configs).
    pub subframe_number: u32,
    /// Reserved; the demo currently emits 0.
    pub reserved: u32,
}

/// Errors produced by [`FrameParser`].
#[derive(Debug, Copy, Clone, Eq, PartialEq)]
pub enum ParseError {
    /// Not enough bytes to form a frame header.
    Truncated,
    /// Magic word did not match.
    BadMagic,
    /// A TLV claims a length that would run past the end of the packet.
    TlvOverrun,
}

/// A single TLV as a zero-copy view into the input buffer.
#[derive(Debug, Copy, Clone)]
pub struct Tlv<'a> {
    /// TLV type, resolved against the known-types enum.
    pub ty: TlvType,
    /// Raw wire value of the type field (preserved for the `Unknown` case).
    pub ty_raw: u32,
    /// Length of [`Tlv::payload`] in bytes.
    pub len: u32,
    /// Payload bytes (not including the 8-byte TLV header).
    pub payload: &'a [u8],
}

/// Parses a single frame out of a byte buffer.
#[derive(Debug)]
pub struct FrameParser<'a> {
    /// Parsed header.
    pub header: FrameHeader,
    /// TLV region; use [`FrameParser::tlvs`] to iterate.
    tlv_bytes: &'a [u8],
}

impl<'a> FrameParser<'a> {
    /// Attempt to parse one frame starting at `buf[0]`. Returns the parser and
    /// the total number of bytes consumed (so the caller can advance its
    /// ring buffer cursor).
    pub fn parse(buf: &'a [u8]) -> Result<(Self, usize), ParseError> {
        if buf.len() < MAGIC_WORD.len() + FRAME_HEADER_LEN {
            return Err(ParseError::Truncated);
        }
        if &buf[..MAGIC_WORD.len()] != MAGIC_WORD {
            return Err(ParseError::BadMagic);
        }

        let hdr_bytes = &buf[MAGIC_WORD.len()..MAGIC_WORD.len() + FRAME_HEADER_LEN];
        let header = FrameHeader {
            version:           read_u32_le(hdr_bytes, 0),
            total_packet_len:  read_u32_le(hdr_bytes, 4),
            platform:          read_u32_le(hdr_bytes, 8),
            frame_number:      read_u32_le(hdr_bytes, 12),
            time_cpu_cycles:   read_u32_le(hdr_bytes, 16),
            num_detected_obj:  read_u32_le(hdr_bytes, 20),
            num_tlvs:          read_u32_le(hdr_bytes, 24),
            subframe_number:   read_u32_le(hdr_bytes, 28),
            reserved:          read_u32_le(hdr_bytes, 32),
        };

        let total = header.total_packet_len as usize;
        if buf.len() < total {
            return Err(ParseError::Truncated);
        }

        let tlv_start = MAGIC_WORD.len() + FRAME_HEADER_LEN;
        let tlv_bytes = &buf[tlv_start..total];

        Ok((Self { header, tlv_bytes }, total))
    }

    /// Iterate TLVs within this frame. Stops on error.
    pub fn tlvs(&self) -> TlvIter<'a> {
        TlvIter { rest: self.tlv_bytes }
    }
}

/// Iterator returned by [`FrameParser::tlvs`].
pub struct TlvIter<'a> {
    rest: &'a [u8],
}

impl<'a> Iterator for TlvIter<'a> {
    type Item = Result<Tlv<'a>, ParseError>;

    fn next(&mut self) -> Option<Self::Item> {
        if self.rest.is_empty() {
            return None;
        }
        if self.rest.len() < 8 {
            return Some(Err(ParseError::Truncated));
        }
        let ty_raw = read_u32_le(self.rest, 0);
        let len = read_u32_le(self.rest, 4) as usize;
        if 8 + len > self.rest.len() {
            return Some(Err(ParseError::TlvOverrun));
        }
        let payload = &self.rest[8..8 + len];
        self.rest = &self.rest[8 + len..];
        Some(Ok(Tlv {
            ty: TlvType::from_u32(ty_raw),
            ty_raw,
            len: len as u32,
            payload,
        }))
    }
}

#[inline(always)]
fn read_u32_le(buf: &[u8], off: usize) -> u32 {
    u32::from_le_bytes([buf[off], buf[off + 1], buf[off + 2], buf[off + 3]])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_bad_magic() {
        let buf = [0u8; 64];
        assert_eq!(FrameParser::parse(&buf).unwrap_err(), ParseError::BadMagic);
    }

    #[test]
    fn detects_truncation() {
        let buf = [0u8; 4];
        assert_eq!(FrameParser::parse(&buf).unwrap_err(), ParseError::Truncated);
    }
}
