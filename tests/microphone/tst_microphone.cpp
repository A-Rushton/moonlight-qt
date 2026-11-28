#include <QtTest>

#include <opus.h>

#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <random>
#include <thread>
#include <vector>

#include "micechocanceller.h"
#include "micdownmix.h"
#include "micencoder.h"
#include "micfarend.h"
#include "micring.h"

namespace {

constexpr size_t FRAME = 480;
constexpr float kFarLevel = 0.6f;

std::vector<float> ramp(size_t first, size_t count)
{
    std::vector<float> v(count);
    for (size_t i = 0; i < count; i++) {
        v[i] = static_cast<float>(first + i);
    }
    return v;
}

double goertzelPower(const std::vector<float>& x, double freq, double rate)
{
    const double w = 2.0 * M_PI * freq / rate;
    const double coeff = 2.0 * std::cos(w);
    double s1 = 0, s2 = 0;
    for (float sample : x) {
        double s0 = sample + coeff * s1 - s2;
        s2 = s1;
        s1 = s0;
    }
    return s1 * s1 + s2 * s2 - coeff * s1 * s2;
}

}

class tst_Microphone : public QObject
{
    Q_OBJECT

private slots:
    void ringPopsExactFrames()
    {
        MicRing ring(4800);
        const size_t chunks[] = {37, 211, 500, 99, 3, 150};
        size_t next = 0;
        for (size_t c : chunks) {
            auto v = ramp(next, c);
            ring.push(v.data(), v.size());
            next += c;
        }
        QCOMPARE(next, size_t(1000));

        std::vector<float> out(FRAME);
        for (size_t f = 0; f < 2; f++) {
            QVERIFY(ring.popFrame(out.data(), FRAME));
            for (size_t i = 0; i < FRAME; i++) {
                QCOMPARE(out[i], static_cast<float>(f * FRAME + i));
            }
        }
        QCOMPARE(ring.available(), size_t(40));
        QVERIFY(!ring.popFrame(out.data(), FRAME));
        QCOMPARE(ring.droppedSamples(), uint64_t(0));
    }

    void ringOverflowDropsOldest()
    {
        MicRing ring(960);
        auto v = ramp(0, 1500);
        ring.push(v.data(), v.size());
        QCOMPARE(ring.droppedSamples(), uint64_t(540));
        QCOMPARE(ring.available(), size_t(960));

        std::vector<float> out(FRAME);
        for (size_t f = 0; f < 2; f++) {
            QVERIFY(ring.popFrame(out.data(), FRAME));
            for (size_t i = 0; i < FRAME; i++) {
                QCOMPARE(out[i], static_cast<float>(540 + f * FRAME + i));
            }
        }
        QVERIFY(!ring.popFrame(out.data(), FRAME));
        QCOMPARE(ring.droppedSamples(), uint64_t(540));
    }

    void ringOversizedPushKeepsNewest()
    {
        MicRing ring(960);
        auto v = ramp(0, 5000);
        ring.push(v.data(), v.size());
        std::vector<float> out(FRAME);
        QVERIFY(ring.popFrame(out.data(), FRAME));
        QCOMPARE(out[0], 4040.0f);
        QCOMPARE(ring.droppedSamples(), uint64_t(4040));
    }

    void ringConcurrentPushPopKeepsOrder()
    {
        MicRing ring(4800);
        constexpr size_t TOTAL = 12000000;
        std::atomic<bool> producerDone{false};

        std::thread producer([&] {
            std::mt19937 rng(12345);
            std::uniform_int_distribution<size_t> dist(1, 700);
            std::vector<float> chunk(700);
            size_t next = 1;
            while (next <= TOTAL) {
                size_t n = std::min(dist(rng), TOTAL + 1 - next);
                for (size_t i = 0; i < n; i++) {
                    chunk[i] = static_cast<float>(next + i);
                }
                ring.push(chunk.data(), n);
                next += n;
                if ((next & 0x3FF) < 700) {
                    std::this_thread::yield();
                }
            }
            producerDone.store(true, std::memory_order_release);
        });

        std::vector<float> out(FRAME);
        float lastValue = 0;
        uint64_t gaps = 0;
        size_t frames = 0;
        bool inOrder = true;
        bool gapsCovered = true;
        for (;;) {
            bool done = producerDone.load(std::memory_order_acquire);
            if (ring.popFrame(out.data(), FRAME)) {
                frames++;
                for (size_t i = 1; i < FRAME; i++) {
                    if (out[i] != out[i - 1] + 1.0f) {
                        inOrder = false;
                    }
                }
                if (out[0] <= lastValue) {
                    inOrder = false;
                }
                else {
                    gaps += static_cast<uint64_t>(out[0] - lastValue) - 1;
                }
                if (gaps > ring.droppedSamples()) {
                    gapsCovered = false;
                }
                lastValue = out[FRAME - 1];
            }
            else if (done) {
                break;
            }
        }
        producer.join();

        QVERIFY(inOrder);
        QVERIFY(gapsCovered);
        QVERIFY(frames > 0);
        QCOMPARE(uint64_t(frames * FRAME) + uint64_t(ring.available()) + ring.droppedSamples(), uint64_t(TOTAL));
        QCOMPARE(gaps + (TOTAL - static_cast<uint64_t>(lastValue)) - ring.available(), ring.droppedSamples());
    }

