#pragma once

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <memory>

// Single-producer/single-consumer float ring. push() never blocks, locks or
// allocates and always keeps the newest samples; when the consumer falls
// behind, the oldest samples are discarded and counted.
//
// Invariant: sample index i lives in slot i % capacity. The producer
// announces the end of a write in mStarted before touching any slot, and
// publishes it in mWritten afterwards. The consumer only trusts a copy of
// [r, r + n) if mStarted <= r + capacity once the copy is done, i.e. no write
// has begun on any of those slots (seqlock-style validation).
class MicRing
{
public:
    explicit MicRing(size_t capacitySamples)
        : mCapacity(capacitySamples ? capacitySamples : 1),
          mBuffer(new std::atomic<float>[mCapacity])
    {
        for (size_t i = 0; i < mCapacity; i++) {
            mBuffer[i].store(0.0f, std::memory_order_relaxed);
        }
    }

    MicRing(const MicRing&) = delete;
    MicRing& operator=(const MicRing&) = delete;

    void push(const float* samples, size_t count) noexcept
    {
        if (count == 0) {
            return;
        }

        const uint64_t w = mWritten.load(std::memory_order_relaxed);
        const uint64_t end = w + count;

        mStarted.store(end, std::memory_order_relaxed);
        std::atomic_thread_fence(std::memory_order_release);

        // Samples older than one full lap are overwritten by this same push
        size_t skip = count > mCapacity ? count - mCapacity : 0;
        size_t slot = static_cast<size_t>((w + skip) % mCapacity);
        for (size_t i = skip; i < count; i++) {
            mBuffer[slot].store(samples[i], std::memory_order_relaxed);
            if (++slot == mCapacity) {
                slot = 0;
            }
        }

        mWritten.store(end, std::memory_order_release);
    }

    bool popFrame(float* out, size_t frameSamples) noexcept
    {
        if (frameSamples == 0 || frameSamples > mCapacity) {
            return false;
        }

        uint64_t r = mRead.load(std::memory_order_relaxed);
        uint64_t skipped = 0;
        bool ok = false;

        for (;;) {
            const uint64_t w = mWritten.load(std::memory_order_acquire);

            if (w - r > mCapacity) {
                skipped += w - mCapacity - r;
                r = w - mCapacity;
            }

            if (w - r < frameSamples) {
                break;
            }

            size_t slot = static_cast<size_t>(r % mCapacity);
            for (size_t i = 0; i < frameSamples; i++) {
                out[i] = mBuffer[slot].load(std::memory_order_relaxed);
                if (++slot == mCapacity) {
                    slot = 0;
                }
            }

            std::atomic_thread_fence(std::memory_order_acquire);
            const uint64_t started = mStarted.load(std::memory_order_relaxed);
            if (started <= r + mCapacity) {
                r += frameSamples;
                ok = true;
                break;
            }

            // The producer lapped us mid-copy; discard what it overwrote
            skipped += started - mCapacity - r;
            r = started - mCapacity;
        }

        // mRead must be visible no later than mDropped so droppedSamples()
        // can never count the same samples twice
        mRead.store(r, std::memory_order_release);
        if (skipped) {
            mDropped.fetch_add(skipped, std::memory_order_release);
        }
        return ok;
    }

    // Consumer side: drops all but the newest keepSamples unread samples
    // Returns the number of samples discarded
    size_t discardTo(size_t keepSamples) noexcept
    {
        const uint64_t r = mRead.load(std::memory_order_relaxed);
        const uint64_t w = mWritten.load(std::memory_order_acquire);
        if (keepSamples > mCapacity) {
            keepSamples = mCapacity;
        }
        if (w - r <= keepSamples) {
            return 0;
        }

        mRead.store(w - keepSamples, std::memory_order_release);
        mDropped.fetch_add(w - keepSamples - r, std::memory_order_release);
        return static_cast<size_t>(w - keepSamples - r);
    }

    size_t available() const noexcept
    {
        const uint64_t r = mRead.load(std::memory_order_acquire);
        const uint64_t w = mWritten.load(std::memory_order_acquire);
        const uint64_t n = w > r ? w - r : 0;
        return static_cast<size_t>(n > mCapacity ? mCapacity : n);
    }

    uint64_t droppedSamples() const noexcept
    {
        const uint64_t dropped = mDropped.load(std::memory_order_acquire);
        const uint64_t r = mRead.load(std::memory_order_acquire);
        const uint64_t w = mWritten.load(std::memory_order_acquire);
        const uint64_t pending = w > r + mCapacity ? w - r - mCapacity : 0;
        return dropped + pending;
    }

private:
    const size_t mCapacity;
    std::unique_ptr<std::atomic<float>[]> mBuffer;

    alignas(64) std::atomic<uint64_t> mWritten{0};
    alignas(64) std::atomic<uint64_t> mStarted{0};
    alignas(64) std::atomic<uint64_t> mRead{0};
    std::atomic<uint64_t> mDropped{0};
};
