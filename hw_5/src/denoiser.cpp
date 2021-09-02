#include "denoiser.h"

Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Reproject
            int id = frameInfo.m_id(x, y);
            if (id != -1) {
                Float3 position = frameInfo.m_position(x, y);
                Matrix4x4 nowModelToWorld = frameInfo.m_matrix[id];
                Matrix4x4 preModelToWorld = m_preFrameInfo.m_matrix[id];

                Float3 preScreen = (preWorldToScreen * preModelToWorld * Inverse(nowModelToWorld))(position, Float3::EType::Point);

                if (preScreen.x <= 0.0 || preScreen.y <= 0.0 || preScreen.z <= 0.0 ||
                    preScreen.x >= width || preScreen.y >= height || preScreen.z >= 1.0)
                    m_valid(x, y) = false;
                else {
                    int preid = m_preFrameInfo.m_id(preScreen.x, preScreen.y);
                    if (preid != id)
                        m_valid(x, y) = false;
                    else {
                        m_valid(x, y) = true;
                        m_misc(x, y) = m_preFrameInfo.m_beauty(preScreen.x, preScreen.y);
                    }
                }
            }
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 3;
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 mu = 0.0;
            for (int dx = -1 * kernelRadius; dx <= kernelRadius; ++dx) {
                for (int dy = -1 * kernelRadius; dy <= kernelRadius; ++dy) {
                    mu += ((const Buffer2D<Float3>)m_accColor)(x + dx, y + dy);
                }
            }
            mu = mu / pow(2 * kernelRadius + 1, 2.0);
            Float3 theta = 0.0;
            for (int dx = -1 * kernelRadius; dx <= kernelRadius; ++dx) {
                for (int dy = -1 * kernelRadius; dy <= kernelRadius; ++dy) {
                    theta += (((const Buffer2D<Float3>)m_accColor)(x + dx, y + dy) - mu) * (((const Buffer2D<Float3>)m_accColor)(x + dx, y + dy) - mu);
                }
            }

            Float3 color = m_accColor(x, y);
            Clamp(color, mu - theta * m_colorBoxK, mu + theta * m_colorBoxK);
            // TODO: Exponential moving average
            float alpha = 1.0f;
            if (m_valid(x, y)) alpha = m_alpha;
            
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> buffer;
    buffer.Copy(frameInfo.m_beauty);

    Buffer2D<Float3> filteredImage = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 16;

    int filter_step = 1;
    int filter_edge = kernelRadius;
    //int kernelRadius_set = 3;
    //int filter_time = log2(kernelRadius);
    //for (int time = 0; time <= filter_time; time++) {
    //    int filter_step = pow(2, time);
    //    int filter_edge = std::min(kernelRadius_set * filter_step, (int)pow(2, filter_time));
#pragma omp parallel for
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                // TODO: Joint bilateral filter
                Float3 out_color = 0.0;
                float sum_J = 0.0;
                for (int dx = -1 * filter_edge; dx <= filter_edge; dx += filter_step) {
                    for (int dy = -1 * filter_edge; dy <= filter_edge; dy += filter_step) {
                        Float3 color = 0.0f;
                        Float3 color_d = 0.0f;
                        Float3 normal = 0.0f;
                        Float3 normal_d = 0.0f;
                        Float3 position = 0.0f;
                        Float3 position_d = 0.0f;
                        if ((x + dx >= 0) && (x + dx < width) && (y + dy >= 0) && (y + dy < height)) {
                            color = buffer(x, y);
                            color_d = buffer(x + dx, y + dy);
                            normal = frameInfo.m_normal(x, y);
                            normal_d = frameInfo.m_normal(x + dx, y + dy);
                            position = frameInfo.m_position(x, y);
                            position_d = frameInfo.m_position(x + dx, y + dy);
                        }
                        double J = exp(
                            -1.0 * (
                            (Sqr(dx/ filter_edge) + Sqr(dy / filter_edge)) / (2.0 * Sqr(m_sigmaCoord)) +
                            Sqr(Length(color - color_d)) / (2.0 * Sqr(m_sigmaColor)) +
                            Sqr(SafeAcos(Dot(normal, normal_d))) / (2.0 * Sqr(m_sigmaNormal)) +
                            Sqr(Dot(normal, Normalize(position_d - position))) / (2.0 * Sqr(m_sigmaPlane))
                            ));
                        sum_J += J;
                        out_color += color_d * J;
                    }
                }
                if (sum_J == 0.0) filteredImage(x, y) = 0.0;
                else filteredImage(x, y) = out_color / sum_J;
            }
        }
        buffer.Copy(filteredImage);
    //}
    return filteredImage;
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    m_preFrameInfo.m_beauty = m_accColor;
    return m_accColor;
}