    void encoderEncodesDecodableVoipFrames()
    {
        MicEncoder enc;
        QVERIFY(enc.init());

        int err = 0;
        OpusDecoder* dec = opus_decoder_create(48000, 1, &err);
        QVERIFY(dec != nullptr);
        QCOMPARE(err, OPUS_OK);

        std::vector<float> decoded;
        std::vector<float> in(FRAME);
        std::vector<float> pcm(FRAME);
        unsigned char packet[1000];
        for (int f = 0; f < 50; f++) {
            for (size_t i = 0; i < FRAME; i++) {
                in[i] = 0.5f * std::sin(2.0 * M_PI * 440.0 * (f * FRAME + i) / 48000.0);
            }
            int len = enc.encode(in.data(), packet, sizeof(packet));
            QVERIFY(len >= 1 && len <= 1000);
            int n = opus_decode_float(dec, packet, len, pcm.data(), FRAME, 0);
            QCOMPARE(n, int(FRAME));
            decoded.insert(decoded.end(), pcm.begin(), pcm.end());
        }
        opus_decoder_destroy(dec);

        std::vector<float> tail(decoded.begin() + 10 * FRAME, decoded.end());
        double tone = goertzelPower(tail, 440.0, 48000.0);
        double other = goertzelPower(tail, 1000.0, 48000.0);
        QVERIFY2(tone / other > 100.0, qPrintable(QString::number(tone / other)));
    }

    void encoderRejectsTinyOutputBuffer()
    {
        MicEncoder enc;
        QVERIFY(enc.init());
        std::vector<float> in(FRAME, 0.25f);
        unsigned char out[1];
        QVERIFY(enc.encode(in.data(), out, 1) < 0);
        QVERIFY(enc.encode(in.data(), out, 0) < 0);
        QVERIFY(enc.encode(in.data(), nullptr, 100) < 0);
    }

    void encoderRequiresInit()
    {
        MicEncoder enc;
        std::vector<float> in(FRAME, 0.0f);
        unsigned char out[1000];
        QVERIFY(enc.encode(in.data(), out, sizeof(out)) < 0);
    }

    void echoIsCancelled()
    {
#ifndef HAVE_WEBRTC_APM
        QSKIP("built without webrtc-audio-processing");
#endif
        MicEchoCanceller aec;
        QVERIFY(aec.init());
        QVERIFY(aec.active());
        aec.setStreamDelayMs(100);

        constexpr size_t total = 8 * 48000;
        constexpr size_t delay = 4800;
        std::vector<float> farEnd(total);
        uint32_t state = 12345;
        for (size_t i = 0; i < total; i++) {
            state = state * 1664525u + 1013904223u;
            float noise = (static_cast<int32_t>(state) / 2147483648.0f);
            float env = 0.5f + 0.5f * std::sin(2.0 * M_PI * 4.0 * i / 48000.0);
            farEnd[i] = kFarLevel * env * noise;
        }

        double inEnergy = 0, outEnergy = 0;
        const size_t measureFrom = total - 3 * 48000;
        for (size_t pos = 0; pos + FRAME <= total; pos += FRAME) {
            std::vector<float> cap(FRAME);
            for (size_t i = 0; i < FRAME; i++) {
                size_t n = pos + i;
                cap[i] = n >= delay ? 0.5f * farEnd[n - delay] : 0.0f;
            }
            std::vector<float> in = cap;
            aec.processReverse(farEnd.data() + pos);
            aec.processCapture(cap.data());
            if (pos >= measureFrom) {
                for (size_t i = 0; i < FRAME; i++) {
                    inEnergy += static_cast<double>(in[i]) * in[i];
                    outEnergy += static_cast<double>(cap[i]) * cap[i];
                }
            }
        }
        double erle = 10.0 * std::log10(inEnergy / std::max(outEnergy, 1e-20));
        qInfo("ERLE %.2f dB", erle);
        QVERIFY2(erle >= 20.0, qPrintable(QString::number(erle)));

        MicEchoCanceller::Stats stats;
        QVERIFY(aec.statistics(stats));
        QVERIFY(stats.delayMs.has_value());
        QVERIFY(stats.erle.has_value());
        QVERIFY(*stats.delayMs >= 0);
        qInfo("AEC3 delay %d ms, ERLE %.1f dB", *stats.delayMs, *stats.erle);
    }

