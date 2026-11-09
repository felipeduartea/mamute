import CoreAudio
import XCTest
@testable import MamuteCore

final class MixerTests: XCTestCase {
    /// Builds a buffer list from per-buffer (channels, samples).
    private func makeList(_ buffers: [(UInt32, [Float])]) -> UnsafeMutableAudioBufferListPointer {
        let list = AudioBufferList.allocate(maximumBuffers: buffers.count)
        for (i, (ch, samples)) in buffers.enumerated() {
            let data = UnsafeMutablePointer<Float>.allocate(capacity: samples.count)
            data.initialize(from: samples, count: samples.count)
            list[i] = AudioBuffer(mNumberChannels: ch, mDataByteSize: UInt32(samples.count * 4), mData: data)
        }
        return list
    }

    private func samples(_ list: UnsafeMutableAudioBufferListPointer, _ i: Int) -> [Float] {
        let b = list[i]
        return Array(UnsafeBufferPointer(start: b.mData!.assumingMemoryBound(to: Float.self), count: Int(b.mDataByteSize) / 4))
    }

    func testInterleavedStereoToSplitChannelsAtHalfGain() {
        let input = makeList([(2, [1, 2, 3, 4])]) // L R L R
        let output = makeList([(1, [9, 9]), (1, [9, 9])])
        mix(input: input, output: output, from: 0.5, to: 0.5)
        XCTAssertEqual(samples(output, 0), [0.5, 1.5])
        XCTAssertEqual(samples(output, 1), [1, 2])
    }

    func testMutedGainSilences() {
        let input = makeList([(2, [1, 1, 1, 1])])
        let output = makeList([(2, [9, 9, 9, 9])])
        mix(input: input, output: output, from: 0, to: 0)
        XCTAssertEqual(samples(output, 0), [0, 0, 0, 0])
    }

    func testGainRampsAcrossBuffer() {
        let input = makeList([(1, [1, 1, 1])])
        let output = makeList([(1, [9, 9, 9])])
        mix(input: input, output: output, from: 0, to: 1)
        XCTAssertEqual(samples(output, 0), [0, 0.5, 1])
    }

    func testExtraOutputChannelsAndFramesAreZeroed() {
        let input = makeList([(2, [1, 1])]) // one stereo frame
        let output = makeList([(4, [9, 9, 9, 9, 9, 9, 9, 9])]) // two 4-channel frames
        mix(input: input, output: output, from: 1, to: 1)
        XCTAssertEqual(samples(output, 0), [1, 1, 0, 0, 0, 0, 0, 0])
    }
}
