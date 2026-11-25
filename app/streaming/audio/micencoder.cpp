#include "micencoder.h"

#include <opus.h>

void MicEncoder::Deleter::operator()(OpusEncoder* enc) const
{
    opus_encoder_destroy(enc);
}

MicEncoder::~MicEncoder() = default;

bool MicEncoder::init()
{
    int err;
    OpusEncoder* enc = opus_encoder_create(SampleRate, 1, OPUS_APPLICATION_VOIP, &err);
    if (enc == nullptr || err != OPUS_OK) {
        return false;
    }

    mEncoder.reset(enc);

    if (opus_encoder_ctl(enc, OPUS_SET_BITRATE(64000)) != OPUS_OK ||
            opus_encoder_ctl(enc, OPUS_SET_INBAND_FEC(1)) != OPUS_OK ||
            opus_encoder_ctl(enc, OPUS_SET_PACKET_LOSS_PERC(10)) != OPUS_OK ||
            opus_encoder_ctl(enc, OPUS_SET_DTX(0)) != OPUS_OK) {
        mEncoder.reset();
        return false;
    }

    return true;
}

int MicEncoder::encode(const float* frame480, unsigned char* out, int outCapacity)
{
    if (!mEncoder || frame480 == nullptr || out == nullptr) {
        return OPUS_BAD_ARG;
    }

    // A single byte can only hold a TOC header, never a usable packet
    if (outCapacity < 2) {
        return OPUS_BUFFER_TOO_SMALL;
    }

    if (outCapacity > MIC_MAX_OPUS_FRAME_BYTES) {
        outCapacity = MIC_MAX_OPUS_FRAME_BYTES;
    }

    return opus_encode_float(mEncoder.get(), frame480, FrameSamples, out, outCapacity);
}