    void nearEndPreserved()
    {
#ifndef HAVE_WEBRTC_APM
        QSKIP("built without webrtc-audio-processing");
#endif
        MicEchoCanceller aec;
        QVERIFY(aec.init());
        aec.setStreamDelayMs(100);

        constexpr size_t total = 6 * 48000;
        std::vector<float> silence(FRAME, 0.0f);
        double inEnergy = 0, outEnergy = 0;
        for (size_t pos = 0; pos + FRAME <= total; pos += FRAME) {
            std::vector<float> cap(FRAME);
            for (size_t i = 0; i < FRAME; i++) {
                double t = (pos + i) / 48000.0;
                double amp = 0.175 + 0.125 * std::sin(2.0 * M_PI * 4.0 * t);
                cap[i] = static_cast<float>(amp * std::sin(2.0 * M_PI * 440.0 * t));
            }
            std::vector<float> in = cap;
            aec.processReverse(silence.data());
            aec.processCapture(cap.data());
            if (pos >= total - 3 * 48000) {
                for (size_t i = 0; i < FRAME; i++) {
                    inEnergy += static_cast<double>(in[i]) * in[i];
                    outEnergy += static_cast<double>(cap[i]) * cap[i];
                }
            }
        }
        double diff = 10.0 * std::log10(outEnergy / inEnergy);
        qInfo("near-end delta %.2f dB", diff);
        QVERIFY2(std::fabs(diff) <= 10.0, qPrintable(QString::number(diff)));
    }

    void echoOffLeavesEcho()
    {
#ifndef HAVE_WEBRTC_APM
        QSKIP("built without webrtc-audio-processing");
#endif
        MicEchoCanceller aec;
        QVERIFY(aec.init({false, true}));
        QVERIFY(aec.active());
        aec.setStreamDelayMs(100);

        constexpr size_t total = 8 * 48000;
        constexpr size_t delay = 4800;
        std::vector<float> farEnd(total);
        uint32_t state = 12345;
        for (size_t i = 0; i < total; i++) {
            state = state * 1664525u + 1013904223u;
            float noise = (static_cast<int32_t>(state) / 2147483648.0f);
            float env = 0.5f + 0.5f * std::sin(2.0 * M_PI * 4.0 * i / 48000.0);
            farEnd[i] = kFarLevel * env * noise;
        }

        double inEnergy = 0, outEnergy = 0;
        const size_t measureFrom = total - 3 * 48000;
        for (size_t pos = 0; pos + FRAME <= total; pos += FRAME) {
            std::vector<float> cap(FRAME);
            for (size_t i = 0; i < FRAME; i++) {
                size_t n = pos + i;
                cap[i] = n >= delay ? 0.5f * farEnd[n - delay] : 0.0f;
            }
            std::vector<float> in = cap;
            aec.processReverse(farEnd.data() + pos);
            aec.processCapture(cap.data());
            if (pos >= measureFrom) {
                for (size_t i = 0; i < FRAME; i++) {
                    inEnergy += static_cast<double>(in[i]) * in[i];
                    outEnergy += static_cast<double>(cap[i]) * cap[i];
                }
            }
        }
        double erle = 10.0 * std::log10(inEnergy / std::max(outEnergy, 1e-20));
        qInfo("ERLE with echo cancellation off %.2f dB", erle);
        QVERIFY2(erle < 6.0, qPrintable(QString::number(erle)));
    }

