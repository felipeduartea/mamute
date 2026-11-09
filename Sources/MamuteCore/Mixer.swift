import CoreAudio

/// Copies 32-bit float audio from `input` to `output`, ramping gain from `from` to `to` across the buffer.
/// Handles interleaved and non-interleaved layouts. Output channels with no matching input channel, and
/// output frames past the end of the input, are zeroed.
public func mix(input: UnsafeMutableAudioBufferListPointer, output: UnsafeMutableAudioBufferListPointer, from: Float, to: Float) {
    // shortcut: allocates small arrays on the audio thread, fine for a few channels; preallocate if glitches show up.
    let src = channels(input), dst = channels(output)
    let outFrames = frameCount(output)
    let n = min(frameCount(input), outFrames)
    for (c, (out, outStride)) in dst.enumerated() {
        for i in 0..<outFrames {
            guard c < src.count, i < n else { out[i * outStride] = 0; continue }
            let (inp, inStride) = src[c]
            let gain = n > 1 ? from + (to - from) * Float(i) / Float(n - 1) : to
            out[i * outStride] = inp[i * inStride] * gain
        }
    }
}

/// One pointer + stride per channel, across all buffers.
private func channels(_ list: UnsafeMutableAudioBufferListPointer) -> [(UnsafeMutablePointer<Float>, Int)] {
    var result: [(UnsafeMutablePointer<Float>, Int)] = []
    for buf in list {
        guard let data = buf.mData?.assumingMemoryBound(to: Float.self) else { continue }
        let count = Int(buf.mNumberChannels)
        for c in 0..<count { result.append((data + c, count)) }
    }
    return result
}

private func frameCount(_ list: UnsafeMutableAudioBufferListPointer) -> Int {
    guard let buf = list.first, buf.mNumberChannels > 0 else { return 0 }
    return Int(buf.mDataByteSize) / (MemoryLayout<Float>.size * Int(buf.mNumberChannels))
}
