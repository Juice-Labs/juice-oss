FROM ubuntu:24.04 AS setup
ARG VIDEOSDK_VERSION=12.0.16
ARG VK_API_VERSION=1.2.203

RUN apt-get update && apt-get install -y unzip

COPY Video_Codec_SDK_${VIDEOSDK_VERSION}.zip /Video_Codec_SDK_${VIDEOSDK_VERSION}.zip
RUN CUDA_VERSION=$(realpath /usr/local/cuda | cut -d "-" -f2) && \
    CPU_ARCH=$(uname -p) && \
    mkdir -p /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/include && \
    mkdir -p /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs && \
    unzip -j Video_Codec_SDK_${VIDEOSDK_VERSION}.zip \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Interface/cuviddec.h \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Interface/nvcuvid.h \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Interface/nvEncodeAPI.h \
          -d /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/include && \
    unzip -j Video_Codec_SDK_${VIDEOSDK_VERSION}.zip \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Lib/linux/stubs/${CPU_ARCH}/libnvcuvid.so \
          Video_Codec_SDK_${VIDEOSDK_VERSION}/Lib/linux/stubs/${CPU_ARCH}/libnvidia-encode.so \
          -d /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs && \
# This needs to be fixed. Shouldn't be linking to libnvidia-encode.so.1
    mv /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs/libnvidia-encode.so /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs/libnvidia-encode.so.1 && \
    ln -s -T libnvidia-encode.so.1 /build/usr/local/cuda-${CUDA_VERSION}/targets/${CPU_ARCH}-linux/lib/stubs/libnvidia-encode.so

COPY root/ /build
RUN sed -e "s/<<VK_API_VERSION>>/${VK_API_VERSION}/" /build/usr/share/vulkan/icd.d/nvidia_icd.json && \
    chmod 755 /build/home/juice/start-agent.sh && \
    chown 1000:1000 /build/home/juice -R

FROM ubuntu:24.04

# =============================================================================
# Environment variables
# =============================================================================

# Base layer
ENV NVARCH=x86_64
ENV NVIDIA_REQUIRE_CUDA="cuda>=13.0"
ENV NV_CUDA_CUDART_VERSION=13.0.96-1
ENV CUDA_VERSION=13.0.2
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/lib64
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Runtime layer
ENV NV_CUDA_LIB_VERSION=13.0.2-1
ENV NV_NVTX_VERSION=13.0.85-1
ENV NV_LIBNPP_VERSION=13.0.1.2-1
ENV NV_LIBNPP_PACKAGE=libnpp-13-0=${NV_LIBNPP_VERSION}
ENV NV_LIBCUSPARSE_VERSION=12.6.3.3-1
ENV NV_LIBCUBLAS_PACKAGE_NAME=libcublas-13-0
ENV NV_LIBCUBLAS_VERSION=13.1.0.3-1
ENV NV_LIBCUBLAS_PACKAGE=${NV_LIBCUBLAS_PACKAGE_NAME}=${NV_LIBCUBLAS_VERSION}
ENV NV_LIBNCCL_PACKAGE_NAME=libnccl2
ENV NV_LIBNCCL_PACKAGE_VERSION=2.28.3-1
ENV NCCL_VERSION=2.28.3-1
ENV NV_LIBNCCL_PACKAGE=${NV_LIBNCCL_PACKAGE_NAME}=${NV_LIBNCCL_PACKAGE_VERSION}+cuda13.0

# CUDNN layer
ENV NV_CUDNN_VERSION=9.14.0.64-1
ENV NV_CUDNN_PACKAGE_NAME=libcudnn9-cuda-13
ENV NV_CUDNN_PACKAGE=libcudnn9-cuda-13=${NV_CUDNN_VERSION}

# Video Codec
ENV VIDEOSDK_VERSION=13.0.37

# =============================================================================
# NVIDIA dependencies
# =============================================================================

RUN apt-get update && \
    apt-get install -y --only-upgrade $(apt-get --just-print upgrade | awk 'tolower($4) ~ /.*security.*/ || tolower($5) ~ /.*security.*/ {print $2}' | sort | uniq) && \
    apt-get install -y --no-install-recommends gnupg2 curl ca-certificates && \
    curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${NVARCH}/3bf863cc.pub | apt-key add - && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/${NVARCH} /" > /etc/apt/sources.list.d/cuda.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    cuda-cudart-13-0=${NV_CUDA_CUDART_VERSION} \
    cuda-compat-13-0 \
    cuda-libraries-13-0=${NV_CUDA_LIB_VERSION} \
    ${NV_LIBNPP_PACKAGE} \
    cuda-nvtx-13-0=${NV_NVTX_VERSION} \
    libcusparse-13-0=${NV_LIBCUSPARSE_VERSION} \
    ${NV_LIBCUBLAS_PACKAGE} \
    ${NV_LIBNCCL_PACKAGE} \
    ${NV_CUDNN_PACKAGE} && \
    echo "/usr/local/cuda/lib64" >> /etc/ld.so.conf.d/nvidia.conf && \
    apt-mark hold ${NV_LIBCUBLAS_PACKAGE_NAME} ${NV_LIBNCCL_PACKAGE_NAME} ${NV_CUDNN_PACKAGE_NAME} && \
    rm -rf /var/lib/apt/lists/*

## Juice Layer
ARG JUICE_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV JUICE_VERSION=${JUICE_VERSION}
ENV JUICE_HOST_PORT=7865
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64:/usr/local/cuda/lib64/stubs:/root
ENV FONTCONFIG_PATH=/etc/fonts
ENV NVIDIA_DISABLE_REQUIRE=1
ENV NVIDIA_DRIVER_CAPABILITIES=compute,graphics,utility,video

# Run all the apt commands in one layer
RUN apt-get update && \
    apt-get install -y software-properties-common pciutils && \
# Install libstdc++-10
#    add-apt-repository ppa:ubuntu-toolchain-r/test && \
#    apt-get install -y libstdc++-10-dev && \
# Install opengl support
    apt-get install -y libglvnd0 libgl1 libegl1 && \
# Install vulkan support
    apt-get install -y libvulkan1 && \
# Install dependencies
    apt-get install -y libnuma1 libatomic1 && \
    rm -rf /var/lib/apt/lists/* && \
# Add juice user
    userdel ubuntu && \
    useradd -u 1000 -ms /bin/bash juice


# Copy all the built data into one layer
COPY --from=setup /build .

# Finally, Juice installation
ADD juice-gpu-linux.tar.gz /home/juice/juice

USER juice
WORKDIR /home/juice
CMD ["./start-agent.sh"]

LABEL "maintainer"="JUICE TECHNOLOGIES <support@juicelabs.co>"
LABEL "juicelabs.co/version"=${JUICE_VERSION}