    void noiseSuppressionOffKeepsNoise()
    {
#ifndef HAVE_WEBRTC_APM
        QSKIP("built without webrtc-audio-processing");
#endif
        auto lastSecondEnergy = [](bool noiseSuppression) {
            MicEchoCanceller aec;
            if (!aec.init({true, noiseSuppression})) {
                return -1.0;
            }
            aec.setStreamDelayMs(100);

            constexpr size_t total = 3 * 48000;
            std::vector<float> silence(FRAME, 0.0f);
            std::mt19937 rng(777);
            std::normal_distribution<float> dist(0.0f, 0.01f);
            double energy = 0;
            for (size_t pos = 0; pos + FRAME <= total; pos += FRAME) {
                std::vector<float> cap(FRAME);
                for (float& s : cap) {
                    s = dist(rng);
                }
                aec.processReverse(silence.data());
                aec.processCapture(cap.data());
                if (pos >= total - 48000) {
                    for (float s : cap) {
                        energy += static_cast<double>(s) * s;
                    }
                }
            }
            return energy;
        };

        double nsOn = lastSecondEnergy(true);
        double nsOff = lastSecondEnergy(false);
        QVERIFY(nsOn >= 0.0 && nsOff >= 0.0);
        double diff = 10.0 * std::log10(nsOff / std::max(nsOn, 1e-20));
        qInfo("noise energy with NS off vs on: +%.2f dB", diff);
        QVERIFY2(diff >= 6.0, qPrintable(QString::number(diff)));
    }

    void processReverseSafeWhenEchoOff()
    {
#ifndef HAVE_WEBRTC_APM
        QSKIP("built without webrtc-audio-processing");
#endif
        MicEchoCanceller aec;
        QVERIFY(aec.init({false, true}));
        std::vector<float> far(FRAME, 0.3f);
        for (int i = 0; i < 100; i++) {
            aec.processReverse(far.data());
        }
        std::vector<float> cap(FRAME);
        for (size_t i = 0; i < FRAME; i++) {
            cap[i] = 0.1f * std::sin(0.05f * i);
        }
        aec.processCapture(cap.data());
        for (float s : cap) {
            QVERIFY(std::isfinite(s));
        }
    }

    void uninitialisedPassesThrough()
    {
        MicEchoCanceller aec;
        QVERIFY(!aec.active());
        std::vector<float> frame(FRAME);
        for (size_t i = 0; i < FRAME; i++) {
            frame[i] = std::sin(0.01f * i);
        }
        std::vector<float> copy = frame;
        aec.processReverse(frame.data());
        aec.processCapture(frame.data());
        QCOMPARE(std::memcmp(frame.data(), copy.data(), FRAME * sizeof(float)), 0);

        MicEchoCanceller::Stats stats;
        QVERIFY(!aec.statistics(stats));
    }
    void downmixLayouts()
    {
        constexpr int frames = 37;
        for (int channels : { 2, 6, 8 }) {
            std::vector<float> fpcm(static_cast<size_t>(frames) * channels);
            std::vector<int16_t> ipcm(fpcm.size());
            float floatMean = 0.0f;
            float intMean = 0.0f;
            for (int c = 0; c < channels; c++) {
                float fv = 0.1f * (c + 1) - 0.35f;
                int16_t iv = static_cast<int16_t>(4000 * (c + 1) - 12000);
                floatMean += fv;
                intMean += iv / 32768.0f;
                for (int f = 0; f < frames; f++) {
                    fpcm[f * channels + c] = fv;
                    ipcm[f * channels + c] = iv;
                }
            }
            floatMean /= channels;
            intMean /= channels;

            std::vector<float> out(frames, 99.0f);
            micDownmixToMono(fpcm.data(), frames, channels, true, out.data());
            for (float s : out) {
                QVERIFY(std::fabs(s - floatMean) < 1e-6f);
            }

            std::fill(out.begin(), out.end(), 99.0f);
            micDownmixToMono(ipcm.data(), frames, channels, false, out.data());
            for (float s : out) {
                QVERIFY(std::fabs(s - intMean) < 1e-6f);
            }
        }
    }

    void farEndStarvedFeedsSilence()
    {
        MicFarEndFeeder feeder;
        std::vector<float> frame(FRAME, 1.0f);
        QVERIFY(!feeder.popFrame(frame.data()));
        QVERIFY(std::all_of(frame.begin(), frame.end(), [](float s) { return s == 0.0f; }));

        std::vector<float> partial = ramp(1, FRAME - 1);
        feeder.push(partial.data(), partial.size());
        std::fill(frame.begin(), frame.end(), 1.0f);
        QVERIFY(!feeder.popFrame(frame.data()));
        QVERIFY(std::all_of(frame.begin(), frame.end(), [](float s) { return s == 0.0f; }));
    }

    void farEndPopsPushedFrame()
    {
        MicFarEndFeeder feeder;
        std::vector<float> in = ramp(0, FRAME);
        feeder.push(in.data(), in.size());
        std::vector<float> frame(FRAME);
        QVERIFY(feeder.popFrame(frame.data()));
        QCOMPARE(frame, in);
        QVERIFY(!feeder.popFrame(frame.data()));
    }

    void farEndOverrunKeepsLatest()
    {
        MicFarEndFeeder feeder;
        QCOMPARE(MicFarEndFeeder::CapacitySamples, size_t(9600));

        constexpr size_t pushed = 9600 + 2400;
        std::vector<float> in = ramp(0, pushed);
        for (size_t i = 0; i < pushed; i += 240) {
            feeder.push(in.data() + i, 240);
        }

        // Resynchronised to the newest samples, keeping the jitter target
        std::vector<float> frame(FRAME);
        const size_t first = pushed - MicFarEndFeeder::TargetBacklogSamples;
        for (size_t f = first; f < pushed; f += FRAME) {
            QVERIFY(feeder.popFrame(frame.data()));
            QCOMPARE(frame, ramp(f, FRAME));
        }
        QVERIFY(!feeder.popFrame(frame.data()));
    }

    void farEndBacklogIsBounded()
    {
        QCOMPARE(MicFarEndFeeder::MaxBacklogSamples, size_t(10 * FRAME));
        QCOMPARE(MicFarEndFeeder::TargetBacklogSamples, size_t(4 * FRAME));

        MicFarEndFeeder feeder;
        const size_t pushed = 12 * FRAME + 100;
        std::vector<float> in = ramp(0, pushed);
        feeder.push(in.data(), in.size());

        std::vector<float> frame(FRAME);
        QVERIFY(feeder.popFrame(frame.data()));
        QCOMPARE(frame, ramp(pushed - 4 * FRAME, FRAME));
    }

    void farEndCountersTrackEvents()
    {
        MicFarEndFeeder feeder;
        std::vector<float> frame(FRAME);

        QVERIFY(!feeder.popFrame(frame.data()));
        std::vector<float> in = ramp(0, 12 * FRAME + 100);
        feeder.push(in.data(), in.size());
        QVERIFY(feeder.popFrame(frame.data()));
        QVERIFY(feeder.popFrame(frame.data()));
        QCOMPARE(feeder.depth(), size_t(2 * FRAME));

        MicFarEndFeeder::Counters c = feeder.takeCounters();
        QCOMPARE(c.frames, uint64_t(3));
        QCOMPARE(c.starved, uint64_t(1));
        QCOMPARE(c.trims, uint64_t(1));
        QCOMPARE(c.trimmedSamples, uint64_t(12 * FRAME + 100 - 4 * FRAME));

        c = feeder.takeCounters();
        QCOMPARE(c.frames, uint64_t(0));
        QCOMPARE(c.starved, uint64_t(0));
        QCOMPARE(c.trims, uint64_t(0));
        QCOMPARE(c.trimmedSamples, uint64_t(0));
    }

    void farEndJitterIsAbsorbed()
    {
        MicFarEndFeeder feeder;
        const size_t pushed = 10 * FRAME;
        std::vector<float> in = ramp(0, pushed);
        feeder.push(in.data(), in.size());

        std::vector<float> frame(FRAME);
        for (size_t f = 0; f < pushed; f += FRAME) {
            QVERIFY(feeder.popFrame(frame.data()));
            QCOMPARE(frame, ramp(f, FRAME));
        }
        QVERIFY(!feeder.popFrame(frame.data()));
    }
};

QTEST_GUILESS_MAIN(tst_Microphone)
#include "tst_microphone.moc"
